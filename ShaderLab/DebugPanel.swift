import SwiftUI

/// Debug control panel for testing shader effects.
struct DebugPanel: View {
    @EnvironmentObject var state: TerminalState
    @State private var showCopied: Bool = false
    @State private var showExported: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Shader Lab")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Working State (OSC 7778)
                sectionHeader("Working State (OSC 7778)")

                HStack {
                    Button(state.isWorkingStateActive ? "Stop" : "Start") {
                        state.isWorkingStateActive.toggle()
                    }
                    .keyboardShortcut("w", modifiers: .command)
                    .buttonStyle(DebugButtonStyle(
                        color: state.isWorkingStateActive ? .red : .green
                    ))

                    statusPill(
                        state.isWorkingStateActive ? "ACTIVE" : "IDLE",
                        color: state.isWorkingStateActive ? .green : .gray
                    )
                }

                // MARK: - Focus Simulation
                sectionHeader("Focus")

                HStack {
                    Button(state.isFocused ? "Unfocus" : "Focus") {
                        state.isFocused.toggle()
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    .buttonStyle(DebugButtonStyle(
                        color: state.isFocused ? .orange : .blue
                    ))

                    statusPill(
                        state.isFocused ? "FOCUSED" : "UNFOCUSED",
                        color: state.isFocused ? .blue : .orange
                    )
                }

                // MARK: - Task Completion (OSC 7777)
                sectionHeader("Task Flash (OSC 7777)")

                HStack(spacing: 8) {
                    Button("Short") { fireTaskCompletion("short") }
                        .buttonStyle(DebugButtonStyle(color: .white))
                        .keyboardShortcut("1", modifiers: .command)

                    Button("Medium") { fireTaskCompletion("medium") }
                        .buttonStyle(DebugButtonStyle(color: .yellow))
                        .keyboardShortcut("2", modifiers: .command)

                    Button("Long") { fireTaskCompletion("long") }
                        .buttonStyle(DebugButtonStyle(color: .purple))
                        .keyboardShortcut("3", modifiers: .command)
                }

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Theme Color
                sectionHeader("Theme Color")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(presetColors, id: \.name) { preset in
                        Circle()
                            .fill(Color(nsColor: preset.color))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: state.themeColor == preset.color ? 2 : 0)
                            )
                            .onTapGesture {
                                state.themeColor = preset.color
                            }
                    }
                }

                ColorPicker("Custom", selection: Binding(
                    get: { Color(nsColor: state.themeColor) },
                    set: { state.themeColor = NSColor($0) }
                ))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Inferno Shader Preview
                sectionHeader("Inferno Shaders")

                Picker("Effect", selection: $state.infernoShader) {
                    ForEach(InfernoShader.allCases) { shader in
                        Text(shader.rawValue).tag(shader)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 12, design: .monospaced))
                .tint(Color(nsColor: state.themeColor))

                // Surprise Me: pick random shader + randomize all params
                Button {
                    let shaders = InfernoShader.allCases.filter { $0 != .none }
                    guard let random = shaders.randomElement() else { return }
                    state.infernoShader = random

                    // Override defaults with random values within each param's range
                    let defs = random.parameterDefs
                    if defs.count > 0 { state.infernoParam1 = Double.random(in: defs[0].range) }
                    if defs.count > 1 { state.infernoParam2 = Double.random(in: defs[1].range) }
                    if defs.count > 2 { state.infernoParam3 = Double.random(in: defs[2].range) }
                    if defs.count > 3 { state.infernoParam4 = Double.random(in: defs[3].range) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dice.fill")
                        Text("Surprise Me")
                    }
                }
                .buttonStyle(DebugButtonStyle(color: .purple))

                if state.infernoShader != .none {
                    HStack {
                        statusPill(state.infernoShader.shaderType.label, color: state.infernoShader.shaderType.tint)
                        Spacer()
                        Button {
                            let defs = state.infernoShader.parameterDefs
                            if defs.count > 0 { state.infernoParam1 = Double.random(in: defs[0].range) }
                            if defs.count > 1 { state.infernoParam2 = Double.random(in: defs[1].range) }
                            if defs.count > 2 { state.infernoParam3 = Double.random(in: defs[2].range) }
                            if defs.count > 3 { state.infernoParam4 = Double.random(in: defs[3].range) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Randomize")
                            }
                        }
                        .buttonStyle(DebugButtonStyle(color: .pink))
                        Button("Reset") {
                            state.resetInfernoParams()
                        }
                        .buttonStyle(DebugButtonStyle(color: .yellow))
                        Button("Clear") {
                            state.infernoShader = .none
                        }
                        .buttonStyle(DebugButtonStyle(color: .red))
                    }

                    // Dynamic per-shader parameter sliders
                    infernoParamSliders

                    // Copy Code button
                    Button {
                        let snippet = state.infernoShader.generateCodeSnippet(
                            param1: state.infernoParam1,
                            param2: state.infernoParam2,
                            param3: state.infernoParam3,
                            param4: state.infernoParam4
                        )
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(snippet, forType: .string)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            Text(showCopied ? "Copied!" : "Copy Code")
                        }
                    }
                    .buttonStyle(DebugButtonStyle(color: .cyan))
                }

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Shader Preset
                sectionHeader("Working State Preset")

                // Export & stats
                HStack(spacing: 4) {
                    statusPill("\(state.starredShaders.count)★", color: .yellow)
                    statusPill("\(state.likedShaders.count)👍", color: .green)
                    statusPill("\(state.midShaders.count)~", color: .orange)
                    statusPill("\(state.dislikedShaders.count)👎", color: .red)

                    Spacer()

                    Button {
                        exportRatings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showExported ? "checkmark" : "square.and.arrow.up")
                            Text(showExported ? "Copied!" : "Export")
                        }
                    }
                    .buttonStyle(DebugButtonStyle(color: showExported ? .green : .cyan))
                }

                // Starred section
                if !state.starredShaders.isEmpty {
                    sectionHeader("Best")
                    shaderGrid(shaderPresets.filter { state.starredShaders.contains($0.mode) })
                }

                // Liked section
                if !state.likedShaders.isEmpty {
                    sectionHeader("Good")
                    shaderGrid(shaderPresets.filter { state.likedShaders.contains($0.mode) })
                }

                // Mid section
                if !state.midShaders.isEmpty {
                    sectionHeader("Mid")
                    shaderGrid(shaderPresets.filter { state.midShaders.contains($0.mode) })
                }

                // Unrated section
                let unratedPresets = shaderPresets.filter {
                    !state.starredShaders.contains($0.mode) &&
                    !state.likedShaders.contains($0.mode) &&
                    !state.midShaders.contains($0.mode) &&
                    !state.dislikedShaders.contains($0.mode)
                }
                if !unratedPresets.isEmpty {
                    sectionHeader("Unrated")
                    shaderGrid(unratedPresets)
                }

                // Rejected section (collapsed)
                if !state.dislikedShaders.isEmpty {
                    DisclosureGroup {
                        shaderGrid(shaderPresets.filter { state.dislikedShaders.contains($0.mode) })
                    } label: {
                        sectionHeader("Rejected (\(state.dislikedShaders.count))")
                    }
                    .tint(.white.opacity(0.4))
                }

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Shader Tuning
                sectionHeader("Shader Tuning")

                // MARK: - Pixelation
                sectionHeader("Pixelation")

                HStack {
                    ForEach(pixelPresets, id: \.size) { preset in
                        Button(preset.label) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                state.pixelSize = preset.size
                            }
                        }
                        .buttonStyle(DebugButtonStyle(
                            color: state.pixelSize == preset.size ? Color(nsColor: state.themeColor) : .gray
                        ))
                    }
                }

                sliderRow("Block Size", value: $state.pixelSize, range: 0...24)
                sliderRow("Grid Lines", value: $state.gridOpacity, range: 0.0...5.0)

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Posterization
                sectionHeader("Posterization")

                HStack {
                    ForEach(posterizePresets, id: \.levels) { preset in
                        Button(preset.label) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                state.posterizeLevels = preset.levels
                            }
                        }
                        .buttonStyle(DebugButtonStyle(
                            color: state.posterizeLevels == preset.levels ? Color(nsColor: state.themeColor) : .gray
                        ))
                    }
                }

                sliderRow("Levels", value: $state.posterizeLevels, range: 0...12)
                sliderRow("Hue Spread", value: $state.hueSpread, range: 0.0...0.25)
                sliderRow("Complement", value: $state.complementMix, range: 0.0...0.5)

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Shader Tuning
                sectionHeader("Shader Tuning")

                sliderRow("Speed", value: $state.shaderSpeed, range: 0.1...30.0)
                sliderRow("Transition", value: $state.transitionDuration, range: 0.3...5.0)
                sliderRow("Unfocused Intensity", value: $state.maxIntensity, range: 0.0...1.5)
                sliderRow("Focused Intensity", value: $state.focusedIntensity, range: 0.0...0.5)
                sliderRow("Focus-in (ms)", value: $state.focusInDuration, range: 0.05...1.0)
                sliderRow("Focus-out (ms)", value: $state.focusOutDuration, range: 0.1...2.0)

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Quick Scenarios
                sectionHeader("Scenarios")

                Button("Full cycle: start > unfocus > focus > stop") {
                    runFullCycle()
                }
                .buttonStyle(DebugButtonStyle(color: .cyan))
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Flash during working state") {
                    if !state.isWorkingStateActive { state.isWorkingStateActive = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        fireTaskCompletion("long")
                    }
                }
                .buttonStyle(DebugButtonStyle(color: .mint))

                Spacer()
            }
            .padding(16)
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Inferno Parameter Sliders

    @ViewBuilder
    private var infernoParamSliders: some View {
        let defs = state.infernoShader.parameterDefs
        if defs.isEmpty {
            Text("No tunable parameters")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .italic()
        } else {
            if defs.count > 0 {
                sliderRow(defs[0].name, value: $state.infernoParam1, range: defs[0].range)
            }
            if defs.count > 1 {
                sliderRow(defs[1].name, value: $state.infernoParam2, range: defs[1].range)
            }
            if defs.count > 2 {
                sliderRow(defs[2].name, value: $state.infernoParam3, range: defs[2].range)
            }
            if defs.count > 3 {
                sliderRow(defs[3].name, value: $state.infernoParam4, range: defs[3].range)
            }
        }
    }

    // MARK: - Shader Grid with Rating Buttons

    private func shaderGrid(_ presets: [(mode: Int, name: String, icon: String)]) -> some View {
        VStack(spacing: 4) {
            ForEach(presets, id: \.mode) { preset in
                HStack(spacing: 6) {
                    // Shader select button
                    Button {
                        state.shaderMode = preset.mode
                    } label: {
                        HStack(spacing: 6) {
                            Text(preset.icon)
                                .font(.system(size: 12))
                            Text(preset.name)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(state.shaderMode == preset.mode
                                    ? Color(nsColor: state.themeColor).opacity(0.25)
                                    : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    state.shaderMode == preset.mode
                                        ? Color(nsColor: state.themeColor).opacity(0.6)
                                        : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(state.shaderMode == preset.mode ? .white : .white.opacity(0.6))

                    // Rating buttons
                    ratingButton(
                        icon: "star.fill",
                        isActive: state.starredShaders.contains(preset.mode),
                        activeColor: .yellow
                    ) {
                        toggleRating(mode: preset.mode, tier: .star)
                    }

                    ratingButton(
                        icon: "hand.thumbsup.fill",
                        isActive: state.likedShaders.contains(preset.mode),
                        activeColor: .green
                    ) {
                        toggleRating(mode: preset.mode, tier: .like)
                    }

                    ratingButton(
                        icon: "minus.circle.fill",
                        isActive: state.midShaders.contains(preset.mode),
                        activeColor: .orange
                    ) {
                        toggleRating(mode: preset.mode, tier: .mid)
                    }

                    ratingButton(
                        icon: "hand.thumbsdown.fill",
                        isActive: state.dislikedShaders.contains(preset.mode),
                        activeColor: .red
                    ) {
                        toggleRating(mode: preset.mode, tier: .dislike)
                    }
                }
            }
        }
    }

    private func ratingButton(icon: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(isActive ? activeColor : .white.opacity(0.2))
        }
        .buttonStyle(.plain)
        .frame(width: 22, height: 22)
    }

    private enum RatingTier { case star, like, mid, dislike }

    private func toggleRating(mode: Int, tier: RatingTier) {
        // Check if already in this tier BEFORE clearing
        let wasInTier: Bool
        switch tier {
        case .star:    wasInTier = state.starredShaders.contains(mode)
        case .like:    wasInTier = state.likedShaders.contains(mode)
        case .mid:     wasInTier = state.midShaders.contains(mode)
        case .dislike: wasInTier = state.dislikedShaders.contains(mode)
        }

        // Clear from all tiers
        state.starredShaders.remove(mode)
        state.likedShaders.remove(mode)
        state.midShaders.remove(mode)
        state.dislikedShaders.remove(mode)

        // If it was already in this tier, leave unrated. Otherwise set it.
        if !wasInTier {
            switch tier {
            case .star:    state.starredShaders.insert(mode)
            case .like:    state.likedShaders.insert(mode)
            case .mid:     state.midShaders.insert(mode)
            case .dislike: state.dislikedShaders.insert(mode)
            }
        }
    }

    // MARK: - Export Ratings

    private func exportRatings() {
        var md = "# Shader Ratings\n\n"

        let starred = shaderPresets.filter { state.starredShaders.contains($0.mode) }
        let liked = shaderPresets.filter { state.likedShaders.contains($0.mode) }
        let mid = shaderPresets.filter { state.midShaders.contains($0.mode) }
        let disliked = shaderPresets.filter { state.dislikedShaders.contains($0.mode) }
        let unrated = shaderPresets.filter {
            !state.starredShaders.contains($0.mode) &&
            !state.likedShaders.contains($0.mode) &&
            !state.midShaders.contains($0.mode) &&
            !state.dislikedShaders.contains($0.mode)
        }

        if !starred.isEmpty {
            md += "## Best (starred)\n"
            for p in starred { md += "- \(p.name) (mode \(p.mode))\n" }
            md += "\n"
        }

        if !liked.isEmpty {
            md += "## Good (thumbs up)\n"
            for p in liked { md += "- \(p.name) (mode \(p.mode))\n" }
            md += "\n"
        }

        if !mid.isEmpty {
            md += "## Mid (okay)\n"
            for p in mid { md += "- \(p.name) (mode \(p.mode))\n" }
            md += "\n"
        }

        if !disliked.isEmpty {
            md += "## Rejected (thumbs down)\n"
            for p in disliked { md += "- \(p.name) (mode \(p.mode))\n" }
            md += "\n"
        }

        if !unrated.isEmpty {
            md += "## Unrated\n"
            for p in unrated { md += "- \(p.name) (mode \(p.mode))\n" }
            md += "\n"
        }

        // Write to project directory using FileManager for reliable path
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileURL = home.appendingPathComponent("Documents/windsurf projects/fadicode-shader-lab/shader-ratings.md")
        try? md.write(to: fileURL, atomically: true, encoding: .utf8)

        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)

        // Visual feedback
        showExported = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showExported = false
        }
    }

    // MARK: - Helpers

    private func fireTaskCompletion(_ tier: String) {
        // Reset first so repeated same-tier fires onChange
        state.taskCompletionTier = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            state.taskCompletionTier = tier
        }
        // Auto-clear
        let delay: Double = tier == "long" ? 4.0 : (tier == "medium" ? 1.5 : 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            state.taskCompletionTier = nil
        }
    }

    private func runFullCycle() {
        state.isFocused = true
        state.isWorkingStateActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            state.isFocused = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            state.isFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            state.isWorkingStateActive = false
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.white.opacity(0.5))
            .textCase(.uppercase)
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            Slider(value: value, in: range)
                .tint(Color(nsColor: state.themeColor))
        }
    }

    // MARK: - Pixel Presets

    private let pixelPresets: [(label: String, size: Double)] = [
        ("Off",  0),
        ("4px",  4),
        ("6px",  6),
        ("8px",  8),
        ("12px", 12),
    ]

    // MARK: - Posterize Presets

    private let posterizePresets: [(label: String, levels: Double)] = [
        ("Off",  0),
        ("3",    3),
        ("5",    5),
        ("8",    8),
    ]

    // MARK: - Shader Presets

    private let shaderPresets: [(mode: Int, name: String, icon: String)] = [
        (0,  "Organic Flow",        "~"),
        (1,  "Mandala",             "*"),
        (2,  "Point Cloud",         "."),
        (3,  "Aurora",              "/"),
        (4,  "Pulse Grid",          "#"),
        (5,  "Combined",            "+"),
        (6,  "Light Grid",          "::"),
        (7,  "Sinebow",             "S"),
        (8,  "Gradient Spin",       "@"),
        (9,  "Circle Wave",         "O"),
        (10, "Kaleidoscope",        "K"),
        (11, "Plasma",              "P"),
        (12, "Voronoi",             "V"),
        (13, "Spiral Galaxy",       "G"),
        (14, "Ripple Pond",         "R"),
        (15, "Lava Lamp",           "L"),
        (16, "Sacred Geometry",     "F"),
        (17, "Warp Tunnel",         "T"),
        (18, "Fractal Rings",       "Q"),
        (19, "Moire",               "M"),
        (20, "Chrysanthemum",       "❁"),
        (21, "Machine Elves",       "⌬"),
        (22, "Hyperspace",          "◈"),
        (23, "Jewel Lattice",       "◇"),
        (24, "Neural Bloom",        "⟡"),
        (25, "Ego Dissolution",     "∞"),
        (26, "Folding Dimensions",  "⊿"),
        (27, "Cymatics",            "≋"),
        (28, "Cosmic Web",          "⟐"),
        (29, "Topographic Flow",    "≈"),
        (30, "Interference Crystal","✧"),
        (31, "Nebula Cloud",        "☁"),
        (32, "DNA Helix",           "⧖"),
        (33, "Tessellation Dance",  "◬"),
        (34, "Entity Presence",     "◉"),
        (35, "Fractal Mandelbrot",  "⍟"),
        (36, "Quantum Field",       "⟁"),
        (37, "Geometric Alchemy",   "⬡"),
        (38, "Wormhole",            "⊘"),
        (39, "Celestial Clockwork", "⚙"),
        (40, "Crystal Cavern",      "⬥"),
        (41, "Electric Field",      "⚡"),
        (42, "Resonance",           "∿"),
        (43, "Spirit Molecule",     "⊛"),
        (44, "Flower of Life",      "✿"),
        (45, "Infinite Zoom",       "⌁"),
        (46, "String Theory",       "∥"),
        (47, "Penrose Tiling",      "◇"),
        (48, "Akashic Field",       "∞"),
        (49, "Breath of God",       "☼"),
        (50, "Metatron's Cube",     "✡"),
        (51, "Void Bloom",          "❀"),
        (52, "Weaver's Loom",       "⌘"),
        (53, "Timecrystal",         "⏣"),
        (54, "Resonance Chamber",   "⊛"),
        (55, "Event Horizon",       "◌"),
        (56, "Architect's Gaze",    "◎"),
        (57, "Sigil Network",       "⎔"),
        (58, "Dream Catcher",       "◐"),
    ]

    // MARK: - Color Presets

    private let presetColors: [(name: String, color: NSColor)] = [
        ("Blue",    NSColor(red: 0.30, green: 0.60, blue: 1.00, alpha: 1)),
        ("Cyan",    NSColor(red: 0.20, green: 0.85, blue: 0.85, alpha: 1)),
        ("Green",   NSColor(red: 0.20, green: 0.85, blue: 0.40, alpha: 1)),
        ("Yellow",  NSColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 1)),
        ("Orange",  NSColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1)),
        ("Red",     NSColor(red: 1.00, green: 0.30, blue: 0.30, alpha: 1)),
        ("Pink",    NSColor(red: 1.00, green: 0.40, blue: 0.70, alpha: 1)),
        ("Purple",  NSColor(red: 0.65, green: 0.35, blue: 1.00, alpha: 1)),
        ("Violet",  NSColor(red: 0.50, green: 0.30, blue: 0.90, alpha: 1)),
        ("Teal",    NSColor(red: 0.25, green: 0.70, blue: 0.65, alpha: 1)),
        ("Lime",    NSColor(red: 0.55, green: 0.90, blue: 0.20, alpha: 1)),
        ("White",   NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)),
    ]
}

// MARK: - Button Style

struct DebugButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(configuration.isPressed ? color : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(configuration.isPressed ? 0.3 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color.opacity(0.4), lineWidth: 1)
            )
    }
}
