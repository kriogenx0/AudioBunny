import Foundation
import AppKit

// MARK: - Install State

struct InstallState {
    enum Phase {
        case resolving
        case downloading(progress: Double)
        case extracting
        case installing
        case failed(String)
    }

    var phase: Phase

    /// Overall 0–1 progress value across all phases.
    var progressFraction: Double {
        switch phase {
        case .resolving:                    return 0.04
        case .downloading(let p):           return 0.04 + p * 0.76
        case .extracting:                   return 0.84
        case .installing:                   return 0.94
        case .failed:                       return 0
        }
    }

    var label: String {
        switch phase {
        case .resolving:                    return "Resolving download..."
        case .downloading(let p):           return String(format: "Downloading %.0f%%", p * 100)
        case .extracting:                   return "Extracting..."
        case .installing:                   return "Installing..."
        case .failed(let msg):              return msg
        }
    }

    var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }
}

// MARK: - Download Errors

enum DownloadError: LocalizedError {
    case noDownloadSource
    case noMacAssetFound
    case extractionFailed(String)
    case noPluginBundlesFound

    var errorDescription: String? {
        switch self {
        case .noDownloadSource:     return "No download source available for this plugin"
        case .noMacAssetFound:      return "No macOS asset found in the latest release"
        case .extractionFailed(let s): return "Extraction failed: \(s)"
        case .noPluginBundlesFound: return "No plugin bundles found inside the archive"
        }
    }
}

// MARK: - GitHub API models

private struct GitHubRelease: Decodable {
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}

// MARK: - Download Manager

@MainActor
final class DownloadManager: ObservableObject {
    @Published var states: [String: InstallState] = [:]

    /// Filled in by AudioBunnyApp after both objects are created.
    weak var pluginManager: PluginManager?

    private var taskPluginMap: [Int: String] = [:]
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private let delegate = SessionDelegate()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 300
        // Use .main queue so delegate callbacks arrive on the main actor.
        session = URLSession(configuration: config, delegate: delegate, delegateQueue: .main)
        delegate.manager = self
    }

    // MARK: Public API

    func install(_ plugin: CatalogPlugin) {
        guard states[plugin.id] == nil else { return }
        states[plugin.id] = InstallState(phase: .resolving)
        Task { await resolveAndStart(plugin: plugin) }
    }

    func cancel(_ pluginId: String) {
        activeTasks[pluginId]?.cancel()
        activeTasks.removeValue(forKey: pluginId)
        taskPluginMap = taskPluginMap.filter { $0.value != pluginId }
        states.removeValue(forKey: pluginId)
    }

    func dismissError(for pluginId: String) {
        if states[pluginId]?.isFailed == true {
            states.removeValue(forKey: pluginId)
        }
    }

    // MARK: Resolution

    private func resolveAndStart(plugin: CatalogPlugin) async {
        let url: URL

        if let direct = plugin.downloadURL, let u = URL(string: direct) {
            url = u
        } else if let repo = plugin.githubRepo {
            switch await resolveGitHubAsset(repo: repo) {
            case .success(let u):   url = u
            case .failure(let err): return fail(plugin.id, err.localizedDescription)
            }
        } else {
            return fail(plugin.id, DownloadError.noDownloadSource.localizedDescription!)
        }

        states[plugin.id] = InstallState(phase: .downloading(progress: 0))
        let task = session.downloadTask(with: url)
        activeTasks[plugin.id] = task
        taskPluginMap[task.taskIdentifier] = plugin.id
        task.resume()
    }

    private func resolveGitHubAsset(repo: String) async -> Result<URL, Error> {
        guard let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            return .failure(DownloadError.noMacAssetFound)
        }
        do {
            var req = URLRequest(url: apiURL)
            req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            req.setValue("AudioBunny/1.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

            // Prefer .zip for auto-extract; fall back to .pkg or .dmg
            let macAssets = release.assets.filter { a in
                let n = a.name.lowercased()
                let isMac = n.contains("mac") || n.contains("osx") || n.contains("darwin")
                let validExt = n.hasSuffix(".zip") || n.hasSuffix(".pkg") || n.hasSuffix(".dmg")
                return isMac && validExt
            }
            let pick = macAssets.first { $0.name.lowercased().hasSuffix(".zip") } ?? macAssets.first
            guard let asset = pick, let url = URL(string: asset.browserDownloadURL) else {
                return .failure(DownloadError.noMacAssetFound)
            }
            return .success(url)
        } catch {
            return .failure(error)
        }
    }

    // MARK: Delegate callbacks (called by SessionDelegate on main queue)

    fileprivate func didUpdateProgress(taskId: Int, written: Int64, total: Int64) {
        guard let pluginId = taskPluginMap[taskId] else { return }
        let p = total > 0 ? Double(written) / Double(total) : 0
        states[pluginId] = InstallState(phase: .downloading(progress: p))
    }

    fileprivate func didFinishDownload(taskId: Int, fileURL: URL) {
        guard let pluginId = taskPluginMap[taskId] else { return }
        taskPluginMap.removeValue(forKey: taskId)
        activeTasks.removeValue(forKey: pluginId)
        states[pluginId] = InstallState(phase: .extracting)
        Task { await processFile(pluginId: pluginId, fileURL: fileURL) }
    }

    fileprivate func didFailDownload(taskId: Int, error: Error) {
        guard let pluginId = taskPluginMap[taskId] else { return }
        taskPluginMap.removeValue(forKey: taskId)
        activeTasks.removeValue(forKey: pluginId)
        fail(pluginId, error.localizedDescription)
    }

    // MARK: Extraction & Installation

    private func processFile(pluginId: String, fileURL: URL) async {
        let ext = fileURL.pathExtension.lowercased()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        do {
            if ext == "zip" {
                let extractDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(pluginId)-extracted")
                try? FileManager.default.removeItem(at: extractDir)
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: extractDir) }

                try await unzip(fileURL, to: extractDir)

                let bundles = findPluginBundles(in: extractDir)
                guard !bundles.isEmpty else { throw DownloadError.noPluginBundlesFound }

                states[pluginId] = InstallState(phase: .installing)
                for bundle in bundles { try installBundle(bundle) }

            } else if ext == "pkg" || ext == "dmg" {
                // Hand off to system installer / Finder
                NSWorkspace.shared.open(fileURL)
            }

            states.removeValue(forKey: pluginId)
            pluginManager?.refresh()

        } catch {
            fail(pluginId, error.localizedDescription)
        }
    }

    private func unzip(_ zipURL: URL, to directory: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            p.arguments = ["-q", "-o", zipURL.path, "-d", directory.path]
            p.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(throwing: DownloadError.extractionFailed("exit \(proc.terminationStatus)"))
                }
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }

    private func findPluginBundles(in directory: URL) -> [URL] {
        let pluginExtensions = Set(["component", "vst", "vst3"])
        var found: [URL] = []
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        for case let url as URL in enumerator {
            if pluginExtensions.contains(url.pathExtension.lowercased()) {
                found.append(url)
                enumerator.skipDescendants()
            }
        }
        return found
    }

    private func installBundle(_ bundleURL: URL) throws {
        let fm = FileManager.default
        let destDir: URL
        switch bundleURL.pathExtension.lowercased() {
        case "component":
            destDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Audio/Plug-Ins/Components")
        case "vst":
            destDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Audio/Plug-Ins/VST")
        case "vst3":
            destDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Audio/Plug-Ins/VST3")
        default:
            return
        }
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        let dest = destDir.appendingPathComponent(bundleURL.lastPathComponent)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: bundleURL, to: dest)
    }

    // MARK: Helpers

    private func fail(_ pluginId: String, _ message: String) {
        states[pluginId] = InstallState(phase: .failed(message))
    }
}

// MARK: - URLSession Delegate (non-isolated bridge)

private final class SessionDelegate: NSObject, URLSessionDownloadDelegate {
    // Set by DownloadManager.init(); always accessed on main queue.
    var manager: DownloadManager?

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData _: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite total: Int64) {
        // delegateQueue is .main, so we're on the main queue here.
        // Hop to MainActor isolation explicitly to satisfy the compiler.
        let taskId = downloadTask.taskIdentifier
        Task { @MainActor [weak manager] in
            manager?.didUpdateProgress(taskId: taskId, written: totalBytesWritten, total: total)
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Copy the temp file NOW — URLSession deletes it when this method returns.
        let taskId = downloadTask.taskIdentifier
        let ext = downloadTask.response?.url?.pathExtension ?? "zip"
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(taskId)-\(UUID().uuidString).\(ext)")
        try? FileManager.default.copyItem(at: location, to: dest)

        Task { @MainActor [weak manager] in
            manager?.didFinishDownload(taskId: taskId, fileURL: dest)
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error else { return }
        let taskId = task.taskIdentifier
        Task { @MainActor [weak manager] in
            manager?.didFailDownload(taskId: taskId, error: error)
        }
    }
}
