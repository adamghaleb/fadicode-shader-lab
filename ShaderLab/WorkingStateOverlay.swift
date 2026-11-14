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
    var focusedOpacity: Double = 0.15
    var focusInDuration: Double = 0.2
    var focusOutDuration: Double = 0.5
    var pixelSize: Double = 0.0
    var gridOpacity: Double = 0.6
    var focusedGridOpacity: Double = 2.5
    var resolutionScale: Double = 1.0
    var posterizeLevels: Double = 5.0
    var hueSpread: Double = 0.10
    var complementMix: Double = 0.0
    var transitionDuration: Double = 3.0

    // Palette system
    var paletteFloats: [Float] = []
    var paletteCount: Int = 0

    // Per-shader tuning
    var shaderTunings: [Int: ShaderTuning] = [:]

    @State private var intensity: Double = 0.0
    @State private var shaderOpacity: Double = 0.0
    @State private var activeGridOpacity: Double = 0.6
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
                .opacity(shaderOpacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { active in
            if active {
                startDate = .now
                isVisible = true
                let target = isFocused ? focusedIntensity : maxIntensity
                let opacityTarget = isFocused ? focusedOpacity : 1.0
                let gridTarget = isFocused ? focusedGridOpacity : gridOpacity
                withAnimation(.easeIn(duration: 0.4)) {
                    intensity = target
                    shaderOpacity = opacityTarget
                    activeGridOpacity = gridTarget
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    intensity = 0.0
                    shaderOpacity = 0.0
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
                    shaderOpacity = focusedOpacity
                    activeGridOpacity = focusedGridOpacity
                }
            } else {
                withAnimation(.easeIn(duration: focusOutDuration)) {
                    intensity = maxIntensity
                    shaderOpacity = 1.0
                    activeGridOpacity = gridOpacity
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
        .onChange(of: focusedOpacity) { newVal in
            guard isActive && isFocused else { return }
            withAnimation(.easeInOut(duration: 0.15)) { shaderOpacity = newVal }
        }
        .onChange(of: gridOpacity) { newVal in
            guard isActive && !isFocused else { return }
            withAnimation(.easeInOut(duration: 0.15)) { activeGridOpacity = newVal }
        }
        .onChange(of: focusedGridOpacity) { newVal in
            guard isActive && isFocused else { return }
            withAnimation(.easeInOut(duration: 0.15)) { activeGridOpacity = newVal }
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
        .onAppear {
            lastKnownMode = mode
            activeGridOpacity = isFocused ? focusedGridOpacity : gridOpacity
            // Kick initial state if already active on appear
            if isActive {
                startDate = .now
                isVisible = true
                let target = isFocused ? focusedIntensity : maxIntensity
                let opacityTarget = isFocused ? focusedOpacity : 1.0
                withAnimation(.easeIn(duration: 0.4)) {
                    intensity = target
                    shaderOpacity = opacityTarget
                }
            }
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
    // When resolutionScale < 1, renders into a smaller frame and scales up
    // to reduce fragment count (since pixelation discards the extra detail anyway).
    private var renderScale: Double {
        // Full resolution when pixelation is off — low-res only makes sense
        // when pixel blocks mask the detail loss
        if pixelSize < 1 { return 1.0 }
        return max(min(resolutionScale, 1.0), 0.1)
    }

    private func rawShaderLayer(modeIndex: Int, elapsed: Double, size: CGSize, contrast: Double = 1.0, brightness: Double = 0.0) -> some View {
        let funcName = Self.shaderNames[modeIndex] ?? "combinedEffect"
        let fn = ShaderLibrary[dynamicMember: funcName]
        let scale = renderScale
        let renderW = size.width * scale
        let renderH = size.height * scale
        return Rectangle()
            .fill(Color.white)
            .frame(width: renderW, height: renderH)
            .colorEffect(
                fn(
                    .float(Float(elapsed)),
                    .float(Float(intensity)),
                    .float(Float(themeRGB.r)),
                    .float(Float(themeRGB.g)),
                    .float(Float(themeRGB.b)),
                    .float(Float(renderW)),
                    .float(Float(renderH)),
                    .float(Float(pixelSize * scale)),
                    .float(Float(activeGridOpacity)),
                    .float(Float(posterizeLevels)),
                    .float(Float(hueSpread)),
                    .float(Float(complementMix)),
                    .float(Float(contrast)),
                    .float(Float(brightness))
                )
            )
            .drawingGroup()
    }

    // Safely get palette float at index, defaulting to 0
    private func pf(_ index: Int) -> Float {
        index < paletteFloats.count ? paletteFloats[index] : 0.0
    }

    // Full pipeline: raw grayscale -> blur -> scale up -> posterize + pixelate + grid
    private func processedShaderLayer(modeIndex: Int, elapsed: Double, size: CGSize, contrast: Double = 1.0, brightness: Double = 0.0) -> some View {
        let scale = renderScale
        let scaledPixel = pixelSize * scale
        let blurR = scaledPixel > 1 ? scaledPixel * 0.4 : 0.0
        let maxOff = CGSize(width: max(pixelSize, 1), height: max(pixelSize, 1))
        return rawShaderLayer(modeIndex: modeIndex, elapsed: elapsed, size: size, contrast: contrast, brightness: brightness)
            .blur(radius: blurR)
            .drawingGroup()
            .scaleEffect(1.0 / scale)
            .frame(width: size.width, height: size.height)
            .drawingGroup()
            .layerEffect(
                ShaderLibrary.posterizePixelateEffect(
                    .float(Float(pixelSize)),
                    .float(Float(activeGridOpacity)),
                    .float(Float(posterizeLevels)),
                    .float(Float(paletteCount)),
                    .float(pf(0)),  .float(pf(1)),  .float(pf(2)),
                    .float(pf(3)),  .float(pf(4)),  .float(pf(5)),
                    .float(pf(6)),  .float(pf(7)),  .float(pf(8)),
                    .float(pf(9)),  .float(pf(10)), .float(pf(11)),
                    .float(pf(12)), .float(pf(13)), .float(pf(14)),
                    .float(pf(15)), .float(pf(16)), .float(pf(17)),
                    .float(pf(18)), .float(pf(19)), .float(pf(20)),
                    .float(pf(21)), .float(pf(22)), .float(pf(23))
                ),
                maxSampleOffset: maxOff
            )
    }

    // Blurred raw grayscale layer (before post-process), ready for compositing.
    // Renders at renderScale resolution — caller must scale up after post-process.
    private func blurredRawLayer(modeIndex: Int, elapsed: Double, size: CGSize, contrast: Double = 1.0, brightness: Double = 0.0) -> some View {
        let scale = renderScale
        let scaledPixel = pixelSize * scale
        let blurR = scaledPixel > 1 ? scaledPixel * 0.4 : 0.0
        return rawShaderLayer(modeIndex: modeIndex, elapsed: elapsed, size: size, contrast: contrast, brightness: brightness)
            .blur(radius: blurR)
            .drawingGroup()
    }

    // Apply post-process (palette map + posterize + pixelate + grid) to any view.
    // Scales up from low-res render first, then applies post-process at full resolution.
    private func postProcess<V: View>(_ view: V, size: CGSize) -> some View {
        let scale = renderScale
        let maxOff = CGSize(width: max(pixelSize, 1), height: max(pixelSize, 1))
        return view
            .scaleEffect(1.0 / scale)
            .frame(width: size.width, height: size.height)
            .drawingGroup()
            .layerEffect(
                ShaderLibrary.posterizePixelateEffect(
                    .float(Float(pixelSize)),
                    .float(Float(activeGridOpacity)),
                    .float(Float(posterizeLevels)),
                    .float(Float(paletteCount)),
                    .float(pf(0)),  .float(pf(1)),  .float(pf(2)),
                    .float(pf(3)),  .float(pf(4)),  .float(pf(5)),
                    .float(pf(6)),  .float(pf(7)),  .float(pf(8)),
                    .float(pf(9)),  .float(pf(10)), .float(pf(11)),
                    .float(pf(12)), .float(pf(13)), .float(pf(14)),
                    .float(pf(15)), .float(pf(16)), .float(pf(17)),
                    .float(pf(18)), .float(pf(19)), .float(pf(20)),
                    .float(pf(21)), .float(pf(22)), .float(pf(23))
                ),
                maxSampleOffset: maxOff
            )
    }

    @ViewBuilder
    private var shaderView: some View {
        TimelineView(.animation) { timeline in
            let baseElapsed = timeline.date.timeIntervalSince(startDate) * speed
            let currentTuning = shaderTunings[mode] ?? ShaderTuning()
            let currentElapsed = baseElapsed * currentTuning.speedMultiplier
            let currentContrast = currentTuning.contrast
            let currentBrightness = currentTuning.brightness
            GeometryReader { geo in
                let size = geo.size

                if let prevMode = previousMode, let transStart = transitionStart {
                    // Transition in progress
                    let prevTuning = shaderTunings[prevMode] ?? ShaderTuning()
                    let prevElapsed = baseElapsed * prevTuning.speedMultiplier
                    let prevContrast = prevTuning.contrast
                    let prevBrightness = prevTuning.brightness
                    let transElapsed = timeline.date.timeIntervalSince(transStart)
                    let rawProgress = min(transElapsed / max(transitionDuration, 0.01), 1.0)
                    // Quintic smoothstep — gentler ease-in/out for cinematic dissolve
                    let p = rawProgress
                    let progress = p * p * p * (p * (p * 6.0 - 15.0) + 10.0)

                    let _ = {
                        if rawProgress >= 1.0 {
                            DispatchQueue.main.async {
                                self.previousMode = nil
                                self.transitionStart = nil
                            }
                        }
                    }()

                    // Blend raw grayscale layers BEFORE post-process:
                    // Old shader: holds full, then gentle luma fade-out.
                    // New shader: ease-in envelope + luma cascade reveal.
                    // Single post-process pass themes the blended result.
                    postProcess(
                        ZStack {
                            blurredRawLayer(modeIndex: prevMode, elapsed: prevElapsed, size: size, contrast: prevContrast, brightness: prevBrightness)
                                .colorEffect(
                                    ShaderLibrary.lumaDissolveOut(
                                        .float(Float(progress))
                                    )
                                )

                            blurredRawLayer(modeIndex: mode, elapsed: currentElapsed, size: size, contrast: currentContrast, brightness: currentBrightness)
                                .colorEffect(
                                    ShaderLibrary.lumaRevealEffect(
                                        .float(Float(progress))
                                    )
                                )
                        }
                        .drawingGroup(),
                        size: size
                    )
                } else {
                    // No transition — single shader, full pipeline
                    processedShaderLayer(modeIndex: mode, elapsed: currentElapsed, size: size, contrast: currentContrast, brightness: currentBrightness)
                        .drawingGroup()
                }
            }
        }
    }
}
