import AppKit
import Foundation

struct Bucket {
  var red = 0.0
  var green = 0.0
  var blue = 0.0
  var saturation = 0.0
  var brightness = 0.0
  var count = 0.0
  var topWeight = 0.0
}

let globalDefaults = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
let isDark = globalDefaults?["AppleInterfaceStyle"] as? String == "Dark"
let fallback = isDark ? "0x8C282124" : "0x8CF4EFEA"

func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
  return max(lower, min(upper, value))
}

func rgbToHsb(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, brightness: Double) {
  let maxValue = max(red, green, blue)
  let minValue = min(red, green, blue)
  let delta = maxValue - minValue

  var hue = 0.0
  if delta != 0 {
    if maxValue == red {
      hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
    } else if maxValue == green {
      hue = ((blue - red) / delta) + 2
    } else {
      hue = ((red - green) / delta) + 4
    }
    hue /= 6
    if hue < 0 { hue += 1 }
  }

  let saturation = maxValue == 0 ? 0 : delta / maxValue
  return (hue, saturation, maxValue)
}

func hsbToRgb(hue: Double, saturation: Double, brightness: Double) -> (red: Int, green: Int, blue: Int) {
  let h = hue * 6
  let c = brightness * saturation
  let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
  let m = brightness - c

  let rgb: (Double, Double, Double)
  switch h {
  case 0..<1: rgb = (c, x, 0)
  case 1..<2: rgb = (x, c, 0)
  case 2..<3: rgb = (0, c, x)
  case 3..<4: rgb = (0, x, c)
  case 4..<5: rgb = (x, 0, c)
  default: rgb = (c, 0, x)
  }

  return (
    Int(clamp((rgb.0 + m) * 255, 0, 255)),
    Int(clamp((rgb.1 + m) * 255, 0, 255)),
    Int(clamp((rgb.2 + m) * 255, 0, 255))
  )
}

func mix(_ first: (red: Int, green: Int, blue: Int), _ second: (red: Int, green: Int, blue: Int), amount: Double) -> (red: Int, green: Int, blue: Int) {
  let ratio = clamp(amount, 0.0, 1.0)
  return (
    Int(Double(first.red) * (1.0 - ratio) + Double(second.red) * ratio),
    Int(Double(first.green) * (1.0 - ratio) + Double(second.green) * ratio),
    Int(Double(first.blue) * (1.0 - ratio) + Double(second.blue) * ratio)
  )
}

func runAppleScript(_ source: String) -> String? {
  let process = Process()
  let pipe = Pipe()

  process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
  process.arguments = ["-e", source]
  process.standardOutput = pipe
  process.standardError = Pipe()

  do {
    try process.run()
    process.waitUntilExit()
  } catch {
    return nil
  }

  guard process.terminationStatus == 0 else {
    return nil
  }

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

func desktopImageURL() -> URL? {
  if CommandLine.arguments.count > 1 {
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    if NSImage(contentsOf: url) != nil {
      return url
    }
  }

  if let screen = NSScreen.main,
     let url = NSWorkspace.shared.desktopImageURL(for: screen),
     NSImage(contentsOf: url) != nil {
    return url
  }

  if let path = runAppleScript("tell application \"System Events\" to get picture of current desktop"),
     !path.isEmpty {
    return URL(fileURLWithPath: path)
  }

  if let path = runAppleScript("tell application \"Finder\" to POSIX path of (desktop picture as alias)"),
     !path.isEmpty {
    return URL(fileURLWithPath: path)
  }

  return nil
}

guard
  let url = desktopImageURL(),
  let image = NSImage(contentsOf: url),
  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
  print(fallback)
  exit(0)
}

let bitmap = NSBitmapImageRep(cgImage: cgImage)
let width = cgImage.width
let height = cgImage.height
let samples = 48
let bucketCount = 64
let displayID = CGMainDisplayID()
let screenWidth = max(1.0, Double(CGDisplayPixelsWide(displayID)))
let screenHeight = max(1.0, Double(CGDisplayPixelsHigh(displayID)))
let imageAspect = Double(width) / Double(max(height, 1))
let screenAspect = screenWidth / screenHeight
let cropWidth: Int
let cropHeight: Int
let cropX: Int
let cropY: Int

if imageAspect > screenAspect {
  cropHeight = height
  cropWidth = max(1, Int(Double(height) * screenAspect))
  cropX = max(0, (width - cropWidth) / 2)
  cropY = 0
} else {
  cropWidth = width
  cropHeight = max(1, Int(Double(width) / screenAspect))
  cropX = 0
  cropY = max(0, (height - cropHeight) / 2)
}

let sampleHeight = max(1, Int(Double(cropHeight) * 0.16))

var buckets = Array(repeating: Bucket(), count: bucketCount)
var ambientRed = 0.0
var ambientGreen = 0.0
var ambientBlue = 0.0
var ambientWeight = 0.0

for xIndex in 0..<samples {
  for yIndex in 0..<samples {
    let x = max(0, min(width - 1, cropX + (xIndex * cropWidth) / samples))
    let y = max(0, min(height - 1, cropY + (yIndex * sampleHeight) / samples))

    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
      continue
    }

    let red = Double(color.redComponent)
    let green = Double(color.greenComponent)
    let blue = Double(color.blueComponent)
    let hsb = rgbToHsb(red: red, green: green, blue: blue)
    let yRatio = Double(y) / Double(max(sampleHeight - 1, 1))
    let weight = yRatio < 0.45 ? 1.25 : 1.0

    if hsb.brightness > 0.08 && hsb.brightness < 0.97 {
      ambientRed += red * weight
      ambientGreen += green * weight
      ambientBlue += blue * weight
      ambientWeight += weight
    }

    // Material You-like seed selection: prefer pleasant colorful mid-tones
    // around the menu-bar area instead of raw full-image dominance.
    if hsb.saturation < 0.08 || hsb.brightness < 0.07 || hsb.brightness > 0.94 {
      continue
    }

    let bucketIndex = min(bucketCount - 1, Int(hsb.hue * Double(bucketCount)))
    buckets[bucketIndex].red += red * weight
    buckets[bucketIndex].green += green * weight
    buckets[bucketIndex].blue += blue * weight
    buckets[bucketIndex].saturation += hsb.saturation * weight
    buckets[bucketIndex].brightness += hsb.brightness * weight
    buckets[bucketIndex].count += weight
    buckets[bucketIndex].topWeight += weight
  }
}

let best = buckets.enumerated().max { lhs, rhs in
  let left = lhs.element
  let right = rhs.element

  let leftSat = left.saturation / max(left.count, 1)
  let rightSat = right.saturation / max(right.count, 1)
  let leftBright = left.brightness / max(left.count, 1)
  let rightBright = right.brightness / max(right.count, 1)
  let leftToneScore = 1.0 - clamp(abs(leftBright - 0.56) / 0.44, 0.0, 0.85)
  let rightToneScore = 1.0 - clamp(abs(rightBright - 0.56) / 0.44, 0.0, 0.85)
  let leftTopScore = 1.0 + min(left.topWeight / max(left.count, 1.0), 1.0) * 0.75
  let rightTopScore = 1.0 + min(right.topWeight / max(right.count, 1.0), 1.0) * 0.75
  let leftSatScore = pow(clamp(leftSat, 0.16, 0.62), 1.25)
  let rightSatScore = pow(clamp(rightSat, 0.16, 0.62), 1.25)
  let leftScore = pow(left.count, 0.72) * leftSatScore * leftToneScore * leftTopScore
  let rightScore = pow(right.count, 0.72) * rightSatScore * rightToneScore * rightTopScore

  return leftScore < rightScore
}

let selected = best?.element
let hasSelectedSeed = (selected?.count ?? 0) > 0

guard hasSelectedSeed || ambientWeight > 0 else {
  print(fallback)
  exit(0)
}

let red = hasSelectedSeed ? selected!.red / selected!.count : ambientRed / ambientWeight
let green = hasSelectedSeed ? selected!.green / selected!.count : ambientGreen / ambientWeight
let blue = hasSelectedSeed ? selected!.blue / selected!.count : ambientBlue / ambientWeight
let seed = rgbToHsb(red: red, green: green, blue: blue)
let ambient = ambientWeight > 0
  ? rgbToHsb(red: ambientRed / ambientWeight, green: ambientGreen / ambientWeight, blue: ambientBlue / ambientWeight)
  : seed
let source = ambientWeight > 0 ? ambient : seed

let surfaceSaturation = isDark
  ? clamp(source.saturation * 1.10, 0.14, 0.34)
  : clamp(source.saturation * 0.55, 0.06, 0.18)
let surfaceBrightness = isDark
  ? clamp(source.brightness * 0.76, 0.27, 0.40)
  : clamp(0.86 + source.brightness * 0.10, 0.88, 0.96)
let surface = hsbToRgb(hue: source.hue, saturation: surfaceSaturation, brightness: surfaceBrightness)

if ProcessInfo.processInfo.environment["DEBUG_WALLPAPER_COLOR"] == "1" {
  fputs(
    String(
      format: "url=%@ size=%dx%d crop=%dx%d+%d+%d ambientWeight=%.2f source=(h%.3f s%.3f b%.3f) surface=%02X%02X%02X\n",
      url.path,
      width,
      height,
      cropWidth,
      cropHeight,
      cropX,
      cropY,
      ambientWeight,
      source.hue,
      source.saturation,
      source.brightness,
      surface.red,
      surface.green,
      surface.blue
    ),
    stderr
  )
}

// 0x8C = 55% opacity. The hue is present but still restrained: the bar should
// feel harmonized with the wallpaper without fully becoming the accent color.
print(String(format: "0x8C%02X%02X%02X", surface.red, surface.green, surface.blue))
