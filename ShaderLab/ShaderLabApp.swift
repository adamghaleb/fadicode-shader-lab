import SwiftUI

enum ShaderLevel: String, Codable, CaseIterable {
    case low, medium, high

    var shortLabel: String {
        switch self {
        case .low: return "L"
        case .medium: return "M"
        case .high: return "H"
        }
    }
}

enum ShaderTag: String, Codable, CaseIterable {
    case geometric, symmetrical, organic, rippling, flowing
    case pulsing, fractal, crystalline, ethereal, hypnotic
}

struct ShaderProfile: Codable, Equatable {
    var coverage: ShaderLevel = .medium  // how much screen area the shader fills
    var density: ShaderLevel = .medium   // how much color vs black (lightness fill)
    var speed: ShaderLevel = .medium
    var energy: ShaderLevel = .medium
    var tags: Set<ShaderTag> = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coverage = try c.decodeIfPresent(ShaderLevel.self, forKey: .coverage) ?? .medium
        density = try c.decodeIfPresent(ShaderLevel.self, forKey: .density) ?? .medium
        speed = try c.decodeIfPresent(ShaderLevel.self, forKey: .speed) ?? .medium
        energy = try c.decodeIfPresent(ShaderLevel.self, forKey: .energy) ?? .medium
        tags = try c.decodeIfPresent(Set<ShaderTag>.self, forKey: .tags) ?? []
    }
}

struct ShaderTuning: Codable, Equatable {
    var speedMultiplier: Double = 1.0  // 0.1–5.0
    var contrast: Double = 1.0         // 0.0–3.0
    var brightness: Double = 0.0       // -0.5–1.0, lifts midtones/highlights while preserving blacks
    var note: String = ""

    // Backwards-compatible decoder: new fields get defaults if missing from saved data
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        speedMultiplier = try c.decodeIfPresent(Double.self, forKey: .speedMultiplier) ?? 1.0
        contrast = try c.decodeIfPresent(Double.self, forKey: .contrast) ?? 1.0
        brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 0.0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    init() {}
}

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
    @Published var isWorkingStateActive: Bool = true

    // Task completion (OSC 7777)
    @Published var taskCompletionTier: String? = nil

    // Focus simulation
    @Published var isFocused: Bool = true

    // Theme color
    @Published var themeColor: NSColor = NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)

    // Shader tuning
    @Published var shaderMode: Int = 12 // 0-58, default Voronoi
    @Published var shaderSpeed: Double = 1.0
    @Published var transitionDuration: Double = 3.0 // seconds for shader-to-shader dissolve
    @Published var maxIntensity: Double = 1.0
    @Published var focusedIntensity: Double = 0.08
    @Published var focusedOpacity: Double = 0.50 // overall opacity of shader overlay when terminal is focused
    @Published var focusInDuration: Double = 0.2
    @Published var focusOutDuration: Double = 0.2

    // Pixelation
    @Published var pixelSize: Double = 6.0 // 0 = off, otherwise block size in points
    @Published var gridOpacity: Double = 1.5           // unfocused grid line thickness
    @Published var focusedGridOpacity: Double = 2.5    // focused grid line thickness
    @Published var resolutionScale: Double = 0.2       // 0.1–1.0, render shader at lower res then upscale

    // Posterization
    @Published var posterizeLevels: Double = 7.0 // 0 = off (plain tint), 2+ = posterize bands
    @Published var hueSpread: Double = 0.20      // warm-cool hue shift (0 = mono, 0.5 = wide)
    @Published var complementMix: Double = 0.10  // complementary accent in highlights (0 = off)
    @Published var paletteContrast: Double = 0.87 // power curve on brightness ramp (0.5 = flat, 2.0 = dramatic)
    @Published var paletteSaturation: Double = 1.21 // saturation multiplier (0 = grayscale, 2 = vivid)

    // Loading guard (prevents saving during init)
    private var isLoading = false

    // Per-shader tuning (speed multiplier, contrast, notes)
    @Published var shaderTunings: [Int: ShaderTuning] = [:] {
        didSet { if !isLoading { saveTunings() } }
    }

    // Per-shader profiles (coverage, speed, energy, tags) for LLM export
    @Published var shaderProfiles: [Int: ShaderProfile] = [:] {
        didSet { if !isLoading { saveProfiles() } }
    }

    var resolvedPalette: GradientPalette {
        let full = generateAutoPalette(
            themeColor: themeColor,
            hueSpread: Float(hueSpread),
            complementMix: Float(complementMix),
            contrast: Float(paletteContrast),
            saturation: Float(paletteSaturation),
            levels: max(Int(posterizeLevels), 3)
        )
        // When focused, drop the top 2 brightest stops and remap to full range
        if isFocused && full.stops.count > 4 {
            let kept = Array(full.stops.sorted { $0.position < $1.position }.prefix(full.stops.count - 2))
            let maxPos = kept.last?.position ?? 1.0
            let remapped = kept.map { stop in
                PaletteStop(color: stop.color, position: maxPos > 0 ? stop.position / maxPos : stop.position)
            }
            return GradientPalette(name: "Auto", stops: remapped, isBuiltIn: true)
        }
        return full
    }

    var paletteFloats: [Float] { resolvedPalette.toFloatArray() }
    var paletteStopCount: Int { resolvedPalette.stops.count }

    // Shader ratings: star = best, liked = good, mid = okay, disliked = nope
    // Persisted to UserDefaults
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

    // Hot reload
    let fileWatcher = ShaderFileWatcher()
    @Published var hotReloadEnabled: Bool = false {
        didSet {
            if hotReloadEnabled {
                fileWatcher.start()
            } else {
                fileWatcher.stop()
            }
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
        // Load ratings: JSON file first, then UserDefaults migration, then defaults
        if let data = try? Data(contentsOf: Self.ratingsFileURL),
           let saved = try? JSONDecoder().decode(SavedRatings.self, from: data) {
            starredShaders = Set(saved.starred)
            likedShaders = Set(saved.liked)
            midShaders = Set(saved.mid)
            dislikedShaders = Set(saved.disliked)
        } else if UserDefaults.standard.array(forKey: "starredShaders") != nil {
            // Migrate from UserDefaults to JSON file
            if let arr = UserDefaults.standard.array(forKey: "starredShaders") as? [Int] { starredShaders = Set(arr) }
            if let arr = UserDefaults.standard.array(forKey: "likedShaders") as? [Int] { likedShaders = Set(arr) }
            if let arr = UserDefaults.standard.array(forKey: "midShaders") as? [Int] { midShaders = Set(arr) }
            if let arr = UserDefaults.standard.array(forKey: "dislikedShaders") as? [Int] { dislikedShaders = Set(arr) }
            saveRatings() // migrate to file
        } else {
            // First launch: seed with defaults
            starredShaders = Self.defaultStarred
            likedShaders = Self.defaultLiked
            midShaders = Self.defaultMid
            dislikedShaders = Self.defaultDisliked
            saveRatings()
        }
        // Load per-shader tunings from JSON file (fall back to UserDefaults for migration)
        if let data = try? Data(contentsOf: Self.tuningsFileURL),
           let decoded = try? JSONDecoder().decode([Int: ShaderTuning].self, from: data) {
            shaderTunings = decoded
        } else if let data = UserDefaults.standard.data(forKey: "shaderTunings"),
                  let decoded = try? JSONDecoder().decode([Int: ShaderTuning].self, from: data) {
            shaderTunings = decoded
            saveTunings() // migrate to file
        }
        // Load shader profiles
        if let data = try? Data(contentsOf: Self.profilesFileURL),
           let decoded = try? JSONDecoder().decode([Int: ShaderProfile].self, from: data) {
            shaderProfiles = decoded
        }
        isLoading = false
    }

    // Tunings file lives next to the project so it's visible, version-controllable, and won't vanish
    private static let tuningsFileURL: URL = {
        // Save alongside the app bundle's parent directory (the project root)
        let projectDir = URL(fileURLWithPath: "/Users/adamghaleb/Documents/windsurf projects/fadicode-shader-lab")
        return projectDir.appendingPathComponent("shader-tunings.json")
    }()

    private func saveTunings() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(shaderTunings) {
            try? data.write(to: Self.tuningsFileURL, options: .atomic)
        }
    }

    // Profiles file lives next to tunings
    private static let profilesFileURL: URL = {
        let projectDir = URL(fileURLWithPath: "/Users/adamghaleb/Documents/windsurf projects/fadicode-shader-lab")
        return projectDir.appendingPathComponent("shader-profiles.json")
    }()

    private func saveProfiles() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(shaderProfiles) {
            try? data.write(to: Self.profilesFileURL, options: .atomic)
        }
    }

    private static let exportFileURL: URL = {
        let projectDir = URL(fileURLWithPath: "/Users/adamghaleb/Documents/windsurf projects/fadicode-shader-lab")
        return projectDir.appendingPathComponent("shader-profiles-export.json")
    }()

    func exportProfilesJSON() -> String {
        struct ExportEntry: Codable {
            let mode: Int
            let name: String
            let coverage: String
            let density: String
            let speed: String
            let energy: String
            let tags: [String]
            let tuning: ExportTuning?
        }
        struct ExportTuning: Codable {
            let speedMultiplier: Double
            let contrast: Double
            let brightness: Double
        }

        let entries: [ExportEntry] = shaderProfiles.keys.sorted().compactMap { mode in
            guard let profile = shaderProfiles[mode],
                  let preset = shaderPresets.first(where: { $0.mode == mode }) else { return nil }
            let tuning = shaderTunings[mode]
            return ExportEntry(
                mode: mode,
                name: preset.name,
                coverage: profile.coverage.rawValue,
                density: profile.density.rawValue,
                speed: profile.speed.rawValue,
                energy: profile.energy.rawValue,
                tags: profile.tags.map(\.rawValue).sorted(),
                tuning: tuning.map { ExportTuning(speedMultiplier: $0.speedMultiplier, contrast: $0.contrast, brightness: $0.brightness) }
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = (try? encoder.encode(entries)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)

        // Write to file
        try? json.write(to: Self.exportFileURL, atomically: true, encoding: .utf8)

        return json
    }

    private static let ratingsFileURL: URL = {
        let projectDir = URL(fileURLWithPath: "/Users/adamghaleb/Documents/windsurf projects/fadicode-shader-lab")
        return projectDir.appendingPathComponent("shader-ratings.json")
    }()

    private struct SavedRatings: Codable {
        var starred: [Int]
        var liked: [Int]
        var mid: [Int]
        var disliked: [Int]
    }

    private func saveRatings() {
        let ratings = SavedRatings(
            starred: Array(starredShaders).sorted(),
            liked: Array(likedShaders).sorted(),
            mid: Array(midShaders).sorted(),
            disliked: Array(dislikedShaders).sorted()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(ratings) {
            try? data.write(to: Self.ratingsFileURL, options: .atomic)
        }
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
                // Shader renders behind terminal text
                WorkingStateOverlay(
                    isActive: state.isWorkingStateActive,
                    isFocused: state.isFocused,
                    themeColor: state.themeColor,
                    mode: state.shaderMode,
                    speed: state.shaderSpeed,
                    maxIntensity: state.maxIntensity,
                    focusedIntensity: state.focusedIntensity,
                    focusedOpacity: state.focusedOpacity,
                    focusInDuration: state.focusInDuration,
                    focusOutDuration: state.focusOutDuration,
                    pixelSize: state.pixelSize,
                    gridOpacity: state.gridOpacity,
                    focusedGridOpacity: state.focusedGridOpacity,
                    resolutionScale: state.resolutionScale,
                    posterizeLevels: state.posterizeLevels,
                    hueSpread: state.hueSpread,
                    complementMix: state.complementMix,
                    transitionDuration: state.transitionDuration,
                    paletteFloats: state.paletteFloats,
                    paletteCount: state.paletteStopCount,
                    shaderTunings: state.shaderTunings
                )

                // Terminal text renders on top of shader
                MockTerminalView()

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
            .contentShape(Rectangle())
            .onTapGesture {
                state.isFocused.toggle()
            }

            // Right: Debug panel
            DebugPanel()
                .frame(width: 320)
        }
    }
}
