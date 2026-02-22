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

    // Pixelation
    @Published var pixelSize: Double = 0.0 // 0 = off, otherwise block size in points
    @Published var gridOpacity: Double = 0.6

    // Posterization
    @Published var posterizeLevels: Double = 5.0 // 0 = off (plain tint), 2+ = posterize bands

    // Inferno shader preview
    @Published var infernoShader: InfernoShader = .none {
        didSet {
            // Reset params to defaults when shader changes
            resetInfernoParams()
        }
    }

    // Generic param slots for the active Inferno shader (mapped per-shader)
    @Published var infernoParam1: Double = 0.0
    @Published var infernoParam2: Double = 0.0
    @Published var infernoParam3: Double = 0.0
    @Published var infernoParam4: Double = 0.0

    func resetInfernoParams() {
        let defs = infernoShader.parameterDefs
        infernoParam1 = defs.count > 0 ? defs[0].defaultValue : 0.0
        infernoParam2 = defs.count > 1 ? defs[1].defaultValue : 0.0
        infernoParam3 = defs.count > 2 ? defs[2].defaultValue : 0.0
        infernoParam4 = defs.count > 3 ? defs[3].defaultValue : 0.0
    }
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
                    focusOutDuration: state.focusOutDuration,
                    pixelSize: state.pixelSize,
                    gridOpacity: state.gridOpacity,
                    posterizeLevels: state.posterizeLevels
                )

                TaskFlashOverlay(
                    tier: state.taskCompletionTier,
                    themeColor: state.themeColor
                )

                if #available(macOS 14.0, *) {
                    InfernoPreviewOverlay(
                        shader: state.infernoShader,
                        themeColor: state.themeColor,
                        param1: state.infernoParam1,
                        param2: state.infernoParam2,
                        param3: state.infernoParam3,
                        param4: state.infernoParam4
                    )
                }
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
