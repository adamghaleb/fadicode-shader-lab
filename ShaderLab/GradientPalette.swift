import SwiftUI

// MARK: - Data Model

struct PaletteStop: Identifiable, Equatable {
    let id: UUID
    var color: NSColor
    var position: Float // 0.0–1.0

    init(color: NSColor, position: Float) {
        self.id = UUID()
        self.color = color
        self.position = position
    }

    var rgb: (r: Float, g: Float, b: Float) {
        let c = color.usingColorSpace(.sRGB) ?? color
        return (Float(c.redComponent), Float(c.greenComponent), Float(c.blueComponent))
    }
}

struct GradientPalette: Identifiable, Equatable {
    let id: UUID
    let name: String
    var stops: [PaletteStop] // 2–8 stops, sorted by position
    let isBuiltIn: Bool

    init(name: String, stops: [PaletteStop], isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.stops = stops.sorted { $0.position < $1.position }
        self.isBuiltIn = isBuiltIn
    }

    /// Flattened RGB floats for the shader (24 values: 8 stops x 3 channels).
    /// Unused stops repeat the last color.
    func toFloatArray() -> [Float] {
        var result = [Float](repeating: 0, count: 24)
        let sorted = stops.sorted { $0.position < $1.position }
        for i in 0..<8 {
            let stop = i < sorted.count ? sorted[i] : sorted.last!
            let rgb = stop.rgb
            result[i * 3 + 0] = rgb.r
            result[i * 3 + 1] = rgb.g
            result[i * 3 + 2] = rgb.b
        }
        return result
    }

    /// SwiftUI gradient for preview strips
    var swiftUIGradient: LinearGradient {
        let sorted = stops.sorted { $0.position < $1.position }
        let gradStops = sorted.map { stop in
            Gradient.Stop(color: Color(nsColor: stop.color), location: CGFloat(stop.position))
        }
        return LinearGradient(
            stops: gradStops,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func == (lhs: GradientPalette, rhs: GradientPalette) -> Bool {
        lhs.id == rhs.id && lhs.stops == rhs.stops
    }
}

// MARK: - Palette Mode

enum PaletteMode: Int, CaseIterable {
    case auto = 0
    case preset = 1
    case custom = 2

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .preset: return "Theme"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Auto Palette Generator

/// Generates a gradient palette from theme color using warm-cool hue shifting:
/// dark stops lean cool (away from yellow), bright stops lean warm (toward yellow).
/// Contrast controls the power curve on the brightness ramp.
func generateAutoPalette(themeColor: NSColor, hueSpread: Float, complementMix: Float, contrast: Float, saturation: Float, maxBrightness: Float = 1.0, levels: Int) -> GradientPalette {
    let c = themeColor.usingColorSpace(.sRGB) ?? themeColor
    let r = Float(c.redComponent)
    let g = Float(c.greenComponent)
    let b = Float(c.blueComponent)
    let themeHSV = rgbToHSV(r: r, g: g, b: b)
    let baseHue = themeHSV.h
    // Respect the theme's actual saturation — grays/whites/browns stay muted
    let baseSat = max(themeHSV.s, 0.05)

    // Warm-cool direction: find which way yellow (warm) is on the hue circle
    let warmTarget: Float = 0.167
    var toWarm = warmTarget - baseHue
    if toWarm > 0.5 { toWarm -= 1.0 }
    if toWarm < -0.5 { toWarm += 1.0 }
    let warmSign: Float = toWarm >= 0 ? 1.0 : -1.0

    let stopCount = min(max(levels, 3), 8)
    var stops: [PaletteStop] = []

    for i in 0..<stopCount {
        let q = Float(i) / Float(stopCount - 1)
        let position = q

        let topBand = Float(stopCount - 1) / Float(stopCount)
        let bridgeBand = Float(stopCount - 2) / Float(stopCount)

        // Asymmetric warm-cool hue ramp
        // t = -1 at darkest, +1 at brightest
        let t = q * 2.0 - 1.0
        // Bright: shift toward yellow, clamped so it can't overshoot past yellow
        // Dark: shift away from yellow (cool direction), full hueSpread
        let hueOffset: Float
        if t >= 0 {
            let warmExtent = min(hueSpread, abs(toWarm))
            hueOffset = warmSign * warmExtent * t
        } else {
            hueOffset = warmSign * hueSpread * t
        }
        let hue = fmodf(baseHue + hueOffset + 1.0, 1.0)

        // Saturation curve
        let satCurve = 1.0 - (t * t) * 0.5
        var sat = baseSat * satCurve
        sat = max(sat, baseSat * 0.3)
        sat = mix(sat * 1.15, sat, smoothstepf(0.0, 0.4, q))
        // Contrast subtly boosts saturation in midtones
        sat *= mix(1.0, 1.15, max(contrast - 1.0, 0.0))
        // Saturation multiplier
        sat *= saturation
        sat = min(sat, 1.0)

        // Value ramp with contrast power curve, capped by maxBrightness
        let contrastQ = powf(q, contrast)
        var val = mix(0.06, maxBrightness * 1.2, contrastQ)
        val = min(max(val, 0.0), maxBrightness)

        // Top band → bright ceiling, bridge band → light desaturated
        if q >= topBand {
            sat = maxBrightness >= 1.0 ? 0.0 : sat * 0.3
            val = maxBrightness
        } else if q >= bridgeBand {
            sat *= 0.3
            val = mix(val, maxBrightness, 0.65)
        }

        var finalR: Float, finalG: Float, finalB: Float
        (finalR, finalG, finalB) = hsvToRGB(h: hue, s: sat, v: val)

        // Complement blend in highlights
        if complementMix > 0.001 {
            let compHue = fmodf(baseHue + 0.5, 1.0)
            let compSat = baseSat * 0.85
            let (cr, cg, cb) = hsvToRGB(h: compHue, s: compSat, v: val)
            let compBlend = smoothstepf(0.55, 1.0, q) * complementMix
            finalR = mix(finalR, cr, compBlend)
            finalG = mix(finalG, cg, compBlend)
            finalB = mix(finalB, cb, compBlend)
        }

        let nsColor = NSColor(red: CGFloat(finalR), green: CGFloat(finalG), blue: CGFloat(finalB), alpha: 1.0)
        stops.append(PaletteStop(color: nsColor, position: position))
    }

    return GradientPalette(name: "Auto", stops: stops, isBuiltIn: true)
}

// MARK: - Theme Palette Generators

/// Generates 7 palettes derived from the current theme color.
func generateThemePalettes(themeColor: NSColor) -> [GradientPalette] {
    let c = themeColor.usingColorSpace(.sRGB) ?? themeColor
    let r = Float(c.redComponent), g = Float(c.greenComponent), b = Float(c.blueComponent)
    let hsv = rgbToHSV(r: r, g: g, b: b)
    let h = hsv.h
    let s = max(hsv.s, 0.5)
    let v = max(hsv.v, 0.5)

    return [
        themeMonochromatic(h: h, s: s, v: v),
        themeAnalogous(h: h, s: s, v: v),
        themeComplementary(h: h, s: s, v: v),
        themeSplitComplementary(h: h, s: s, v: v),
        themeTriadic(h: h, s: s, v: v),
        themeHighContrast(h: h, s: s, v: v),
        themeWarmCoolShift(h: h, s: s, v: v),
    ]
}

private func makeStop(_ h: Float, _ s: Float, _ v: Float, _ pos: Float) -> PaletteStop {
    let (r, g, b) = hsvToRGB(h: fmodf(h + 1.0, 1.0), s: min(max(s, 0), 1), v: min(max(v, 0), 1))
    return PaletteStop(color: NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1), position: pos)
}

private func themeMonochromatic(h: Float, s: Float, v: Float) -> GradientPalette {
    GradientPalette(name: "Mono", stops: [
        makeStop(h, s * 0.3, 0.05, 0.0),
        makeStop(h, s * 0.6, 0.20, 0.2),
        makeStop(h, s * 0.9, 0.45, 0.4),
        makeStop(h, s,       0.70, 0.6),
        makeStop(h, s * 0.7, 0.88, 0.8),
        makeStop(h, s * 0.2, 1.00, 1.0),
    ], isBuiltIn: true)
}

private func themeAnalogous(h: Float, s: Float, v: Float) -> GradientPalette {
    GradientPalette(name: "Analogous", stops: [
        makeStop(h - 0.083, s * 0.5, 0.06, 0.0),
        makeStop(h - 0.055, s * 0.8, 0.25, 0.2),
        makeStop(h - 0.028, s,       0.50, 0.4),
        makeStop(h,         s,       0.72, 0.55),
        makeStop(h + 0.040, s * 0.9, 0.88, 0.75),
        makeStop(h + 0.083, s * 0.4, 1.00, 1.0),
    ], isBuiltIn: true)
}

private func themeComplementary(h: Float, s: Float, v: Float) -> GradientPalette {
    let comp = h + 0.5
    return GradientPalette(name: "Complement", stops: [
        makeStop(h,    s * 0.4, 0.05, 0.0),
        makeStop(h,    s,       0.35, 0.2),
        makeStop(h,    s,       0.65, 0.4),
        makeStop(comp, s * 0.8, 0.65, 0.6),
        makeStop(comp, s,       0.85, 0.8),
        makeStop(comp, s * 0.3, 1.00, 1.0),
    ], isBuiltIn: true)
}

private func themeSplitComplementary(h: Float, s: Float, v: Float) -> GradientPalette {
    let sc1 = h + 0.417 // complement - 30°
    let sc2 = h + 0.583 // complement + 30°
    return GradientPalette(name: "Split Comp", stops: [
        makeStop(h,   s * 0.4, 0.05, 0.0),
        makeStop(h,   s,       0.40, 0.2),
        makeStop(sc1, s * 0.9, 0.60, 0.4),
        makeStop(h,   s * 0.5, 0.75, 0.6),
        makeStop(sc2, s * 0.9, 0.88, 0.8),
        makeStop(sc2, s * 0.3, 1.00, 1.0),
    ], isBuiltIn: true)
}

private func themeTriadic(h: Float, s: Float, v: Float) -> GradientPalette {
    let t1 = h + 0.333
    let t2 = h + 0.667
    return GradientPalette(name: "Triadic", stops: [
        makeStop(h,  s * 0.4, 0.05, 0.0),
        makeStop(h,  s,       0.40, 0.2),
        makeStop(t1, s,       0.65, 0.45),
        makeStop(t2, s,       0.78, 0.65),
        makeStop(t2, s * 0.6, 0.92, 0.85),
        makeStop(h,  s * 0.2, 1.00, 1.0),
    ], isBuiltIn: true)
}

private func themeHighContrast(h: Float, s: Float, v: Float) -> GradientPalette {
    GradientPalette(name: "Hi-Contrast", stops: [
        makeStop(h, 0.0, 0.0, 0.0),
        makeStop(h, s,   0.20, 0.2),
        makeStop(h, s,   0.55, 0.4),
        makeStop(h, s,   0.80, 0.6),
        makeStop(h, s * 0.5, 0.95, 0.8),
        makeStop(h, 0.0, 1.0, 1.0),
    ], isBuiltIn: true)
}

private func themeWarmCoolShift(h: Float, s: Float, v: Float) -> GradientPalette {
    // If theme is warm (hue 0–0.17 or 0.83–1.0), shift toward cool; otherwise shift toward warm
    let isWarm = h < 0.17 || h > 0.83
    let shift: Float = isWarm ? 0.33 : -0.25
    return GradientPalette(name: isWarm ? "Cool Shift" : "Warm Shift", stops: [
        makeStop(h,             s * 0.3, 0.05, 0.0),
        makeStop(h,             s,       0.30, 0.2),
        makeStop(h + shift * 0.3, s,     0.50, 0.4),
        makeStop(h + shift * 0.6, s,     0.70, 0.6),
        makeStop(h + shift,       s * 0.8, 0.88, 0.8),
        makeStop(h + shift,       s * 0.3, 1.00, 1.0),
    ], isBuiltIn: true)
}

// MARK: - Swift-side HSV helpers (mirrors ShaderUtils.h)

private func rgbToHSV(r: Float, g: Float, b: Float) -> (h: Float, s: Float, v: Float) {
    let maxC = max(r, max(g, b))
    let minC = min(r, min(g, b))
    let d = maxC - minC
    var h: Float = 0
    let s = maxC > 0 ? d / maxC : 0
    let v = maxC
    if d > 1e-10 {
        if maxC == r { h = (g - b) / d + (g < b ? 6.0 : 0.0) }
        else if maxC == g { h = (b - r) / d + 2.0 }
        else { h = (r - g) / d + 4.0 }
        h /= 6.0
    }
    return (h, s, v)
}

private func hsvToRGB(h: Float, s: Float, v: Float) -> (Float, Float, Float) {
    let c = v * s
    let x = c * (1.0 - abs(fmodf(h * 6.0, 2.0) - 1.0))
    let m = v - c
    var r: Float = 0, g: Float = 0, b: Float = 0
    let seg = Int(h * 6.0) % 6
    switch seg {
    case 0: r = c; g = x; b = 0
    case 1: r = x; g = c; b = 0
    case 2: r = 0; g = c; b = x
    case 3: r = 0; g = x; b = c
    case 4: r = x; g = 0; b = c
    default: r = c; g = 0; b = x
    }
    return (r + m, g + m, b + m)
}

private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    return a + (b - a) * t
}

private func smoothstepf(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)
}

// MARK: - Preset Palettes

let presetPalettes: [GradientPalette] = [
    GradientPalette(name: "Ocean", stops: [
        PaletteStop(color: NSColor(red: 0.02, green: 0.05, blue: 0.15, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.05, green: 0.15, blue: 0.35, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.10, green: 0.40, blue: 0.65, alpha: 1), position: 0.4),
        PaletteStop(color: NSColor(red: 0.20, green: 0.65, blue: 0.85, alpha: 1), position: 0.6),
        PaletteStop(color: NSColor(red: 0.55, green: 0.85, blue: 0.95, alpha: 1), position: 0.8),
        PaletteStop(color: NSColor(red: 0.90, green: 0.97, blue: 1.00, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Ember", stops: [
        PaletteStop(color: NSColor(red: 0.10, green: 0.02, blue: 0.02, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.40, green: 0.05, blue: 0.02, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.75, green: 0.15, blue: 0.05, alpha: 1), position: 0.4),
        PaletteStop(color: NSColor(red: 0.95, green: 0.40, blue: 0.10, alpha: 1), position: 0.6),
        PaletteStop(color: NSColor(red: 1.00, green: 0.70, blue: 0.25, alpha: 1), position: 0.8),
        PaletteStop(color: NSColor(red: 1.00, green: 0.95, blue: 0.80, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Forest", stops: [
        PaletteStop(color: NSColor(red: 0.02, green: 0.08, blue: 0.03, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.05, green: 0.20, blue: 0.08, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.12, green: 0.45, blue: 0.18, alpha: 1), position: 0.4),
        PaletteStop(color: NSColor(red: 0.30, green: 0.65, blue: 0.25, alpha: 1), position: 0.6),
        PaletteStop(color: NSColor(red: 0.60, green: 0.85, blue: 0.40, alpha: 1), position: 0.8),
        PaletteStop(color: NSColor(red: 0.88, green: 0.97, blue: 0.85, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Amethyst", stops: [
        PaletteStop(color: NSColor(red: 0.08, green: 0.02, blue: 0.15, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.20, green: 0.05, blue: 0.35, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.40, green: 0.12, blue: 0.60, alpha: 1), position: 0.4),
        PaletteStop(color: NSColor(red: 0.60, green: 0.30, blue: 0.80, alpha: 1), position: 0.6),
        PaletteStop(color: NSColor(red: 0.80, green: 0.55, blue: 0.95, alpha: 1), position: 0.8),
        PaletteStop(color: NSColor(red: 0.95, green: 0.88, blue: 1.00, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Rose", stops: [
        PaletteStop(color: NSColor(red: 0.12, green: 0.02, blue: 0.05, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.35, green: 0.05, blue: 0.15, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.65, green: 0.12, blue: 0.30, alpha: 1), position: 0.4),
        PaletteStop(color: NSColor(red: 0.90, green: 0.35, blue: 0.50, alpha: 1), position: 0.6),
        PaletteStop(color: NSColor(red: 1.00, green: 0.65, blue: 0.75, alpha: 1), position: 0.8),
        PaletteStop(color: NSColor(red: 1.00, green: 0.92, blue: 0.95, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Solar", stops: [
        PaletteStop(color: NSColor(red: 0.10, green: 0.05, blue: 0.00, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.40, green: 0.15, blue: 0.00, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.80, green: 0.35, blue: 0.00, alpha: 1), position: 0.35),
        PaletteStop(color: NSColor(red: 1.00, green: 0.60, blue: 0.05, alpha: 1), position: 0.5),
        PaletteStop(color: NSColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1), position: 0.7),
        PaletteStop(color: NSColor(red: 1.00, green: 0.95, blue: 0.70, alpha: 1), position: 0.85),
        PaletteStop(color: NSColor(red: 1.00, green: 1.00, blue: 0.95, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Neon", stops: [
        PaletteStop(color: NSColor(red: 0.00, green: 0.00, blue: 0.05, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.00, green: 0.90, blue: 0.40, alpha: 1), position: 0.25),
        PaletteStop(color: NSColor(red: 0.00, green: 0.60, blue: 1.00, alpha: 1), position: 0.5),
        PaletteStop(color: NSColor(red: 1.00, green: 0.00, blue: 0.80, alpha: 1), position: 0.75),
        PaletteStop(color: NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Retrowave", stops: [
        PaletteStop(color: NSColor(red: 0.05, green: 0.00, blue: 0.10, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.15, green: 0.00, blue: 0.30, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.50, green: 0.00, blue: 0.50, alpha: 1), position: 0.4),
        PaletteStop(color: NSColor(red: 1.00, green: 0.20, blue: 0.40, alpha: 1), position: 0.6),
        PaletteStop(color: NSColor(red: 1.00, green: 0.50, blue: 0.20, alpha: 1), position: 0.8),
        PaletteStop(color: NSColor(red: 0.95, green: 0.90, blue: 0.50, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Midnight", stops: [
        PaletteStop(color: NSColor(red: 0.00, green: 0.00, blue: 0.03, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1), position: 0.25),
        PaletteStop(color: NSColor(red: 0.10, green: 0.10, blue: 0.30, alpha: 1), position: 0.5),
        PaletteStop(color: NSColor(red: 0.25, green: 0.25, blue: 0.55, alpha: 1), position: 0.7),
        PaletteStop(color: NSColor(red: 0.50, green: 0.50, blue: 0.80, alpha: 1), position: 0.85),
        PaletteStop(color: NSColor(red: 0.85, green: 0.85, blue: 1.00, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Lava", stops: [
        PaletteStop(color: NSColor(red: 0.05, green: 0.00, blue: 0.00, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.30, green: 0.00, blue: 0.00, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.70, green: 0.10, blue: 0.00, alpha: 1), position: 0.4),
        PaletteStop(color: NSColor(red: 1.00, green: 0.30, blue: 0.00, alpha: 1), position: 0.55),
        PaletteStop(color: NSColor(red: 1.00, green: 0.65, blue: 0.00, alpha: 1), position: 0.7),
        PaletteStop(color: NSColor(red: 1.00, green: 0.90, blue: 0.30, alpha: 1), position: 0.85),
        PaletteStop(color: NSColor(red: 1.00, green: 1.00, blue: 0.90, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Arctic", stops: [
        PaletteStop(color: NSColor(red: 0.02, green: 0.05, blue: 0.10, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.10, green: 0.20, blue: 0.35, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.30, green: 0.50, blue: 0.65, alpha: 1), position: 0.4),
        PaletteStop(color: NSColor(red: 0.55, green: 0.75, blue: 0.85, alpha: 1), position: 0.6),
        PaletteStop(color: NSColor(red: 0.80, green: 0.90, blue: 0.95, alpha: 1), position: 0.8),
        PaletteStop(color: NSColor(red: 0.95, green: 0.98, blue: 1.00, alpha: 1), position: 1.0),
    ], isBuiltIn: true),

    GradientPalette(name: "Autumn", stops: [
        PaletteStop(color: NSColor(red: 0.08, green: 0.04, blue: 0.02, alpha: 1), position: 0.0),
        PaletteStop(color: NSColor(red: 0.30, green: 0.10, blue: 0.02, alpha: 1), position: 0.2),
        PaletteStop(color: NSColor(red: 0.60, green: 0.25, blue: 0.05, alpha: 1), position: 0.35),
        PaletteStop(color: NSColor(red: 0.85, green: 0.40, blue: 0.08, alpha: 1), position: 0.5),
        PaletteStop(color: NSColor(red: 0.95, green: 0.60, blue: 0.15, alpha: 1), position: 0.65),
        PaletteStop(color: NSColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1), position: 0.8),
        PaletteStop(color: NSColor(red: 0.95, green: 0.92, blue: 0.80, alpha: 1), position: 1.0),
    ], isBuiltIn: true),
]

/// Default custom palette (editable)
func makeDefaultCustomPalette() -> GradientPalette {
    GradientPalette(name: "Custom", stops: [
        PaletteStop(color: NSColor.black, position: 0.0),
        PaletteStop(color: NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1), position: 0.5),
        PaletteStop(color: NSColor.white, position: 1.0),
    ])
}
