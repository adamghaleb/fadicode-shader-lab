import SwiftUI

@main
struct ShaderLabApp: App {
    @StateObject private var state = TerminalState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
    }
}

/// Shared observable state that mimics what SurfaceView provides in fadicode.
class TerminalState: ObservableObject {
    // Working state (OSC 7778)
    @Published var isWorkingStateActive: Bool = false

    // Task completion (OSC 7777)
    @Published var taskCompletionTier: String? = nil

    // Focus simulation
    @Published var isFocused: Bool = true

    // Theme color
    @Published var themeColor: NSColor = NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)

    // Shader tuning
    @Published var shaderMode: Int = 5 // 0-5, default Combined
    @Published var shaderSpeed: Double = 1.0
    @Published var maxIntensity: Double = 1.0
    @Published var focusedIntensity: Double = 0.08
    @Published var focusInDuration: Double = 0.2
    @Published var focusOutDuration: Double = 0.5
}

struct ContentView: View {
    @EnvironmentObject var state: TerminalState

    var body: some View {
        HSplitView {
            // Left: Mock terminal with overlays
            ZStack {
                MockTerminalView()

                WorkingStateOverlay(
                    isActive: state.isWorkingStateActive,
                    isFocused: state.isFocused,
                    themeColor: state.themeColor,
                    mode: state.shaderMode,
                    speed: state.shaderSpeed,
                    maxIntensity: state.maxIntensity,
                    focusedIntensity: state.focusedIntensity,
                    focusInDuration: state.focusInDuration,
                    focusOutDuration: state.focusOutDuration
                )

                TaskFlashOverlay(
                    tier: state.taskCompletionTier,
                    themeColor: state.themeColor
                )
            }
            .frame(minWidth: 500)
            .background(Color.black)
            .onTapGesture {
                state.isFocused = true
            }

            // Right: Debug panel
            DebugPanel()
                .frame(width: 320)
        }
    }
}
