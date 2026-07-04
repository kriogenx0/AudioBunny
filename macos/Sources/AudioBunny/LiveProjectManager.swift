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
    process.standardError = Pipe()
    try process.run()
    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0, !data.isEmpty else {
        throw NSError(domain: "LiveProjectManager", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not read \(url.lastPathComponent)"
        ])
    }
    return data
}

// MARK: - Manager

@MainActor
class LiveProjectManager: ObservableObject {
    @Published var projects: [LiveProject] = []
    @Published var isScanning = false
    @Published var scanError: String?

    // Progress
    @Published var scanCurrentIndex: Int = 0
    @Published var scanTotalCount: Int = 0
    @Published var scanCurrentFile: String = ""
    @Published var scanFoundCount: Int = 0

    func scanDirectory(_ url: URL) async {
        isScanning = true
        scanCurrentIndex = 0
        scanTotalCount = 0
        scanFoundCount = 0
        scanCurrentFile = "Finding projects…"
        scanError = nil
        projects = []

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

        scanTotalCount = alsURLs.count
        var result: [LiveProject] = []

        // Second pass: parse each file, reporting progress per file
        for (index, fileURL) in alsURLs.enumerated() {
            scanCurrentIndex = index + 1
            scanCurrentFile = fileURL.lastPathComponent
            if let project = try? await Task.detached { try parseAbletonProject(at: fileURL) }.value {
                result.append(project)
                scanFoundCount += 1
            }
        }

        projects = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isScanning = false
        scanCurrentFile = ""
    }

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
