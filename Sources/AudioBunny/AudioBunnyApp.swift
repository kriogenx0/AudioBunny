import SwiftUI
import AVFoundation

@main
struct AudioBunnyApp: App {
    @StateObject private var pluginManager = PluginManager()
    @StateObject private var catalogManager = CatalogManager()
    @StateObject private var downloadManager = DownloadManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pluginManager)
                .environmentObject(catalogManager)
                .environmentObject(downloadManager)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    // Wire the back-reference so DownloadManager can trigger rescans.
                    downloadManager.pluginManager = pluginManager
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
