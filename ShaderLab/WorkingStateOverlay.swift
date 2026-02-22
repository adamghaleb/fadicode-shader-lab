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
    var hueSpread: Double = 0.10
    var complementMix: Double = 0.0
    var transitionDuration: Double = 2.0

    @State private var intensity: Double = 0.0
    @State private var isVisible: Bool = false
    @State private var startDate: Date = .now

    // Transition state
    @State private var previousMode: Int? = nil
    @State private var transitionStart: Date? = nil
    @State private var lastKnownMode: Int? = nil

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
        .onChange(of: mode) { newMode in
            guard isVisible else {
                lastKnownMode = newMode
                return
            }
            if let old = lastKnownMode, old != newMode {
                previousMode = old
                transitionStart = .now
            }
            lastKnownMode = newMode
        }
        .onAppear { lastKnownMode = mode }
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
        20: "chrysanthemumEffect",
        21: "machineElvesEffect",
        22: "hyperspaceEffect",
        23: "jewelLatticeEffect",
        24: "neuralBloomEffect",
        25: "egoDissolutionEffect",
        26: "foldingDimensionsEffect",
        27: "cymaticsEffect",
        28: "cosmicWebEffect",
        29: "topographicFlowEffect",
        30: "interferenceCrystalEffect",
        31: "nebulaCloudEffect",
        32: "dnaHelixEffect",
        33: "tessellationDanceEffect",
        34: "entityPresenceEffect",
        35: "fractalMandelbrotEffect",
        36: "quantumFieldEffect",
        37: "geometricAlchemyEffect",
        38: "wormholeEffect",
        39: "celestialClockworkEffect",
        40: "crystalCavernEffect",
        41: "electricFieldEffect",
        42: "resonanceEffect",
        43: "spiritMoleculeEffect",
        44: "flowerOfLifeEffect",
        45: "infiniteZoomEffect",
        46: "stringTheoryEffect",
        47: "penroseTilingEffect",
        48: "akashicFieldEffect",
        49: "breathOfGodEffect",
        50: "metatronsCubeEffect",
        51: "voidBloomEffect",
        52: "weaversLoomEffect",
        53: "timecrystalEffect",
        54: "resonanceChamberEffect",
        55: "eventHorizonEffect",
        56: "architectsGazeEffect",
        57: "sigilNetworkEffect",
        58: "dreamCatcherEffect",
    ]

    // Raw shader layer: outputs auto-contrasted grayscale luminance.
    // No theme color, no posterize, no pixelate — those are in post-process.
    private func rawShaderLayer(modeIndex: Int, elapsed: Double, size: CGSize) -> some View {
        let funcName = Self.shaderNames[modeIndex] ?? "combinedEffect"
        let fn = ShaderLibrary[dynamicMember: funcName]
        return Rectangle()
            .fill(Color.white)
            .colorEffect(
                fn(
                    .float(Float(elapsed)),
                    .float(Float(intensity)),
                    .float(Float(themeRGB.r)),
                    .float(Float(themeRGB.g)),
                    .float(Float(themeRGB.b)),
                    .float(Float(size.width)),
                    .float(Float(size.height)),
                    .float(Float(pixelSize)),
                    .float(Float(gridOpacity)),
                    .float(Float(posterizeLevels)),
                    .float(Float(hueSpread)),
                    .float(Float(complementMix))
                )
            )
    }

    // Full pipeline: raw grayscale → blur → posterize + pixelate + grid
    private func processedShaderLayer(modeIndex: Int, elapsed: Double, size: CGSize) -> some View {
        let blurR = pixelSize > 1 ? pixelSize * 0.4 : 0.0
        let maxOff = CGSize(width: max(pixelSize, 1), height: max(pixelSize, 1))
        return rawShaderLayer(modeIndex: modeIndex, elapsed: elapsed, size: size)
            .blur(radius: blurR)
            .drawingGroup()
            .layerEffect(
                ShaderLibrary.posterizePixelateEffect(
                    .float(Float(pixelSize)),
                    .float(Float(gridOpacity)),
                    .float(Float(posterizeLevels)),
                    .float(Float(themeRGB.r)),
                    .float(Float(themeRGB.g)),
                    .float(Float(themeRGB.b)),
                    .float(Float(hueSpread)),
                    .float(Float(complementMix))
                ),
                maxSampleOffset: maxOff
            )
    }

    @ViewBuilder
    private var shaderView: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate) * speed
            GeometryReader { geo in
                let size = geo.size

                if let prevMode = previousMode, let transStart = transitionStart {
                    // Transition in progress
                    let transElapsed = timeline.date.timeIntervalSince(transStart)
                    let rawProgress = min(transElapsed / max(transitionDuration, 0.01), 1.0)
                    let progress = rawProgress * rawProgress * (3.0 - 2.0 * rawProgress)

                    let _ = {
                        if rawProgress >= 1.0 {
                            DispatchQueue.main.async {
                                self.previousMode = nil
                                self.transitionStart = nil
                            }
                        }
                    }()

                    ZStack {
                        // Old shader: luma fade-out (bright parts vanish first)
                        processedShaderLayer(modeIndex: prevMode, elapsed: elapsed, size: size)
                            .colorEffect(
                                ShaderLibrary.lumaFadeOutEffect(
                                    .float(Float(progress))
                                )
                            )
                            .drawingGroup()

                        // New shader: luma fade-in (bright parts appear first)
                        processedShaderLayer(modeIndex: mode, elapsed: elapsed, size: size)
                            .colorEffect(
                                ShaderLibrary.lumaFadeInEffect(
                                    .float(Float(progress))
                                )
                            )
                            .drawingGroup()
                    }
                } else {
                    // No transition — single shader, full pipeline
                    processedShaderLayer(modeIndex: mode, elapsed: elapsed, size: size)
                        .drawingGroup()
                }
            }
        }
    }
}
