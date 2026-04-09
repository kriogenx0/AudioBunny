import Foundation
import AVFoundation
import AudioToolbox

// MARK: - Plugin Types

enum PluginType: String, CaseIterable {
    case audioUnit = "Audio Unit"
    case vst2 = "VST 2"
    case vst3 = "VST 3"

    var icon: String {
        switch self {
        case .audioUnit: return "waveform"
        case .vst2: return "puzzlepiece"
        case .vst3: return "puzzlepiece.fill"
        }
    }

    var fileExtension: String? {
        switch self {
        case .audioUnit: return "component"
        case .vst2: return "vst"
        case .vst3: return "vst3"
        }
    }
}

enum PluginStatus {
    case untested
    case testing
    case active
    case failed(String)
    case disabled
}

extension PluginStatus: Equatable {
    static func == (lhs: PluginStatus, rhs: PluginStatus) -> Bool {
        switch (lhs, rhs) {
        case (.untested, .untested), (.testing, .testing), (.active, .active), (.disabled, .disabled): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    var label: String {
        switch self {
        case .untested: return "Untested"
        case .testing: return "Testing..."
        case .active: return "Active"
        case .failed(let msg): return "Failed: \(msg)"
        case .disabled: return "Disabled"
        }
    }

    var color: String {
        switch self {
        case .untested: return "gray"
        case .testing: return "orange"
        case .active: return "green"
        case .failed: return "red"
        case .disabled: return "secondary"
        }
    }
}

// MARK: - Plugin Model

class AudioPlugin: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let manufacturer: String
    let type: PluginType
    let fileURL: URL
    @Published var status: PluginStatus = .untested

    // Audio Unit specific
    var audioComponentDescription: AudioComponentDescription?

    init(name: String, manufacturer: String, type: PluginType, fileURL: URL, componentDescription: AudioComponentDescription? = nil) {
        self.name = name
        self.manufacturer = manufacturer
        self.type = type
        self.fileURL = fileURL
        self.audioComponentDescription = componentDescription
    }

    var isDisabled: Bool { status == .disabled }
    var canTest: Bool { status != .testing && status != .disabled }

    var subtypeString: String? {
        guard let desc = audioComponentDescription else { return nil }
        return fourCCToString(desc.componentSubType)
    }

    var manufacturerCodeString: String? {
        guard let desc = audioComponentDescription else { return nil }
        return fourCCToString(desc.componentManufacturer)
    }

    private func fourCCToString(_ value: OSType) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
        return String(bytes: bytes, encoding: .utf8)?.trimmingCharacters(in: .whitespaces) ?? String(format: "%08X", value)
    }
}
