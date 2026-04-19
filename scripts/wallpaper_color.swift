import AppKit
import Foundation

struct Bucket {
  var red = 0.0
  var green = 0.0
  var blue = 0.0
  var saturation = 0.0
  var brightness = 0.0
  var count = 0.0
}

let globalDefaults = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
let isDark = globalDefaults?["AppleInterfaceStyle"] as? String == "Dark"
let fallback = isDark ? "0x8A3B302F" : "0x8AF6EEE7"

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

guard
  let screen = NSScreen.main,
  let url = NSWorkspace.shared.desktopImageURL(for: screen),
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
let bucketCount = 48

var buckets = Array(repeating: Bucket(), count: bucketCount)

for xIndex in 0..<samples {
  for yIndex in 0..<samples {
    let x = max(0, min(width - 1, (xIndex * width) / samples))
    let y = max(0, min(height - 1, (yIndex * height) / samples))

    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
      continue
    }

    let red = color.redComponent
    let green = color.greenComponent
    let blue = color.blueComponent
    let hsb = rgbToHsb(red: red, green: green, blue: blue)

    // Material You-like seed selection: prefer colorful mid-tones over neutral,
    // overexposed, or crushed-black pixels.
    if hsb.saturation < 0.14 || hsb.brightness < 0.12 || hsb.brightness > 0.94 {
      continue
    }

    let bucketIndex = min(bucketCount - 1, Int(hsb.hue * Double(bucketCount)))
    buckets[bucketIndex].red += red
    buckets[bucketIndex].green += green
    buckets[bucketIndex].blue += blue
    buckets[bucketIndex].saturation += hsb.saturation
    buckets[bucketIndex].brightness += hsb.brightness
    buckets[bucketIndex].count += 1
  }
}

let best = buckets.enumerated().max { lhs, rhs in
  let left = lhs.element
  let right = rhs.element

  let leftSat = left.saturation / max(left.count, 1)
  let rightSat = right.saturation / max(right.count, 1)
  let leftBright = left.brightness / max(left.count, 1)
  let rightBright = right.brightness / max(right.count, 1)
  let leftTonePenalty = abs(leftBright - 0.55) * 0.35
  let rightTonePenalty = abs(rightBright - 0.55) * 0.35
  let leftScore = left.count * pow(max(leftSat - leftTonePenalty, 0.01), 1.55)
  let rightScore = right.count * pow(max(rightSat - rightTonePenalty, 0.01), 1.55)

  return leftScore < rightScore
}

guard let selected = best?.element, selected.count > 0 else {
  print(fallback)
  exit(0)
}

let red = selected.red / selected.count
let green = selected.green / selected.count
let blue = selected.blue / selected.count
let seed = rgbToHsb(red: red, green: green, blue: blue)

let surfaceSaturation = isDark
  ? clamp(seed.saturation * 0.48, 0.16, 0.42)
  : clamp(seed.saturation * 0.22, 0.08, 0.24)
let surfaceBrightness = isDark
  ? clamp(0.16 + seed.brightness * 0.12, 0.19, 0.31)
  : clamp(0.86 + seed.brightness * 0.08, 0.88, 0.96)
let surface = hsbToRgb(hue: seed.hue, saturation: surfaceSaturation, brightness: surfaceBrightness)

// 0x8A = 54% opacity, giving a more translucent material surface.
print(String(format: "0x8A%02X%02X%02X", surface.red, surface.green, surface.blue))
