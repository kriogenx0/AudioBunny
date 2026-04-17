import Foundation

// MARK: - Plugin Category

enum PluginCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case instrument = "Instrument"
    case effect = "Effect"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .instrument: return "pianokeys"
        case .effect: return "waveform.badge.magnifyingglass"
        }
    }
}

// MARK: - Catalog Plugin

struct CatalogPlugin: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let developer: String
    let description: String
    let category: PluginCategory
    let formats: [String]   // "AU", "VST2", "VST3"
    let tags: [String]
    let version: String
    let websiteURL: String
    let price: String
}

// MARK: - Catalog Response

struct PluginCatalogResponse: Codable {
    let version: String
    let plugins: [CatalogPlugin]
}
