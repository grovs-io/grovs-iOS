import XCTest
@testable import Grovs

final class DebugLoggerTests: XCTestCase {

    private var originalLevel: LogLevel!

    override func setUp() {
        super.setUp()
        originalLevel = DebugLogger.shared.logLevel
    }

    override func tearDown() {
        DebugLogger.shared.logLevel = originalLevel
        super.tearDown()
    }

    // MARK: - Helpers

    /// Captures stdout during the execution of `block` and returns it as a string.
    private func captureStdout(_ block: () -> Void) -> String {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        setvbuf(stdout, nil, _IONBF, 0)  // disable buffering
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        block()

        fflush(stdout)
        dup2(original, STDOUT_FILENO)
        close(original)
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Filtering

    func testInfoMessageFilteredWhenLevelIsError() {
        DebugLogger.shared.logLevel = .error
        let output = captureStdout {
            DebugLogger.shared.log(.info, "should not appear")
        }
        XCTAssertTrue(output.isEmpty, "Info message should be filtered when level is .error, got: \(output)")
    }

    func testWarnMessageFilteredWhenLevelIsError() {
        DebugLogger.shared.logLevel = .error
        let output = captureStdout {
            DebugLogger.shared.log(.warn, "should not appear")
        }
        XCTAssertTrue(output.isEmpty, "Warn message should be filtered when level is .error")
    }

    func testInfoMessagePassesWhenLevelIsInfo() {
        DebugLogger.shared.logLevel = .info
        let output = captureStdout {
            DebugLogger.shared.log(.info, "visible message")
        }
        XCTAssertTrue(output.contains("visible message"), "Info message should pass when level is .info")
    }

    func testWarnMessagePassesWhenLevelIsInfo() {
        DebugLogger.shared.logLevel = .info
        let output = captureStdout {
            DebugLogger.shared.log(.warn, "warn visible")
        }
        XCTAssertTrue(output.contains("warn visible"), "Warn message should pass when level is .info")
    }

    // MARK: - Output format

    func testOutputContainsLevelLabel() {
        DebugLogger.shared.logLevel = .info
        let output = captureStdout {
            DebugLogger.shared.log(.info, "test message")
        }
        XCTAssertTrue(output.contains("GROVS [INFO]"), "Output should contain 'GROVS [INFO]', got: \(output)")
    }

    func testOutputContainsFileAndFunction() {
        DebugLogger.shared.logLevel = .info
        let output = captureStdout {
            DebugLogger.shared.log(.info, "location test")
        }
        // The logger extracts the filename from #file and includes #function
        XCTAssertTrue(output.contains("DebugLoggerTests.swift"), "Output should contain calling file name")
        XCTAssertTrue(output.contains("testOutputContainsFileAndFunction"), "Output should contain calling function")
        XCTAssertTrue(output.contains("[Line"), "Output should contain line number marker")
    }

    func testErrorMessageGetsTripleNewlinePadding() {
        DebugLogger.shared.logLevel = .error
        let output = captureStdout {
            DebugLogger.shared.log(.error, "padded error")
        }
        XCTAssertTrue(output.hasPrefix("\n\n\n"), "Error message should start with triple newline")
        XCTAssertTrue(output.contains("padded error\n\n\n"), "Error message should end with triple newline")
    }

    func testInfoMessageDoesNotGetNewlinePadding() {
        DebugLogger.shared.logLevel = .info
        let output = captureStdout {
            DebugLogger.shared.log(.info, "no padding")
        }
        XCTAssertFalse(output.hasPrefix("\n\n\n"), "Info message should NOT get triple newline padding")
    }

    // MARK: - LogLevel enum

    func testLogLevelComparable() {
        XCTAssertTrue(LogLevel.info < LogLevel.warn)
        XCTAssertTrue(LogLevel.warn < LogLevel.error)
        XCTAssertFalse(LogLevel.error < LogLevel.info)
    }
}
