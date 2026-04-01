import XCTest

extension XCTestCase {

    /// Waits for all pending main-queue blocks by enqueuing an expectation at the back of the queue.
    func waitForMainQueue(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: timeout)
    }

    /// Waits for all pending blocks on the given queue by enqueuing an expectation at the back.
    func waitForQueue(_ queue: DispatchQueue, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "queue drained")
        queue.async { exp.fulfill() }
        wait(for: [exp], timeout: timeout)
    }

    /// Asserts that a key exists in the dictionary and its value is a nil Optional
    /// (not just "fails to cast to some type").
    /// Uses Mirror to inspect the actual boxed value inside Any.
    func assertValueIsNil(
        _ dict: [String: Any], key: String,
        file: StaticString = #file, line: UInt = #line
    ) {
        guard let value = dict[key] else {
            XCTFail("Key '\(key)' not found in dictionary", file: file, line: line)
            return
        }
        let mirror = Mirror(reflecting: value)
        let isNil = mirror.displayStyle == .optional && mirror.children.isEmpty
        XCTAssertTrue(isNil,
                      "Value for '\(key)' should be nil, got: \(value)",
                      file: file, line: line)
    }
}
