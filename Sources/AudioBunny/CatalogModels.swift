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

    /// Direct URL to a zip/pkg/dmg download.
    let downloadURL: String?
    /// GitHub "owner/repo" — used to resolve the latest release asset at runtime.
    let githubRepo: String?

    /// True when an automated install path exists.
    var isDownloadable: Bool { downloadURL != nil || githubRepo != nil }
}

// MARK: - Catalog Response

struct PluginCatalogResponse: Codable {
    let version: String
    let plugins: [CatalogPlugin]
}
