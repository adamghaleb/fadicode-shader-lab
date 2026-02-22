import SwiftUI

/// Debug control panel for testing shader effects.
struct DebugPanel: View {
    @EnvironmentObject var state: TerminalState

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

                // MARK: - Shader Preset
                sectionHeader("Shader Preset")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(shaderPresets, id: \.mode) { preset in
                        Button {
                            state.shaderMode = preset.mode
                        } label: {
                            HStack(spacing: 6) {
                                Text(preset.icon)
                                    .font(.system(size: 14))
                                Text(preset.name)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
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
                    }
                }

                Divider().background(Color.white.opacity(0.2))

                // MARK: - Shader Tuning
                sectionHeader("Shader Tuning")

                sliderRow("Speed", value: $state.shaderSpeed, range: 0.1...3.0)
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

    // MARK: - Shader Presets

    private let shaderPresets: [(mode: Int, name: String, icon: String)] = [
        (0, "Organic Flow", "~"),
        (1, "Mandala",      "*"),
        (2, "Point Cloud",  "."),
        (3, "Aurora",       "/"),
        (4, "Pulse Grid",   "#"),
        (5, "Combined",     "+"),
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
