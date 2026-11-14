import AppKit
import Combine

/// Watches the ShaderLab source directory for .metal and .swift changes,
/// then triggers an xcodebuild + relaunch cycle (hot reload).
final class ShaderFileWatcher: ObservableObject {

    enum BuildStatus: String {
        case idle = "Idle"
        case building = "Building..."
        case ready = "Ready"
        case error = "Error"
    }

    @Published var status: BuildStatus = .idle
    @Published var lastError: String?

    private var stream: FSEventStreamRef?
    private var debounceWork: DispatchWorkItem?
    private let projectPath: String
    private let watchPath: String

    init() {
        // Resolve project root relative to the running app's bundle
        let bundle = Bundle.main.bundlePath
        // ShaderLab.app lives inside build/Build/Products/Debug/ShaderLab.app (or similar)
        // Walk up to find the project root containing ShaderLab.xcodeproj
        var url = URL(fileURLWithPath: bundle)
        var found = false
        for _ in 0..<10 {
            url = url.deletingLastPathComponent()
            let xcodeproj = url.appendingPathComponent("ShaderLab.xcodeproj")
            if FileManager.default.fileExists(atPath: xcodeproj.path) {
                found = true
                break
            }
        }

        if found {
            projectPath = url.path
            watchPath = url.appendingPathComponent("ShaderLab").path
        } else {
            // Fallback: hardcoded dev path
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            projectPath = "\(home)/Documents/windsurf projects/fadicode-shader-lab"
            watchPath = "\(projectPath)/ShaderLab"
        }
    }

    func start() {
        guard stream == nil else { return }

        let pathsToWatch = [watchPath] as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagUseCFTypes) |
            UInt32(kFSEventStreamCreateFlagFileEvents)

        guard let eventStream = FSEventStreamCreate(
            nil,
            { (_, info, numEvents, eventPaths, _, _) in
                guard let info = info else { return }
                let watcher = Unmanaged<ShaderFileWatcher>.fromOpaque(info).takeUnretainedValue()

                // Check if any changed paths are .metal or .swift
                guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
                let relevant = paths.contains { path in
                    path.hasSuffix(".metal") || path.hasSuffix(".swift")
                }
                if relevant {
                    watcher.scheduleRebuild()
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // latency in seconds
            flags
        ) else { return }

        self.stream = eventStream
        FSEventStreamSetDispatchQueue(eventStream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(eventStream)
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil

        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        DispatchQueue.main.async { self.status = .idle }
    }

    private func scheduleRebuild() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.rebuild()
        }
        debounceWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func rebuild() {
        DispatchQueue.main.async { self.status = .building }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "-project", "\(projectPath)/ShaderLab.xcodeproj",
            "-scheme", "ShaderLab",
            "-configuration", "Debug",
            "build"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                DispatchQueue.main.async {
                    self.status = .ready
                    self.lastError = nil
                }
                relaunch()
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown build error"
                // Extract last few lines for a useful error message
                let lines = output.components(separatedBy: "\n")
                let errorLines = lines.suffix(10).joined(separator: "\n")
                DispatchQueue.main.async {
                    self.status = .error
                    self.lastError = errorLines
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.status = .error
                self.lastError = error.localizedDescription
            }
        }
    }

    private func relaunch() {
        guard let appURL = Bundle.main.bundleURL as URL? else { return }

        // Launch a new instance, then terminate the current one
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }
}
