import SwiftUI
import AVFoundation

@main
struct AudioBunnyApp: App {
    @StateObject private var pluginManager = PluginManager()
    @StateObject private var catalogManager = CatalogManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pluginManager)
                .environmentObject(catalogManager)
                .frame(minWidth: 900, minHeight: 600)
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
