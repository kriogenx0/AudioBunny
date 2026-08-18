import XCTest
import AudioToolbox
@testable import AudioBunny

final class CategoryDetectionTests: XCTestCase {

    // MARK: - AU component type mapping

    func testMusicDeviceIsInstrument() {
        XCTAssertEqual(categoryForAUComponentType(kAudioUnitType_MusicDevice), .instrument)
    }

    func testGeneratorIsInstrument() {
        XCTAssertEqual(categoryForAUComponentType(kAudioUnitType_Generator), .instrument)
    }

    func testEffectIsEffect() {
        XCTAssertEqual(categoryForAUComponentType(kAudioUnitType_Effect), .effect)
    }

    func testMusicEffectIsEffect() {
        XCTAssertEqual(categoryForAUComponentType(kAudioUnitType_MusicEffect), .effect)
    }

    // MARK: - VST3 moduleinfo.json best-effort detection

    private func makeVST3Bundle(category: String?) throws -> URL {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Test.vst3")
        let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        if let category {
            let json = """
            { "Classes": [ { "Name": "Test", "Category": "\(category)" } ] }
            """
            try json.write(to: resourcesURL.appendingPathComponent("moduleinfo.json"), atomically: true, encoding: .utf8)
        }
        return bundleURL
    }

    func testModuleInfoInstrumentCategory() throws {
        let url = try makeVST3Bundle(category: "Instrument|Synth")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent().deletingLastPathComponent()) }
        XCTAssertEqual(categoryFromVST3ModuleInfo(url), .instrument)
    }

    func testModuleInfoFxCategory() throws {
        let url = try makeVST3Bundle(category: "Fx")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent().deletingLastPathComponent()) }
        XCTAssertEqual(categoryFromVST3ModuleInfo(url), .effect)
    }

    func testMissingModuleInfoReturnsNil() throws {
        let url = try makeVST3Bundle(category: nil)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent().deletingLastPathComponent()) }
        XCTAssertNil(categoryFromVST3ModuleInfo(url))
    }

    // MARK: - Bundle identifier heuristic (VST2, and VST3 fallback)

    private func makeBundle(pathExtension: String, bundleIdentifier: String) throws -> URL {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Test.\(pathExtension)")
        let contentsURL = bundleURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleExecutable": "Test",
            "CFBundlePackageType": "BNDL"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        return bundleURL
    }

    func testBundleIdentifierSynthIsInstrument() throws {
        let url = try makeBundle(pathExtension: "vst", bundleIdentifier: "Absynth 5.Synth.vst")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(categoryFromBundleIdentifier(url), .instrument)
    }

    func testBundleIdentifierFxIsEffect() throws {
        let url = try makeBundle(pathExtension: "vst", bundleIdentifier: "Guitar Rig 6.FX.vst")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(categoryFromBundleIdentifier(url), .effect)
    }

    func testBundleIdentifierWithNoConventionReturnsNil() throws {
        let url = try makeBundle(pathExtension: "vst", bundleIdentifier: "com.roli.EquatorPlugin")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertNil(categoryFromBundleIdentifier(url))
    }

    func testDetectVSTCategoryPrefersModuleInfoForVST3() throws {
        let url = try makeVST3Bundle(category: "Fx")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent().deletingLastPathComponent()) }
        XCTAssertEqual(detectVSTCategory(type: .vst3, bundleURL: url), .effect)
    }

    func testDetectVSTCategoryFallsBackToBundleIdentifierForVST2() throws {
        let url = try makeBundle(pathExtension: "vst", bundleIdentifier: "Battery 4.Synth.vst")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(detectVSTCategory(type: .vst2, bundleURL: url), .instrument)
    }

    // MARK: - Preferred category across merged format variants

    func testPrefersAUCategoryOverVST3() {
        let au = AudioPlugin(name: "X", manufacturer: "M", type: .audioUnit, fileURL: URL(fileURLWithPath: "/tmp/x.component"), category: .effect)
        let vst3 = AudioPlugin(name: "X", manufacturer: "M", type: .vst3, fileURL: URL(fileURLWithPath: "/tmp/x.vst3"), category: .instrument)
        XCTAssertEqual(preferredCategory(for: [vst3, au]), .effect)
    }

    func testFallsBackToAnyNonNilCategoryWithoutAU() {
        let vst3 = AudioPlugin(name: "X", manufacturer: "M", type: .vst3, fileURL: URL(fileURLWithPath: "/tmp/x.vst3"), category: .instrument)
        let vst2 = AudioPlugin(name: "X", manufacturer: "M", type: .vst2, fileURL: URL(fileURLWithPath: "/tmp/x.vst"))
        XCTAssertEqual(preferredCategory(for: [vst2, vst3]), .instrument)
    }

    func testReturnsNilWhenNoCategoryKnown() {
        let vst2 = AudioPlugin(name: "X", manufacturer: "M", type: .vst2, fileURL: URL(fileURLWithPath: "/tmp/x.vst"))
        XCTAssertNil(preferredCategory(for: [vst2]))
    }
}
