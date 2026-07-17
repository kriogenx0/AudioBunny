import XCTest
@testable import AudioBunny

final class VST2ProbeCacheTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AudioBunnyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeBundle(executableName: String = "Test") throws -> URL {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Test.vst")
        let contentsURL = bundleURL.appendingPathComponent("Contents")
        let macOSURL = contentsURL.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.example.test.vst", // no Synth/FX convention match
            "CFBundleExecutable": executableName,
            "CFBundlePackageType": "BNDL"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        // A real (tiny) executable file so Bundle(url:).executableURL resolves.
        FileManager.default.createFile(atPath: macOSURL.appendingPathComponent(executableName).path, contents: Data())
        return bundleURL
    }

    func testReturnsCachedInstrumentWithoutReprobing() throws {
        let url = try makeBundle()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let executablePath = url.appendingPathComponent("Contents/MacOS/Test").path

        defaults.set(["\(executablePath)": "instrument"], forKey: "audiobunny.vst2ProbeCache")

        XCTAssertEqual(categoryFromVST2Probe(url, userDefaults: defaults), .instrument)
    }

    func testReturnsCachedEffectWithoutReprobing() throws {
        let url = try makeBundle()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let executablePath = url.appendingPathComponent("Contents/MacOS/Test").path

        defaults.set(["\(executablePath)": "effect"], forKey: "audiobunny.vst2ProbeCache")

        XCTAssertEqual(categoryFromVST2Probe(url, userDefaults: defaults), .effect)
    }

    func testReturnsNilForCachedUnknownWithoutReprobing() throws {
        let url = try makeBundle()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let executablePath = url.appendingPathComponent("Contents/MacOS/Test").path

        defaults.set(["\(executablePath)": "unknown"], forKey: "audiobunny.vst2ProbeCache")

        XCTAssertNil(categoryFromVST2Probe(url, userDefaults: defaults))
    }

    /// With no cache entry and (in this test environment) no VST2Prober helper
    /// next to the test runner's executable, the probe can't run at all — this
    /// exercises the "no prober found" path and confirms it fails safe (nil),
    /// without asserting anything about a real probe outcome.
    func testUncachedWithNoProberAvailableReturnsNilGracefully() throws {
        let url = try makeBundle()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertNil(categoryFromVST2Probe(url, userDefaults: defaults))
    }
}
