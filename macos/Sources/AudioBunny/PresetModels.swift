import Foundation

// MARK: - Auth

struct AuthResponse: Decodable {
    let token: String
    let user: APIUser
}

struct APIUser: Decodable, Equatable {
    let id: Int
    let email: String
    let username: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, username
        case createdAt = "created_at"
    }
}

// MARK: - Plugin

struct APIPlugin: Decodable, Identifiable {
    let id: Int
    let name: String
    let manufacturer: String
    let pluginType: String
    let description: String?
    let version: String?
    let tags: String?
    let isFree: Bool
    let priceUsd: Double?
    let favorited: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, manufacturer, description, version, tags, favorited
        case pluginType = "plugin_type"
        case isFree     = "is_free"
        case priceUsd   = "price_usd"
    }
}

// MARK: - Preset

struct APIPreset: Decodable, Identifiable, Hashable {
    let id: Int
    let pluginId: Int
    let pluginName: String?
    let name: String
    let author: String
    let genre: String
    let description: String?
    let tags: [String]
    let fileExtension: String
    let fileSizeBytes: Int?
    let isDownloadable: Bool
    let isCommunity: Bool
    let uploaderUsername: String?
    let favorited: Bool
    let installed: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, author, genre, description, tags, favorited, installed
        case pluginId          = "plugin_id"
        case pluginName        = "plugin_name"
        case fileExtension     = "file_extension"
        case fileSizeBytes     = "file_size_bytes"
        case isDownloadable    = "is_downloadable"
        case isCommunity       = "is_community"
        case uploaderUsername  = "uploader_username"
        case createdAt         = "created_at"
    }

    static func == (lhs: APIPreset, rhs: APIPreset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Install

struct APIInstall: Decodable {
    let installId: Int
    let status: String
    let id: Int
    let pluginId: Int
    let pluginName: String?
    let name: String
    let fileExtension: String
    let isDownloadable: Bool

    enum CodingKeys: String, CodingKey {
        case status, name
        case installId     = "install_id"
        case id
        case pluginId      = "plugin_id"
        case pluginName    = "plugin_name"
        case fileExtension = "file_extension"
        case isDownloadable = "is_downloadable"
    }
}
