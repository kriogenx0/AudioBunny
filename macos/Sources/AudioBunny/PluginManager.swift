import Foundation
import AVFoundation
import AudioToolbox
import Combine

// MARK: - Plugin Manager

@MainActor
class PluginManager: ObservableObject {
    @Published var plugins: [AudioPlugin] = []
    @Published var isScanning = false
    @Published var filterType: PluginType? = nil
    @Published var filterStatus: PluginStatusFilter = .all
    @Published var searchText = ""

    enum PluginStatusFilter: String, CaseIterable {
        case all = "All"
        case untested = "Untested"
        case active = "Active"
        case failed = "Failed"
        case disabled = "Disabled"
    }

    // Standard plugin search paths
    private let systemAUPath = URL(fileURLWithPath: "/Library/Audio/Plug-Ins/Components")
    private let userAUPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Audio/Plug-Ins/Components")
    private let systemVST2Path = URL(fileURLWithPath: "/Library/Audio/Plug-Ins/VST")
    private let userVST2Path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Audio/Plug-Ins/VST")
    private let systemVST3Path = URL(fileURLWithPath: "/Library/Audio/Plug-Ins/VST3")
    private let userVST3Path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Audio/Plug-Ins/VST3")

    nonisolated var disabledFolderURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Audio/Plug-Ins/Disabled")
    }

    nonisolated private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var filteredPlugins: [AudioPlugin] {
        plugins.filter { plugin in
            let matchesType = filterType == nil || plugin.type == filterType
            let matchesSearch = searchText.isEmpty ||
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.manufacturer.localizedCaseInsensitiveContains(searchText)
            let matchesStatus: Bool = {
                switch filterStatus {
                case .all: return true
                case .untested:
                    if case .untested = plugin.status { return true }
                    return false
                case .active:
                    if case .active = plugin.status { return true }
                    return false
                case .failed:
                    if case .failed = plugin.status { return true }
                    return false
                case .disabled: return plugin.status == .disabled
                }
            }()
            return matchesType && matchesSearch && matchesStatus
        }
    }

    var pluginCounts: (total: Int, active: Int, failed: Int, disabled: Int, untested: Int) {
        let total = plugins.count
        let active = plugins.filter { if case .active = $0.status { return true }; return false }.count
        let failed = plugins.filter { if case .failed = $0.status { return true }; return false }.count
        let disabled = plugins.filter { $0.status == .disabled }.count
        let untested = plugins.filter { if case .untested = $0.status { return true }; return false }.count
        return (total, active, failed, disabled, untested)
    }

    func refresh() {
        Task {
            await scan()
        }
    }

    private func scan() async {
        isScanning = true

        // AVAudioUnitComponentManager enumeration and filesystem/bundle scans are
        // synchronous and can take a noticeable moment; run them off the main actor
        // so they don't contend with SwiftUI's initial window layout at launch.
        let discovered: [AudioPlugin] = await Task.detached { [self] in
            var discovered: [AudioPlugin] = []

            // Scan Audio Units via AVAudioUnitComponentManager
            discovered += scanAudioUnits()

            // Scan VST2
            discovered += scanVSTDirectory(systemVST2Path, type: .vst2)
            discovered += scanVSTDirectory(userVST2Path, type: .vst2)

            // Scan VST3
            discovered += scanVSTDirectory(systemVST3Path, type: .vst3)
            discovered += scanVSTDirectory(userVST3Path, type: .vst3)

            // Also scan disabled folder to restore disabled status
            let disabledAU = scanDisabledPlugins(extension: "component", type: .audioUnit)
            let disabledVST2 = scanDisabledPlugins(extension: "vst", type: .vst2)
            let disabledVST3 = scanDisabledPlugins(extension: "vst3", type: .vst3)
            let disabled = disabledAU + disabledVST2 + disabledVST3
            for p in disabled { p.status = .disabled }
            discovered += disabled

            return discovered
        }.value

        // Deduplicate by file URL
        var seen = Set<URL>()
        let deduped = discovered.filter { seen.insert($0.fileURL).inserted }

        // Restore last known test result for plugins whose name+version we've
        // tested before (persists across launches — see recordTestResult).
        let history = loadTestHistory()
        for plugin in deduped {
            guard plugin.status == .untested,
                  let key = testHistoryKey(for: plugin),
                  let record = history[key] else { continue }
            plugin.status = record.status
        }

        // Preserve existing (this-session) test results for plugins we already know about
        let existingByURL = Dictionary(uniqueKeysWithValues: plugins.map { ($0.fileURL, $0.status) })
        for plugin in deduped {
            if let existingStatus = existingByURL[plugin.fileURL], plugin.status != .disabled {
                plugin.status = existingStatus
            }
        }

        plugins = deduped.sorted { $0.name < $1.name }
        isScanning = false
    }

    // MARK: - Test History (persisted across launches)

    struct TestHistoryRecord: Codable, Equatable {
        let statusKind: String // "active" or "failed"
        let failureMessage: String?

        var status: PluginStatus {
            statusKind == "active" ? .active : .failed(failureMessage ?? "Unknown error")
        }
    }

    private let testHistoryDefaultsKey = "audiobunny.pluginTestHistory"

    /// Only plugins with a known version are tracked — without one we can't
    /// reliably tell "the same plugin, unchanged" from "a different install",
    /// so we'd rather re-test than silently misreport an untested plugin as OK.
    func testHistoryKey(for plugin: AudioPlugin) -> String? {
        guard let version = plugin.version else { return nil }
        return "\(plugin.type.rawValue)|\(plugin.name.lowercased())|\(version)"
    }

    func loadTestHistory() -> [String: TestHistoryRecord] {
        guard let data = userDefaults.data(forKey: testHistoryDefaultsKey),
              let history = try? JSONDecoder().decode([String: TestHistoryRecord].self, from: data) else {
            return [:]
        }
        return history
    }

    func recordTestResult(for plugin: AudioPlugin) {
        guard let key = testHistoryKey(for: plugin) else { return }
        let record: TestHistoryRecord
        switch plugin.status {
        case .active:
            record = TestHistoryRecord(statusKind: "active", failureMessage: nil)
        case .failed(let message):
            record = TestHistoryRecord(statusKind: "failed", failureMessage: message)
        default:
            return
        }
        var history = loadTestHistory()
        history[key] = record
        guard let data = try? JSONEncoder().encode(history) else { return }
        userDefaults.set(data, forKey: testHistoryDefaultsKey)
    }

    // MARK: - Audio Unit Discovery

    nonisolated private func scanAudioUnits() -> [AudioPlugin] {
        let manager = AVAudioUnitComponentManager.shared()
        let allComponents = manager.components(passingTest: { _, _ in true })

        return allComponents.map { component in
            let desc = component.audioComponentDescription
            let fileURL = component.iconURL?.deletingLastPathComponent()
                ?? URL(fileURLWithPath: "/Library/Audio/Plug-Ins/Components/\(component.name).component")

            return AudioPlugin(
                name: component.name,
                manufacturer: component.manufacturerName,
                type: .audioUnit,
                fileURL: fileURL,
                version: extractVersionFromBundle(fileURL),
                category: categoryForAUComponentType(desc.componentType),
                componentDescription: desc
            )
        }
    }

    // MARK: - VST Discovery

    nonisolated private func scanVSTDirectory(_ directory: URL, type: PluginType) -> [AudioPlugin] {
        guard let ext = type.fileExtension else { return [] }
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return contents
                .filter { $0.pathExtension.lowercased() == ext }
                .map { url in
                    let name = url.deletingPathExtension().lastPathComponent
                    let manufacturer = extractManufacturerFromBundle(url) ?? "Unknown"
                    return AudioPlugin(
                        name: name, manufacturer: manufacturer, type: type, fileURL: url,
                        version: extractVersionFromBundle(url),
                        category: detectVSTCategory(type: type, bundleURL: url, userDefaults: userDefaults)
                    )
                }
        } catch {
            return []
        }
    }

    nonisolated private func scanDisabledPlugins(extension ext: String, type: PluginType) -> [AudioPlugin] {
        guard FileManager.default.fileExists(atPath: disabledFolderURL.path) else { return [] }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: disabledFolderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return contents
                .filter { $0.pathExtension.lowercased() == ext }
                .map { url in
                    let name = url.deletingPathExtension().lastPathComponent
                    let manufacturer = extractManufacturerFromBundle(url) ?? "Unknown"
                    return AudioPlugin(
                        name: name, manufacturer: manufacturer, type: type, fileURL: url,
                        version: extractVersionFromBundle(url),
                        category: detectVSTCategory(type: type, bundleURL: url, userDefaults: userDefaults)
                    )
                }
        } catch {
            return []
        }
    }

    nonisolated private func extractManufacturerFromBundle(_ url: URL) -> String? {
        guard url.isFileURL,
              let bundle = Bundle(url: url),
              let info = bundle.infoDictionary else { return nil }
        return info["CFBundleGetInfoString"] as? String
            ?? info["NSHumanReadableCopyright"] as? String
            ?? info["CFBundleIdentifier"] as? String
    }

    nonisolated private func extractVersionFromBundle(_ url: URL) -> String? {
        guard url.isFileURL,
              let bundle = Bundle(url: url),
              let info = bundle.infoDictionary else { return nil }
        return info["CFBundleShortVersionString"] as? String
            ?? info["CFBundleVersion"] as? String
    }

    // MARK: - Plugin Testing

    func testPlugin(_ plugin: AudioPlugin) {
        Task {
            await performTest(plugin)
        }
    }

    func testAllUntested() {
        Task {
            let untested = plugins.filter {
                if case .untested = $0.status { return true }
                return false
            }
            for plugin in untested {
                await performTest(plugin)
            }
        }
    }

    private func performTest(_ plugin: AudioPlugin) async {
        plugin.status = .testing

        switch plugin.type {
        case .audioUnit:
            await testAudioUnit(plugin)
        case .vst2:
            testVSTBundle(plugin, expectedSymbol: "VSTPluginMain")
        case .vst3:
            testVSTBundle(plugin, expectedSymbol: "GetPluginFactory")
        }

        recordTestResult(for: plugin)
    }

    private func testAudioUnit(_ plugin: AudioPlugin) async {
        guard let desc = plugin.audioComponentDescription else {
            plugin.status = .failed("No component description")
            return
        }

        return await withCheckedContinuation { continuation in
            AVAudioUnit.instantiate(with: desc, options: []) { avAudioUnit, error in
                Task { @MainActor in
                    if let error = error {
                        plugin.status = .failed(error.localizedDescription)
                    } else if avAudioUnit != nil {
                        plugin.status = .active
                    } else {
                        plugin.status = .failed("Could not instantiate")
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func testVSTBundle(_ plugin: AudioPlugin, expectedSymbol: String) {
        let url = plugin.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            plugin.status = .failed("File not found")
            return
        }

        guard let bundle = Bundle(url: url),
              let executableURL = bundle.executableURL else {
            plugin.status = .failed("Cannot find bundle executable")
            return
        }

        // Use nm to inspect the symbol table without loading the plugin code,
        // avoiding crashes from buggy plugin initializers (EXC_BAD_ACCESS).
        guard let data = runProcessCapturingStdout(
            executable: "/usr/bin/nm",
            arguments: ["-g", "--defined-only", executableURL.path]
        ) else {
            plugin.status = .failed("Cannot inspect binary")
            return
        }
        let output = String(data: data, encoding: .utf8) ?? ""
        if output.contains(expectedSymbol) {
            plugin.status = .active
        } else {
            plugin.status = .failed("Missing entry point '\(expectedSymbol)'")
        }
    }

    // MARK: - Disable / Enable

    func disableAllFailing() {
        Task {
            let failing = plugins.filter {
                if case .failed = $0.status { return true }
                return false
            }
            for plugin in failing {
                await movePlugin(plugin, toDisabled: true)
            }
        }
    }

    func disablePlugin(_ plugin: AudioPlugin) {
        Task {
            await movePlugin(plugin, toDisabled: true)
        }
    }

    func enablePlugin(_ plugin: AudioPlugin) {
        Task {
            await movePlugin(plugin, toDisabled: false)
        }
    }

    private func movePlugin(_ plugin: AudioPlugin, toDisabled: Bool) async {
        let fm = FileManager.default
        let source = plugin.fileURL

        if toDisabled {
            // Ensure disabled folder exists
            try? fm.createDirectory(at: disabledFolderURL, withIntermediateDirectories: true)
            let destination = disabledFolderURL.appendingPathComponent(source.lastPathComponent)
            do {
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.moveItem(at: source, to: destination)
                plugin.status = .disabled
            } catch {
                print("Failed to disable \(plugin.name): \(error)")
            }
        } else {
            // Move back to the appropriate folder
            let destinationFolder = restoreDestination(for: plugin.type)
            try? fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            let destination = destinationFolder.appendingPathComponent(source.lastPathComponent)
            do {
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.moveItem(at: source, to: destination)
                plugin.status = .untested
                // Update the fileURL by rescanning
                await scan()
            } catch {
                print("Failed to enable \(plugin.name): \(error)")
            }
        }
    }

    private func restoreDestination(for type: PluginType) -> URL {
        switch type {
        case .audioUnit: return userAUPath
        case .vst2: return userVST2Path
        case .vst3: return userVST3Path
        }
    }

    func restorePath(for type: PluginType) -> String {
        restoreDestination(for: type).path
    }

    // MARK: - Delete (Uninstall)

    func deletePlugin(_ plugin: AudioPlugin) {
        Task {
            let fm = FileManager.default
            do {
                try fm.removeItem(at: plugin.fileURL)
                plugins.removeAll { $0.id == plugin.id }
            } catch {
                print("Failed to delete \(plugin.name): \(error)")
            }
        }
    }
}

// MARK: - Category Detection (free functions: not actor-isolated, unit-testable)

/// Maps an Audio Unit's component type to instrument/effect.
func categoryForAUComponentType(_ type: OSType) -> PluginCategory {
    switch type {
    case kAudioUnitType_MusicDevice, kAudioUnitType_Generator:
        return .instrument
    default:
        return .effect
    }
}

/// Best-effort: modern VST3 bundles ship Contents/Resources/moduleinfo.json
/// listing each class's category (e.g. "Instrument|Synth" or "Fx"). Not all
/// VST3 plugins include it, so this can return nil.
func categoryFromVST3ModuleInfo(_ bundleURL: URL) -> PluginCategory? {
    let infoURL = bundleURL.appendingPathComponent("Contents/Resources/moduleinfo.json")
    guard let data = try? Data(contentsOf: infoURL),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let classes = json["Classes"] as? [[String: Any]] else { return nil }
    for cls in classes {
        guard let category = cls["Category"] as? String else { continue }
        if category.localizedCaseInsensitiveContains("Instrument") { return .instrument }
        if category.localizedCaseInsensitiveContains("Fx") { return .effect }
    }
    return nil
}

/// Best-effort: some vendors (e.g. Native Instruments) encode the plugin kind
/// directly in the bundle identifier, like "Absynth 5.Synth.vst" (instrument)
/// vs "Guitar Rig 6.FX.vst" (effect). Not universal — plenty of vendors don't
/// follow this convention — but a real, useful signal when present, and safe:
/// it only reads Info.plist, never loads the plugin.
func categoryFromBundleIdentifier(_ bundleURL: URL) -> PluginCategory? {
    guard bundleURL.isFileURL,
          let bundle = Bundle(url: bundleURL),
          let identifier = bundle.bundleIdentifier else { return nil }
    let lower = identifier.lowercased()
    if lower.contains(".synth") { return .instrument }
    if lower.contains(".fx") { return .effect }
    return nil
}

/// Combines the available signals for a VST2/VST3 bundle, safest first:
/// VST3's moduleinfo.json (structured, no code execution) → the bundle
/// identifier naming convention (no code execution) → for VST2 only, as a
/// last resort, actually probing the plugin's entry point (runs real vendor
/// code in an isolated, timeout-guarded subprocess — can crash or hang, but
/// both are contained, and the outcome is cached forever either way so we
/// only ever pay that cost once per plugin — see categoryFromVST2Probe).
func detectVSTCategory(type: PluginType, bundleURL: URL, userDefaults: UserDefaults = .standard) -> PluginCategory? {
    if type == .vst3, let category = categoryFromVST3ModuleInfo(bundleURL) {
        return category
    }
    if let category = categoryFromBundleIdentifier(bundleURL) {
        return category
    }
    if type == .vst2 {
        return categoryFromVST2Probe(bundleURL, userDefaults: userDefaults)
    }
    return nil
}

/// True if the Mach-O binary at `url` has no arm64 slice — i.e. it needs
/// Rosetta translation (`arch -x86_64`) to run on Apple Silicon.
func isX86_64Only(_ url: URL) -> Bool {
    guard let data = runProcessCapturingStdout(executable: "/usr/bin/lipo", arguments: ["-info", url.path]),
          let output = String(data: data, encoding: .utf8) else { return false }
    return output.contains("x86_64") && !output.contains("arm64")
}

private let vst2ProbeCacheDefaultsKey = "audiobunny.vst2ProbeCache"

/// Last-resort VST2 detection: calls the plugin's real entry point (VSTPluginMain)
/// via the bundled VST2Prober helper to read AEffect.flags — the only place VST2
/// records instrument-vs-effect. Runs in an isolated, timeout-guarded subprocess
/// since this executes real vendor code, which can crash or hang. Requires
/// VST2Prober to sit next to the running app's executable (the Makefile copies
/// it there); if it's missing (e.g. running the raw `swift build` binary
/// directly, not the packaged .app), this simply returns nil.
///
/// The outcome — including "couldn't determine" — is cached permanently per
/// plugin path, exactly like a DAW's plugin database: real hosts pay this same
/// crash/hang risk once per plugin during their scan and then never touch that
/// plugin's entry point again. Without caching, an unresolved plugin (crashed
/// or timed out) would retry — and re-risk hanging for the full timeout — on
/// every single rescan.
func categoryFromVST2Probe(_ bundleURL: URL, userDefaults: UserDefaults = .standard) -> PluginCategory? {
    guard let bundle = Bundle(url: bundleURL), let executableURL = bundle.executableURL else { return nil }
    let cacheKey = executableURL.path

    var cache = (userDefaults.dictionary(forKey: vst2ProbeCacheDefaultsKey) as? [String: String]) ?? [:]
    if let cached = cache[cacheKey] {
        switch cached {
        case "instrument": return .instrument
        case "effect": return .effect
        default: return nil
        }
    }

    let result = probeVST2Category(executableURL: executableURL)
    cache[cacheKey] = result.map { $0 == .instrument ? "instrument" : "effect" } ?? "unknown"
    userDefaults.set(cache, forKey: vst2ProbeCacheDefaultsKey)
    return result
}

/// The actual (uncached) probe: locates the helper, picks native vs.
/// Rosetta-translated invocation based on the plugin's architecture, and runs
/// it with a timeout.
private func probeVST2Category(executableURL: URL) -> PluginCategory? {
    let proberURL = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("VST2Prober")
    guard let proberURL, FileManager.default.isExecutableFile(atPath: proberURL.path) else { return nil }

    let executable: String
    let arguments: [String]
    if isX86_64Only(executableURL) {
        executable = "/usr/bin/arch"
        arguments = ["-x86_64", proberURL.path, executableURL.path]
    } else {
        executable = proberURL.path
        arguments = [executableURL.path]
    }

    guard let data = runProcessWithTimeout(executable: executable, arguments: arguments, timeoutSeconds: 3),
          let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    else { return nil }

    switch output {
    case "instrument": return .instrument
    case "effect": return .effect
    default: return nil
    }
}

/// A plugin may exist as multiple format variants (AU/VST2/VST3) under the same
/// name. AU's category comes straight from its component type, so prefer it when
/// present; otherwise fall back to any other variant's best-effort category.
func preferredCategory(for group: [AudioPlugin]) -> PluginCategory? {
    if let au = group.first(where: { $0.type == .audioUnit })?.category { return au }
    return group.compactMap(\.category).first
}

// MARK: - Process Helper

/// Runs a process and returns its captured stdout, or nil if it couldn't be launched.
///
/// Reads stdout to EOF *before* calling `waitUntilExit()` — a process whose output
/// exceeds the pipe's kernel buffer (~64KB) will block writing more until it's
/// drained, so waiting on exit first deadlocks. Stderr is discarded via
/// `/dev/null` rather than an unread `Pipe()`, which has the same deadlock/fd-leak
/// problem. (This exact bug previously caused a hang/leak in VST symbol testing.)
func runProcessCapturingStdout(executable: String, arguments: [String]) -> Data? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    guard (try? process.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    try? pipe.fileHandleForReading.close()
    process.waitUntilExit()
    return data
}

/// Like `runProcessCapturingStdout`, but force-kills (SIGKILL) the process if
/// it doesn't finish within `timeoutSeconds`, returning nil in that case.
/// Reserved for probing untrusted plugin code that may hang, not just crash —
/// prefer `runProcessCapturingStdout` for trusted system tools.
func runProcessWithTimeout(executable: String, arguments: [String], timeoutSeconds: Double) -> Data? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    let semaphore = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in semaphore.signal() }

    guard (try? process.run()) != nil else { return nil }

    if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
        kill(process.processIdentifier, SIGKILL)
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    try? pipe.fileHandleForReading.close()
    return data
}
