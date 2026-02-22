import SwiftUI

/// GPU-powered shader overlay for the working state (OSC 7778).
/// Mirrors the implementation in fadicode's SurfaceView.swift but with
/// exposed tuning parameters for the debug panel.
struct WorkingStateOverlay: View {
    let isActive: Bool
    let isFocused: Bool
    var themeColor: NSColor? = nil

    // Tuning knobs
    var mode: Int = 5
    var speed: Double = 1.0
    var maxIntensity: Double = 1.0
    var focusedIntensity: Double = 0.08
    var focusInDuration: Double = 0.2
    var focusOutDuration: Double = 0.5
    var pixelSize: Double = 0.0
    var gridOpacity: Double = 0.6
    var posterizeLevels: Double = 5.0

    @State private var intensity: Double = 0.0
    @State private var isVisible: Bool = false
    @State private var startDate: Date = .now

    private var themeRGB: (r: Double, g: Double, b: Double) {
        guard let tc = themeColor else { return (0.3, 0.6, 1.0) }
        let c = tc.usingColorSpace(.sRGB) ?? tc
        return (
            r: Double(c.redComponent),
            g: Double(c.greenComponent),
            b: Double(c.blueComponent)
        )
    }

    var body: some View {
        Group {
            if isVisible {
                ZStack {
                    // Dim layer: darkens terminal content underneath
                    Rectangle()
                        .fill(Color.black)
                        .opacity(intensity * 0.3)

                    // Shader layer: the visual effect
                    shaderView
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { active in
            if active {
                startDate = .now
                isVisible = true
                let target = isFocused ? focusedIntensity : maxIntensity
                withAnimation(.easeIn(duration: 0.4)) {
                    intensity = target
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    intensity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if !isActive { isVisible = false }
                }
            }
        }
        .onChange(of: isFocused) { focused in
            guard isActive else { return }
            if focused {
                withAnimation(.easeOut(duration: focusInDuration)) {
                    intensity = focusedIntensity
                }
            } else {
                withAnimation(.easeIn(duration: focusOutDuration)) {
                    intensity = maxIntensity
                }
            }
        }
        // Live-update intensity when tuning knobs change while active
        .onChange(of: maxIntensity) { newVal in
            guard isActive && !isFocused else { return }
            withAnimation(.easeInOut(duration: 0.15)) { intensity = newVal }
        }
        .onChange(of: focusedIntensity) { newVal in
            guard isActive && isFocused else { return }
            withAnimation(.easeInOut(duration: 0.15)) { intensity = newVal }
        }
    }

    // Maps mode index to the stitchable shader function name in each .metal file
    private static let shaderNames: [Int: String] = [
        0:  "organicFlowEffect",
        1:  "mandalaEffect",
        2:  "pointCloudEffect",
        3:  "auroraEffect",
        4:  "pulseGridEffect",
        5:  "combinedEffect",
        6:  "lightGridEffect",
        7:  "sinebowEffect",
        8:  "gradientSpinEffect",
        9:  "circleWaveEffect",
        10: "kaleidoscopeEffect",
        11: "plasmaEffect",
        12: "voronoiEffect",
        13: "spiralGalaxyEffect",
        14: "ripplePondEffect",
        15: "lavaLampEffect",
        16: "sacredGeometryEffect",
        17: "warpTunnelEffect",
        18: "fractalRingsEffect",
        19: "moireEffect",
    ]

    @ViewBuilder
    private var shaderView: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate) * speed
            GeometryReader { geo in
                let funcName = Self.shaderNames[mode] ?? "combinedEffect"
                let fn = ShaderLibrary[dynamicMember: funcName]
                Rectangle()
                    .fill(Color.white)
                    .colorEffect(
                        fn(
                            .float(Float(elapsed)),
                            .float(Float(intensity)),
                            .float(Float(themeRGB.r)),
                            .float(Float(themeRGB.g)),
                            .float(Float(themeRGB.b)),
                            .float(Float(geo.size.width)),
                            .float(Float(geo.size.height)),
                            .float(Float(pixelSize)),
                            .float(Float(gridOpacity)),
                            .float(Float(posterizeLevels))
                        )
                    )
                    .drawingGroup()
            }
        }
    }
}
