import SwiftUI
import AVFoundation

let appVersion = "1.0.0"

@main
struct AudioBunnyApp: App {
    @StateObject private var pluginManager = PluginManager()
    @StateObject private var catalogManager = CatalogManager()
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var liveProjectManager = LiveProjectManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pluginManager)
                .environmentObject(catalogManager)
                .environmentObject(downloadManager)
                .environmentObject(presetManager)
                .environmentObject(liveProjectManager)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    downloadManager.pluginManager = pluginManager
                    pluginManager.refresh()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh Plugins") {
                    pluginManager.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
