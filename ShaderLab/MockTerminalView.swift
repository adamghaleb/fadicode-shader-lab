import SwiftUI

/// Fake terminal content that looks realistic so you can judge shader readability.
struct MockTerminalView: View {
    @EnvironmentObject var state: TerminalState

    private let termFont = Font.system(size: 13, design: .monospaced)

    private var shaderName: String {
        shaderPresets.first(where: { $0.mode == state.shaderMode })?.name ?? "Unknown"
    }

    private var isFocused: Bool { state.isFocused }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title bar
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 1.0, green: 0.38, blue: 0.34)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 1.0, green: 0.79, blue: 0.23)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 0.30, green: 0.85, blue: 0.39)).frame(width: 10, height: 10)
                }
                .padding(.leading, 8)

                Spacer()

                Text(shaderName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                // Invisible spacer dots to keep title centered
                HStack(spacing: 6) {
                    Circle().fill(Color.clear).frame(width: 10, height: 10)
                    Circle().fill(Color.clear).frame(width: 10, height: 10)
                    Circle().fill(Color.clear).frame(width: 10, height: 10)
                }
                .padding(.trailing, 8)
            }
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: state.themeColor).opacity(0.3))
                    .frame(height: 1)
            }

            promptLine("~/projects/fadicode", command: "zig build -Doptimize=Debug")
            outputLine("info: compilation done in 4.23s")
            outputLine("")
            promptLine("~/projects/fadicode", command: "printf '\\033]7778;start\\033\\\\'")
            outputLine("")
            promptLine("~/projects/fadicode", command: "cargo test --release")
            outputLine("   Compiling fadicode v0.1.0")
            outputLine("   Compiling shader-pipeline v0.3.2")
            outputLine("     Running unittests src/lib.rs")
            outputLine("")
            testLine(passed: true, name: "test_osc_7778_parse_start")
            testLine(passed: true, name: "test_osc_7778_parse_stop")
            testLine(passed: true, name: "test_shader_intensity_range")
            testLine(passed: true, name: "test_focus_transition_timing")
            testLine(passed: false, name: "test_point_cloud_density")
            outputLine("")
            outputLine("test result: 4 passed; 1 failed; finished in 0.82s")
            outputLine("")
            promptLine("~/projects/fadicode", command: "")

            Spacer()

            // Status bar at bottom
            HStack {
                Text("NORMAL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isFocused ? .black : .white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isFocused ? Color(nsColor: state.themeColor) : Color.white.opacity(0.15))

                Text("main")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isFocused ? Color(nsColor: state.themeColor) : .white.opacity(0.5))

                Spacer()

                Text("utf-8  unix  zig")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isFocused ? .gray : .white.opacity(0.3))

                Text("42:1")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(isFocused ? 0.6 : 0.3))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
        }
        .padding(12)
        .opacity(isFocused ? 1.0 : 0.3)
        .shadow(color: isFocused ? Color(nsColor: state.themeColor.blended(withFraction: 0.75, of: .black) ?? .black).opacity(0.7) : .clear, radius: 1, x: 0, y: 1)
        .shadow(color: isFocused ? Color(nsColor: state.themeColor.blended(withFraction: 0.75, of: .black) ?? .black).opacity(0.3) : .clear, radius: 12, x: 0, y: 4)
    }

    private func promptLine(_ dir: String, command: String) -> some View {
        HStack(spacing: 0) {
            Text(dir)
                .foregroundColor(isFocused ? Color(nsColor: state.themeColor) : .white)
                .font(termFont)
            Text(" > ")
                .foregroundColor(.white.opacity(isFocused ? 0.5 : 1.0))
                .font(termFont)
            Text(command)
                .foregroundColor(.white)
                .font(termFont)
            if command.isEmpty {
                BlinkingCursor(color: isFocused ? Color(nsColor: state.themeColor) : .white)
            }
        }
    }

    private func outputLine(_ text: String) -> some View {
        Text(text.isEmpty ? " " : text)
            .foregroundColor(.white)
            .font(termFont)
    }

    private func testLine(passed: Bool, name: String) -> some View {
        HStack(spacing: 0) {
            Text(passed ? "  PASS " : "  FAIL ")
                .foregroundColor(isFocused ? (passed ? .green : .red) : .white)
                .font(termFont.bold())
            Text(name)
                .foregroundColor(.white)
                .font(termFont)
        }
    }
}

struct BlinkingCursor: View {
    let color: Color
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { _ in
                    visible.toggle()
                }
            }
    }
}
