import Foundation
import AppKit

// MARK: - Catalog Manager

@MainActor
class CatalogManager: ObservableObject {
    @Published var catalogPlugins: [CatalogPlugin] = []
    @Published var searchText = ""
    @Published var filterCategory: PluginCategory? = nil
    @Published var filterFormat: String? = nil

    init() {
        loadCatalog()
    }

    private func loadCatalog() {
        guard let url = Bundle.module.url(forResource: "PluginCatalog", withExtension: "json") else {
            print("CatalogManager: PluginCatalog.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(PluginCatalogResponse.self, from: data)
            catalogPlugins = response.plugins
        } catch {
            print("CatalogManager: Failed to decode catalog: \(error)")
        }
    }

    func filteredPlugins(installedPlugins: [AudioPlugin]) -> [CatalogPlugin] {
        catalogPlugins.filter { plugin in
            let matchesCategory = filterCategory == nil || plugin.category == filterCategory
            let matchesFormat = filterFormat == nil || plugin.formats.contains(filterFormat!)
            let matchesSearch = searchText.isEmpty ||
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.developer.localizedCaseInsensitiveContains(searchText) ||
                plugin.description.localizedCaseInsensitiveContains(searchText) ||
                plugin.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesCategory && matchesFormat && matchesSearch
        }
    }

    /// Returns the installed AudioPlugin matching a catalog entry (by name + format).
    func installedPlugin(for catalogPlugin: CatalogPlugin, in plugins: [AudioPlugin]) -> AudioPlugin? {
        plugins.first { installed in
            let nameMatch = installed.name.localizedCaseInsensitiveContains(catalogPlugin.name) ||
                catalogPlugin.name.localizedCaseInsensitiveContains(installed.name)
            let formatMatch = catalogPlugin.formats.contains { format in
                switch format {
                case "AU":   return installed.type == .audioUnit
                case "VST2": return installed.type == .vst2
                case "VST3": return installed.type == .vst3
                default:     return false
                }
            }
            return nameMatch && formatMatch
        }
    }

    func isInstalled(_ catalogPlugin: CatalogPlugin, in plugins: [AudioPlugin]) -> Bool {
        installedPlugin(for: catalogPlugin, in: plugins) != nil
    }

    func openWebsite(_ plugin: CatalogPlugin) {
        guard let url = URL(string: plugin.websiteURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
