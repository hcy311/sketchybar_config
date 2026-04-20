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
let fallback = isDark ? "0x82282124" : "0x82F4EFEA"

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
let bucketCount = 64

var buckets = Array(repeating: Bucket(), count: bucketCount)
var ambientRed = 0.0
var ambientGreen = 0.0
var ambientBlue = 0.0
var ambientWeight = 0.0

for xIndex in 0..<samples {
  for yIndex in 0..<samples {
    let x = max(0, min(width - 1, (xIndex * width) / samples))
    let y = max(0, min(height - 1, (yIndex * height) / samples))

    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
      continue
    }

    let red = Double(color.redComponent)
    let green = Double(color.greenComponent)
    let blue = Double(color.blueComponent)
    let hsb = rgbToHsb(red: red, green: green, blue: blue)
    let yRatio = Double(y) / Double(max(height - 1, 1))
    let topBias = yRatio < 0.22
    let weight = topBias ? 2.7 : (yRatio < 0.45 ? 1.35 : 0.65)

    if hsb.brightness > 0.08 && hsb.brightness < 0.97 {
      ambientRed += red * weight
      ambientGreen += green * weight
      ambientBlue += blue * weight
      ambientWeight += weight
    }

    // Material You-like seed selection: prefer pleasant colorful mid-tones
    // around the menu-bar area instead of raw full-image dominance.
    if hsb.saturation < 0.12 || hsb.brightness < 0.14 || hsb.brightness > 0.92 {
      continue
    }

    let bucketIndex = min(bucketCount - 1, Int(hsb.hue * Double(bucketCount)))
    buckets[bucketIndex].red += red * weight
    buckets[bucketIndex].green += green * weight
    buckets[bucketIndex].blue += blue * weight
    buckets[bucketIndex].saturation += hsb.saturation * weight
    buckets[bucketIndex].brightness += hsb.brightness * weight
    buckets[bucketIndex].count += weight
    if topBias {
      buckets[bucketIndex].topWeight += weight
    }
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

guard let selected = best?.element, selected.count > 0 else {
  print(fallback)
  exit(0)
}

let red = selected.red / selected.count
let green = selected.green / selected.count
let blue = selected.blue / selected.count
let seed = rgbToHsb(red: red, green: green, blue: blue)
let ambient = ambientWeight > 0
  ? rgbToHsb(red: ambientRed / ambientWeight, green: ambientGreen / ambientWeight, blue: ambientBlue / ambientWeight)
  : seed

let surfaceSaturation = isDark
  ? clamp(seed.saturation * 0.16, 0.055, 0.14)
  : clamp(seed.saturation * 0.08, 0.025, 0.08)
let surfaceBrightness = isDark
  ? clamp(0.16 + (1.0 - ambient.brightness) * 0.055 + seed.brightness * 0.025, 0.17, 0.235)
  : clamp(0.92 + ambient.brightness * 0.035, 0.92, 0.965)
let tintedSurface = hsbToRgb(hue: seed.hue, saturation: surfaceSaturation, brightness: surfaceBrightness)
let neutralSurface = isDark
  ? (red: 40, green: 37, blue: 40)
  : (red: 244, green: 239, blue: 234)
let surface = mix(neutralSurface, tintedSurface, amount: isDark ? 0.38 : 0.28)

// 0x82 = 51% opacity. The hue is intentionally subtle: the bar should feel
// harmonized with the wallpaper, not painted with the wallpaper's accent color.
print(String(format: "0x82%02X%02X%02X", surface.red, surface.green, surface.blue))
