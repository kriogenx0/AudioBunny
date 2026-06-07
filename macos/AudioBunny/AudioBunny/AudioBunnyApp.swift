import SwiftUI
import AVFoundation

@main
struct AudioBunnyApp: App {
    @StateObject private var pluginManager = PluginManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pluginManager)
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
