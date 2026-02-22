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
    @Published var shaderMode: Int = 5 // 0-58, default Combined
    @Published var shaderSpeed: Double = 1.0
    @Published var transitionDuration: Double = 2.0 // seconds for shader-to-shader dissolve
    @Published var maxIntensity: Double = 1.0
    @Published var focusedIntensity: Double = 0.08
    @Published var focusInDuration: Double = 0.2
    @Published var focusOutDuration: Double = 0.5

    // Pixelation
    @Published var pixelSize: Double = 0.0 // 0 = off, otherwise block size in points
    @Published var gridOpacity: Double = 0.6

    // Posterization
    @Published var posterizeLevels: Double = 5.0 // 0 = off (plain tint), 2+ = posterize bands
    @Published var hueSpread: Double = 0.10      // analogous hue spread (0 = mono, 0.25 = wide)
    @Published var complementMix: Double = 0.0   // complementary accent in highlights (0 = off)

    // Shader ratings: star = best, liked = good, mid = okay, disliked = nope
    // Persisted to UserDefaults
    private var isLoading = false

    @Published var starredShaders: Set<Int> = [] {
        didSet { if !isLoading { saveRatings() } }
    }
    @Published var likedShaders: Set<Int> = [] {
        didSet { if !isLoading { saveRatings() } }
    }
    @Published var midShaders: Set<Int> = [] {
        didSet { if !isLoading { saveRatings() } }
    }
    @Published var dislikedShaders: Set<Int> = [] {
        didSet { if !isLoading { saveRatings() } }
    }

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

    // Pre-seeded ratings from review session
    private static let defaultStarred: Set<Int> = [12, 13, 21, 26, 27, 28, 30, 34]
    // Voronoi(12), Spiral Galaxy(13), Machine Elves(21), Folding Dimensions(26),
    // Cymatics(27), Cosmic Web(28), Interference Crystal(30), Entity Presence(34)

    private static let defaultLiked: Set<Int> = [6, 7, 8, 10, 15, 16, 19, 20, 23, 25, 32]
    // Light Grid(6), Sinebow(7), Gradient Spin(8), Kaleidoscope(10), Lava Lamp(15),
    // Sacred Geometry(16), Moire(19), Chrysanthemum(20), Jewel Lattice(23),
    // Ego Dissolution(25), DNA Helix(32)

    private static let defaultMid: Set<Int> = [2, 11, 17, 18, 22, 31, 33]
    // Point Cloud(2), Plasma(11), Warp Tunnel(17), Fractal Rings(18),
    // Hyperspace(22), Nebula Cloud(31), Tessellation Dance(33)

    private static let defaultDisliked: Set<Int> = [0, 1, 3, 4, 5, 9, 14, 24, 29]
    // Organic Flow(0), Mandala(1), Aurora(3), Pulse Grid(4), Combined(5),
    // Circle Wave(9), Ripple Pond(14), Neural Bloom(24), Topographic Flow(29)

    init() {
        isLoading = true
        let hasExisting = UserDefaults.standard.array(forKey: "starredShaders") != nil
        if hasExisting {
            if let arr = UserDefaults.standard.array(forKey: "starredShaders") as? [Int] {
                starredShaders = Set(arr)
            }
            if let arr = UserDefaults.standard.array(forKey: "likedShaders") as? [Int] {
                likedShaders = Set(arr)
            }
            if let arr = UserDefaults.standard.array(forKey: "midShaders") as? [Int] {
                midShaders = Set(arr)
            }
            if let arr = UserDefaults.standard.array(forKey: "dislikedShaders") as? [Int] {
                dislikedShaders = Set(arr)
            }
        } else {
            // First launch: seed with pre-existing ratings
            starredShaders = Self.defaultStarred
            likedShaders = Self.defaultLiked
            midShaders = Self.defaultMid
            dislikedShaders = Self.defaultDisliked
            // Persist so next launch loads from UserDefaults
            saveRatings()
        }
        isLoading = false
    }

    private func saveRatings() {
        UserDefaults.standard.set(Array(starredShaders), forKey: "starredShaders")
        UserDefaults.standard.set(Array(likedShaders), forKey: "likedShaders")
        UserDefaults.standard.set(Array(midShaders), forKey: "midShaders")
        UserDefaults.standard.set(Array(dislikedShaders), forKey: "dislikedShaders")
    }

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
                    posterizeLevels: state.posterizeLevels,
                    hueSpread: state.hueSpread,
                    complementMix: state.complementMix,
                    transitionDuration: state.transitionDuration
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
