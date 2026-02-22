import SwiftUI

/// Available Inferno shader effects for the preview overlay.
enum InfernoShader: String, CaseIterable, Identifiable {
    case none            = "None"
    case lightGrid       = "Light Grid"
    case sinebow         = "Sinebow"
    case animatedGradient = "Gradient Spin"
    case circleWave      = "Circle Wave"
    case infrared        = "Infrared"
    case interlace       = "CRT Scanlines"
    case checkerboard    = "Checkerboard"
    case rainbowNoise    = "Rainbow Noise"
    case whiteNoise      = "White Noise"
    case shimmer         = "Shimmer"
    case water           = "Water"
    case wave            = "Wave"
    case relativeWave    = "Relative Wave"
    case emboss          = "Emboss"
    case chromatic       = "Chromatic Aberration"
    case swirl           = "Swirl"
    case pixellate       = "Pixellate"

    var id: String { rawValue }

    /// Describes a tunable parameter for an Inferno shader.
    struct ParamDef {
        let name: String
        let defaultValue: Double
        let range: ClosedRange<Double>
    }

    /// The tunable parameters for each shader (up to 4 slots).
    var parameterDefs: [ParamDef] {
        switch self {
        case .none:
            return []
        case .lightGrid:
            return [
                ParamDef(name: "Density",    defaultValue: 8,   range: 1...50),
                ParamDef(name: "Speed",      defaultValue: 3,   range: 1...20),
                ParamDef(name: "Group Size", defaultValue: 1,   range: 1...8),
                ParamDef(name: "Brightness", defaultValue: 3,   range: 0.2...10),
            ]
        case .sinebow, .animatedGradient, .rainbowNoise, .whiteNoise, .infrared:
            return []
        case .circleWave:
            return [
                ParamDef(name: "Brightness", defaultValue: 3,   range: 0.5...10),
                ParamDef(name: "Speed",      defaultValue: 2,   range: 0.5...10),
                ParamDef(name: "Strength",   defaultValue: 1.5, range: 0.5...5),
                ParamDef(name: "Density",    defaultValue: 40,  range: 5...100),
            ]
        case .interlace:
            return [
                ParamDef(name: "Line Width", defaultValue: 3,   range: 1...10),
                ParamDef(name: "Strength",   defaultValue: 0.5, range: 0...1),
            ]
        case .checkerboard:
            return [
                ParamDef(name: "Size", defaultValue: 12, range: 4...40),
            ]
        case .shimmer:
            return [
                ParamDef(name: "Duration",       defaultValue: 2,   range: 0.5...5),
                ParamDef(name: "Gradient Width", defaultValue: 0.3, range: 0.1...1),
                ParamDef(name: "Max Lightness",  defaultValue: 0.5, range: 0...1),
            ]
        case .water:
            return [
                ParamDef(name: "Speed",     defaultValue: 3,  range: 0.5...10),
                ParamDef(name: "Strength",  defaultValue: 3,  range: 1...10),
                ParamDef(name: "Frequency", defaultValue: 10, range: 5...25),
            ]
        case .wave:
            return [
                ParamDef(name: "Speed",     defaultValue: 5,  range: 1...15),
                ParamDef(name: "Smoothing", defaultValue: 20, range: 5...50),
                ParamDef(name: "Strength",  defaultValue: 5,  range: 1...20),
            ]
        case .relativeWave:
            return [
                ParamDef(name: "Speed",     defaultValue: 5,  range: 1...15),
                ParamDef(name: "Smoothing", defaultValue: 20, range: 5...50),
                ParamDef(name: "Strength",  defaultValue: 10, range: 1...30),
            ]
        case .emboss:
            return [
                ParamDef(name: "Strength", defaultValue: 2, range: 0.5...5),
            ]
        case .chromatic:
            return [
                ParamDef(name: "Amount", defaultValue: 5, range: 1...15),
            ]
        case .swirl:
            return [
                ParamDef(name: "Radius", defaultValue: 0.5, range: 0.1...1),
                ParamDef(name: "Speed",  defaultValue: 0.5, range: 0.1...2),
            ]
        case .pixellate:
            return [
                ParamDef(name: "Squares", defaultValue: 20, range: 5...50),
                ParamDef(name: "Steps",   defaultValue: 5,  range: 2...10),
            ]
        }
    }

    /// The type of SwiftUI shader modifier this effect needs.
    var shaderType: ShaderType {
        switch self {
        case .none: return .none
        case .water, .wave, .relativeWave: return .distortion
        case .emboss, .chromatic, .swirl, .pixellate: return .layer
        default: return .color
        }
    }

    enum ShaderType {
        case none, color, layer, distortion

        var label: String {
            switch self {
            case .none: return "NONE"
            case .color: return "COLOR"
            case .layer: return "LAYER"
            case .distortion: return "DISTORTION"
            }
        }

        var tint: Color {
            switch self {
            case .none: return .gray
            case .color: return .green
            case .layer: return .orange
            case .distortion: return .cyan
            }
        }
    }
}

/// Overlay that applies the selected Inferno shader on top of the terminal content.
@available(macOS 14.0, *)
struct InfernoPreviewOverlay: View {
    let shader: InfernoShader
    let themeColor: NSColor
    let param1: Double
    let param2: Double
    let param3: Double
    let param4: Double

    @State private var startDate: Date = .now

    private var themeRGB: (r: Double, g: Double, b: Double) {
        let c = themeColor.usingColorSpace(.sRGB) ?? themeColor
        return (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
    }

    var body: some View {
        if shader == .none {
            EmptyView()
        } else {
            TimelineView(.animation) { timeline in
                let elapsed = Float(timeline.date.timeIntervalSince(startDate))
                GeometryReader { geo in
                    let size = CGPoint(x: geo.size.width, y: geo.size.height)

                    switch shader.shaderType {
                    case .none:
                        EmptyView()

                    case .color:
                        Rectangle()
                            .fill(Color.white)
                            .colorEffect(colorShader(shader, size: size, time: elapsed))
                            .drawingGroup()

                    case .layer:
                        Rectangle()
                            .fill(Color.white)
                            .layerEffect(
                                layerShader(shader, size: size, time: elapsed),
                                maxSampleOffset: CGSize(width: 20, height: 20)
                            )
                            .drawingGroup()

                    case .distortion:
                        Rectangle()
                            .fill(Color.white.opacity(0.001)) // needs content for distortion
                            .distortionEffect(
                                distortionShader(shader, size: size, time: elapsed),
                                maxSampleOffset: CGSize(width: 20, height: 20)
                            )
                    }
                }
            }
            .allowsHitTesting(false)
            .opacity(0.6)
        }
    }

    // MARK: - Color Effect Shaders

    private func colorShader(_ shader: InfernoShader, size: CGPoint, time: Float) -> Shader {
        switch shader {
        case .lightGrid:
            return ShaderLibrary.lightGrid(
                .float2(size), .float(time),
                .float(param1), // density
                .float(param2), // speed
                .float(param3), // groupSize
                .float(param4)  // brightness
            )
        case .sinebow:
            return ShaderLibrary.sinebow(.float2(size), .float(time))
        case .animatedGradient:
            return ShaderLibrary.animatedGradientFill(.float2(size), .float(time))
        case .circleWave:
            return ShaderLibrary.circleWave(
                .float2(size), .float(time),
                .float(param1), // brightness
                .float(param2), // speed
                .float(param3), // strength
                .float(param4), // density
                .float2(CGPoint(x: 0.5, y: 0.5)),
                .color(Color(red: themeRGB.r, green: themeRGB.g, blue: themeRGB.b))
            )
        case .infrared:
            return ShaderLibrary.infrared()
        case .interlace:
            return ShaderLibrary.interlace(
                .float(param1), // width
                .color(.black),
                .float(param2)  // strength
            )
        case .checkerboard:
            return ShaderLibrary.checkerboard(
                .color(Color(red: themeRGB.r, green: themeRGB.g, blue: themeRGB.b).opacity(0.3)),
                .float(param1)  // size
            )
        case .rainbowNoise:
            return ShaderLibrary.rainbowNoise(.float(time))
        case .whiteNoise:
            return ShaderLibrary.whiteNoise(.float(time))
        case .shimmer:
            return ShaderLibrary.shimmer(
                .float2(size), .float(time),
                .float(param1), // animationDuration
                .float(param2), // gradientWidth
                .float(param3)  // maxLightness
            )
        default:
            return ShaderLibrary.passthrough()
        }
    }

    // MARK: - Layer Effect Shaders

    private func layerShader(_ shader: InfernoShader, size: CGPoint, time: Float) -> Shader {
        switch shader {
        case .emboss:
            return ShaderLibrary.emboss(.float(param1)) // strength
        case .chromatic:
            let amount = sin(time * 2) * Float(param1) // amplitude from param1
            return ShaderLibrary.colorPlanes(.float2(CGPoint(x: CGFloat(amount), y: CGFloat(amount))))
        case .swirl:
            let amount = (sin(time * Float(param2)) + 1) / 2 // speed from param2
            return ShaderLibrary.swirl(.float2(size), .float(amount), .float(param1)) // radius from param1
        case .pixellate:
            let amount = (sin(time * 0.3) + 1) / 2
            return ShaderLibrary.pixellateTransition(.float2(size), .float(amount), .float(param1), .float(param2)) // squares, steps
        default:
            return ShaderLibrary.emboss(.float(0))
        }
    }

    // MARK: - Distortion Effect Shaders

    private func distortionShader(_ shader: InfernoShader, size: CGPoint, time: Float) -> Shader {
        switch shader {
        case .water:
            return ShaderLibrary.water(
                .float2(size), .float(time),
                .float(param1), // speed
                .float(param2), // strength
                .float(param3)  // frequency
            )
        case .wave:
            return ShaderLibrary.wave(
                .float(time),
                .float(param1), // speed
                .float(param2), // smoothing
                .float(param3)  // strength
            )
        case .relativeWave:
            return ShaderLibrary.relativeWave(
                .float2(size), .float(time),
                .float(param1), // speed
                .float(param2), // smoothing
                .float(param3)  // strength
            )
        default:
            return ShaderLibrary.wave(.float(time), .float(0), .float(1), .float(0))
        }
    }
}
