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

    var disabledFolderURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Audio/Plug-Ins/Disabled")
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

    init() {
        refresh()
    }

    func refresh() {
        Task {
            await scan()
        }
    }

    private func scan() async {
        isScanning = true
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

        // Deduplicate by file URL
        var seen = Set<URL>()
        let deduped = discovered.filter { seen.insert($0.fileURL).inserted }

        // Preserve existing test results for plugins we already know about
        let existingByURL = Dictionary(uniqueKeysWithValues: plugins.map { ($0.fileURL, $0.status) })
        for plugin in deduped {
            if let existingStatus = existingByURL[plugin.fileURL], plugin.status != .disabled {
                plugin.status = existingStatus
            }
        }

        plugins = deduped.sorted { $0.name < $1.name }
        isScanning = false
    }

    // MARK: - Audio Unit Discovery

    private func scanAudioUnits() -> [AudioPlugin] {
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
                componentDescription: desc
            )
        }
    }

    // MARK: - VST Discovery

    private func scanVSTDirectory(_ directory: URL, type: PluginType) -> [AudioPlugin] {
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
                    return AudioPlugin(name: name, manufacturer: manufacturer, type: type, fileURL: url)
                }
        } catch {
            return []
        }
    }

    private func scanDisabledPlugins(extension ext: String, type: PluginType) -> [AudioPlugin] {
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
                    return AudioPlugin(name: name, manufacturer: manufacturer, type: type, fileURL: url)
                }
        } catch {
            return []
        }
    }

    private func extractManufacturerFromBundle(_ url: URL) -> String? {
        guard let bundle = Bundle(url: url),
              let info = bundle.infoDictionary else { return nil }
        return info["CFBundleGetInfoString"] as? String
            ?? info["NSHumanReadableCopyright"] as? String
            ?? info["CFBundleIdentifier"] as? String
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

        // Try loading the bundle
        guard let bundle = Bundle(url: url) else {
            plugin.status = .failed("Cannot create bundle")
            return
        }

        guard bundle.load() else {
            plugin.status = .failed("Bundle failed to load")
            return
        }

        // Check for the required VST entry point symbol
        let handle = dlopen(bundle.executableURL?.path, RTLD_LAZY | RTLD_LOCAL)
        if handle == nil {
            let errMsg = String(cString: dlerror())
            bundle.unload()
            plugin.status = .failed("dlopen: \(errMsg)")
            return
        }

        let sym = dlsym(handle, expectedSymbol)
        dlclose(handle)
        bundle.unload()

        if sym != nil {
            plugin.status = .active
        } else {
            plugin.status = .failed("Missing entry point '\(expectedSymbol)'")
        }
    }

    // MARK: - Disable / Enable

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
}
