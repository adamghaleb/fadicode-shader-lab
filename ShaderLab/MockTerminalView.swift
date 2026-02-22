import SwiftUI

/// Fake terminal content that looks realistic so you can judge shader readability.
struct MockTerminalView: View {
    @EnvironmentObject var state: TerminalState

    private let termFont = Font.system(size: 13, design: .monospaced)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: state.themeColor))

                Text("main")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(nsColor: state.themeColor))

                Spacer()

                Text("utf-8  unix  zig")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)

                Text("42:1")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
        }
        .padding(12)
    }

    private func promptLine(_ dir: String, command: String) -> some View {
        HStack(spacing: 0) {
            Text(dir)
                .foregroundColor(Color(nsColor: state.themeColor))
                .font(termFont)
            Text(" > ")
                .foregroundColor(.white.opacity(0.5))
                .font(termFont)
            Text(command)
                .foregroundColor(.white.opacity(0.9))
                .font(termFont)
            if command.isEmpty {
                // Blinking cursor
                BlinkingCursor(color: Color(nsColor: state.themeColor))
            }
        }
    }

    private func outputLine(_ text: String) -> some View {
        Text(text.isEmpty ? " " : text)
            .foregroundColor(.white.opacity(0.7))
            .font(termFont)
    }

    private func testLine(passed: Bool, name: String) -> some View {
        HStack(spacing: 0) {
            Text(passed ? "  PASS " : "  FAIL ")
                .foregroundColor(passed ? .green : .red)
                .font(termFont.bold())
            Text(name)
                .foregroundColor(.white.opacity(0.8))
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
