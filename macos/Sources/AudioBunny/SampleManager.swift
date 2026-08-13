import Foundation
import AVFoundation

struct SoundFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var name: String { url.deletingPathExtension().lastPathComponent }
    var fileExtension: String { url.pathExtension.uppercased() }

    static func == (lhs: SoundFile, rhs: SoundFile) -> Bool { lhs.url == rhs.url }
}

struct SampleFolder: Identifiable {
    let id = UUID()
    let url: URL
    var samples: [SoundFile] = []
    var isScanning = false

    var name: String { url.lastPathComponent }
}

private let soundFileExtensions: Set<String> = ["wav", "aif", "aiff", "mp3", "m4a", "caf", "flac", "ogg"]

@MainActor
class SampleManager: NSObject, ObservableObject {
    @Published var folders: [SampleFolder] = []
    @Published var currentlyPlayingID: UUID?

    private let savedPathsKey = "audiobunny.sampleFolderPaths"
    private let userDefaults: UserDefaults
    private var player: AVAudioPlayer?

    /// - Parameters:
    ///   - userDefaults: injectable for testing; defaults to the app's real defaults.
    ///   - autoRescanOnLaunch: kicks off a background scan for each restored folder.
    init(userDefaults: UserDefaults = .standard, autoRescanOnLaunch: Bool = true) {
        self.userDefaults = userDefaults
        super.init()
        let paths = userDefaults.stringArray(forKey: savedPathsKey) ?? []
        folders = paths.map { SampleFolder(url: URL(fileURLWithPath: $0)) }
        guard autoRescanOnLaunch else { return }
        for folder in folders {
            Task { await scan(folderID: folder.id) }
        }
    }

    func addFolder(_ url: URL) {
        guard !folders.contains(where: { $0.url.path == url.path }) else { return }
        let folder = SampleFolder(url: url)
        folders.append(folder)
        persistFolders()
        Task { await scan(folderID: folder.id) }
    }

    func removeFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        persistFolders()
    }

    func rescan(folderID: UUID) {
        Task { await scan(folderID: folderID) }
    }

    func rescanAll() {
        for folder in folders {
            Task { await scan(folderID: folder.id) }
        }
    }

    private func persistFolders() {
        userDefaults.set(folders.map { $0.url.path }, forKey: savedPathsKey)
    }

    private func scan(folderID: UUID) async {
        guard let idx = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let url = folders[idx].url
        folders[idx].isScanning = true

        // Filesystem enumeration is synchronous and can take a moment for large
        // sample libraries; run it off the main actor so the UI stays responsive.
        let found: [SoundFile] = await Task.detached(priority: .userInitiated) {
            var results: [SoundFile] = []
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return results }
            for case let fileURL as URL in enumerator {
                if soundFileExtensions.contains(fileURL.pathExtension.lowercased()) {
                    results.append(SoundFile(url: fileURL))
                }
            }
            return results
        }.value

        guard let idx2 = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[idx2].samples = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        folders[idx2].isScanning = false
    }

    func togglePlay(_ sample: SoundFile) {
        if currentlyPlayingID == sample.id {
            stop()
            return
        }
        stop()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: sample.url) else { return }
        newPlayer.delegate = self
        player = newPlayer
        newPlayer.play()
        currentlyPlayingID = sample.id
    }

    func stop() {
        player?.stop()
        player = nil
        currentlyPlayingID = nil
    }
}

extension SampleManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
