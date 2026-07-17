import XCTest
@testable import AudioBunny

final class AbletonProjectParsingTests: XCTestCase {
    private func makeGzippedAlsFile(named name: String, xml: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let xmlURL = dir.appendingPathComponent("\(name).xml")
        try xml.write(to: xmlURL, atomically: true, encoding: .utf8)

        let alsURL = dir.appendingPathComponent("\(name).als")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = ["-c", xmlURL.path]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        try process.run()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try data.write(to: alsURL)
        return alsURL
    }

    func testParsesAllThreePluginTypes() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Ableton>
          <LiveSet>
            <VstPluginInfo>
              <PlugName Value="Massive"/>
              <Manufacturer Value="Native Instruments"/>
            </VstPluginInfo>
            <Vst3PluginInfo>
              <Name Value="Serum"/>
              <Vendor Value="Xfer Records"/>
            </Vst3PluginInfo>
            <AuPluginInfo>
              <Name Value="AUSampler"/>
              <Manufacturer Value="Apple"/>
            </AuPluginInfo>
          </LiveSet>
        </Ableton>
        """
        let url = try makeGzippedAlsFile(named: "MyTrack", xml: xml)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let project = try parseAbletonProject(at: url)

        XCTAssertEqual(project.name, "MyTrack")
        XCTAssertEqual(project.plugins.count, 3)

        XCTAssertTrue(project.plugins.contains {
            $0.name == "Massive" && $0.manufacturer == "Native Instruments" && $0.type == .vst2
        })
        XCTAssertTrue(project.plugins.contains {
            $0.name == "Serum" && $0.manufacturer == "Xfer Records" && $0.type == .vst3
        })
        XCTAssertTrue(project.plugins.contains {
            $0.name == "AUSampler" && $0.manufacturer == "Apple" && $0.type == .audioUnit
        })
    }

    func testDeduplicatesSamePluginListedTwice() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Ableton>
          <LiveSet>
            <Vst3PluginInfo>
              <Name Value="Serum"/>
              <Vendor Value="Xfer Records"/>
            </Vst3PluginInfo>
            <Vst3PluginInfo>
              <Name Value="Serum"/>
              <Vendor Value="Xfer Records"/>
            </Vst3PluginInfo>
          </LiveSet>
        </Ableton>
        """
        let url = try makeGzippedAlsFile(named: "DupeTrack", xml: xml)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let project = try parseAbletonProject(at: url)
        XCTAssertEqual(project.plugins.count, 1)
    }

    func testNoPluginsYieldsEmptyList() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Ableton><LiveSet></LiveSet></Ableton>
        """
        let url = try makeGzippedAlsFile(named: "EmptyTrack", xml: xml)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let project = try parseAbletonProject(at: url)
        XCTAssertTrue(project.plugins.isEmpty)
    }
}
