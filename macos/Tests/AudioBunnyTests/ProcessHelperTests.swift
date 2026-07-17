import XCTest
@testable import AudioBunny

final class ProcessHelperTests: XCTestCase {
    /// Regression test for a real bug: an earlier version of this helper's logic
    /// called `waitUntilExit()` before draining stdout and sent stderr to an
    /// unread `Pipe()`. Both deadlock once a process's output exceeds the pipe's
    /// kernel buffer (~64KB) — which is exactly what happened testing some
    /// installed VST plugins via `nm`. This generates >64KB of stdout to make
    /// sure that class of bug can't silently come back.
    func testCapturesLargeStdoutWithoutDeadlock() {
        let expectation = expectation(description: "process completes without hanging")
        var resultData: Data?

        DispatchQueue.global().async {
            resultData = runProcessCapturingStdout(
                executable: "/bin/dd",
                arguments: ["if=/dev/zero", "bs=1024", "count=300"]
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(resultData?.count, 300 * 1024)
    }

    func testReturnsDataForSmallOutput() {
        let data = runProcessCapturingStdout(executable: "/bin/echo", arguments: ["hello"])
        XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "hello\n")
    }

    func testReturnsNilForNonexistentExecutable() {
        let data = runProcessCapturingStdout(executable: "/no/such/binary", arguments: [])
        XCTAssertNil(data)
    }

    // MARK: - runProcessWithTimeout

    func testWithTimeoutReturnsDataWhenProcessFinishesInTime() {
        let expectation = expectation(description: "process completes")
        var resultData: Data?

        DispatchQueue.global().async {
            resultData = runProcessWithTimeout(executable: "/bin/echo", arguments: ["hi"], timeoutSeconds: 5)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(resultData.flatMap { String(data: $0, encoding: .utf8) }, "hi\n")
    }

    /// Regression test for the VST2 probing use case: a hung/misbehaving process
    /// must be force-killed and reported as nil, not left to block forever.
    func testWithTimeoutKillsHungProcessAndReturnsNil() {
        let expectation = expectation(description: "timeout returns promptly")
        var resultData: Data?
        var elapsed: TimeInterval = 0

        DispatchQueue.global().async {
            let start = Date()
            resultData = runProcessWithTimeout(executable: "/bin/sleep", arguments: ["30"], timeoutSeconds: 1)
            elapsed = Date().timeIntervalSince(start)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertNil(resultData)
        XCTAssertLessThan(elapsed, 5, "should have been killed at the 1s timeout, not run the full 30s sleep")
    }

    func testWithTimeoutReturnsNilForNonexistentExecutable() {
        let data = runProcessWithTimeout(executable: "/no/such/binary", arguments: [], timeoutSeconds: 5)
        XCTAssertNil(data)
    }
}
