import Foundation

// MARK: - Parsing (free functions, nonisolated, safe to call from Task.detached)

func parseAbletonProject(at url: URL) throws -> LiveProject {
    let xmlData = try decompressAbletonFile(at: url)
    let xmlDoc = try XMLDocument(data: xmlData, options: [])

    var plugins: [LiveProjectPlugin] = []
    var seen = Set<String>()

    func add(name: String, manufacturer: String?, type: PluginType) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let key = "\(type.rawValue)|\(trimmed.lowercased())"
        guard seen.insert(key).inserted else { return }
        plugins.append(LiveProjectPlugin(name: trimmed, manufacturer: manufacturer, type: type))
    }

    for node in (try? xmlDoc.nodes(forXPath: "//VstPluginInfo")) ?? [] {
        guard let el = node as? XMLElement else { continue }
        add(
            name: el.elements(forName: "PlugName").first?.attribute(forName: "Value")?.stringValue ?? "",
            manufacturer: el.elements(forName: "Manufacturer").first?.attribute(forName: "Value")?.stringValue,
            type: .vst2
        )
    }

    for node in (try? xmlDoc.nodes(forXPath: "//Vst3PluginInfo")) ?? [] {
        guard let el = node as? XMLElement else { continue }
        add(
            name: el.elements(forName: "Name").first?.attribute(forName: "Value")?.stringValue ?? "",
            manufacturer: el.elements(forName: "Vendor").first?.attribute(forName: "Value")?.stringValue,
            type: .vst3
        )
    }

    for node in (try? xmlDoc.nodes(forXPath: "//AuPluginInfo")) ?? [] {
        guard let el = node as? XMLElement else { continue }
        add(
            name: el.elements(forName: "Name").first?.attribute(forName: "Value")?.stringValue ?? "",
            manufacturer: el.elements(forName: "Manufacturer").first?.attribute(forName: "Value")?.stringValue,
            type: .audioUnit
        )
    }

    return LiveProject(url: url, plugins: plugins)
}

private func decompressAbletonFile(at url: URL) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
    process.arguments = ["-c", url.path]
    let outPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    try? outPipe.fileHandleForReading.close()
    process.waitUntilExit()
    guard process.terminationStatus == 0, !data.isEmpty else {
        throw NSError(domain: "LiveProjectManager", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not read \(url.lastPathComponent)"
        ])
    }
    return data
}

// MARK: - Project Folder

struct ProjectFolder: Identifiable {
    let id = UUID()
    let url: URL
    var projects: [LiveProject] = []
    var isScanning = false
    var scanCurrentIndex = 0
    var scanTotalCount = 0
    var scanCurrentFile = ""
    var scanFoundCount = 0

    var name: String { url.lastPathComponent }

    var allUniquePlugins: [LiveProjectPlugin] {
        var seen = Set<String>()
        var result: [LiveProjectPlugin] = []
        for project in projects {
            for plugin in project.plugins {
                let key = "\(plugin.type?.rawValue ?? "")|\(plugin.name.lowercased())"
                if seen.insert(key).inserted { result.append(plugin) }
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func projectCount(for plugin: LiveProjectPlugin) -> Int {
        projects.filter { project in
            project.plugins.contains { p in
                p.name.lowercased() == plugin.name.lowercased() && p.type == plugin.type
            }
        }.count
    }
}

// MARK: - Manager

@MainActor
class LiveProjectManager: ObservableObject {
    @Published var folders: [ProjectFolder] = []

    private let savedPathsKey = "audiobunny.projectFolderPaths"
    private let userDefaults: UserDefaults

    /// - Parameters:
    ///   - userDefaults: injectable for testing; defaults to the app's real defaults.
    ///   - autoRescanOnLaunch: kicks off a background rescan for each restored folder.
    ///     Disabled in tests that only care about persisted paths, not live scan results.
    init(userDefaults: UserDefaults = .standard, autoRescanOnLaunch: Bool = true) {
        self.userDefaults = userDefaults
        let paths = userDefaults.stringArray(forKey: savedPathsKey) ?? []
        folders = paths.map { ProjectFolder(url: URL(fileURLWithPath: $0)) }
        guard autoRescanOnLaunch else { return }
        for folder in folders {
            Task { await rescan(folderID: folder.id) }
        }
    }

    func addFolder(_ url: URL) {
        guard !folders.contains(where: { $0.url.path == url.path }) else { return }
        let folder = ProjectFolder(url: url)
        folders.append(folder)
        persistFolders()
        Task { await rescan(folderID: folder.id) }
    }

    func removeFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        persistFolders()
    }

    private func persistFolders() {
        userDefaults.set(folders.map { $0.url.path }, forKey: savedPathsKey)
    }

    func rescan(folderID: UUID) async {
        guard let idx = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let url = folders[idx].url

        folders[idx].isScanning = true
        folders[idx].scanCurrentIndex = 0
        folders[idx].scanTotalCount = 0
        folders[idx].scanFoundCount = 0
        folders[idx].scanCurrentFile = "Finding projects…"
        folders[idx].projects = []

        // First pass: enumerate all .als paths (fast, no decompression)
        let alsURLs: [URL] = await Task.detached(priority: .userInitiated) {
            var urls: [URL] = []
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return urls }
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "als" { urls.append(fileURL) }
            }
            return urls
        }.value

        guard let idx2 = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[idx2].scanTotalCount = alsURLs.count

        // Second pass: parse each file, publishing each project as soon as it's found
        // so the sidebar list fills in live during the scan.
        for (index, fileURL) in alsURLs.enumerated() {
            guard let idx3 = folders.firstIndex(where: { $0.id == folderID }) else { return }
            folders[idx3].scanCurrentIndex = index + 1
            folders[idx3].scanCurrentFile = fileURL.lastPathComponent
            if let project = try? await Task.detached { try parseAbletonProject(at: fileURL) }.value {
                folders[idx3].projects.append(project)
                folders[idx3].scanFoundCount += 1
            }
        }

        guard let idx4 = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[idx4].projects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        folders[idx4].isScanning = false
        folders[idx4].scanCurrentFile = ""
    }

    var isScanning: Bool { folders.contains { $0.isScanning } }

    func project(withID id: UUID) -> LiveProject? {
        for folder in folders {
            if let project = folder.projects.first(where: { $0.id == id }) { return project }
        }
        return nil
    }

    func folder(containing projectID: UUID) -> ProjectFolder? {
        folders.first { folder in folder.projects.contains { $0.id == projectID } }
    }
}
