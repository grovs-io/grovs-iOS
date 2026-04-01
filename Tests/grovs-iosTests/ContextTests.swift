import XCTest
@testable import Grovs

final class ContextTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Context.reset()
    }

    override func tearDown() {
        Context.reset()
        super.tearDown()
    }

    // MARK: - Basic get/set

    func testIdentifierStartsNil() {
        XCTAssertNil(Context.identifier)
    }

    func testSetAndGetIdentifier() {
        Context.identifier = "user-123"
        XCTAssertEqual(Context.identifier, "user-123")
    }

    func testSetAndGetAttributes() {
        let attrs: [String: Any] = ["plan": "pro", "count": 42]
        Context.attributes = attrs
        XCTAssertEqual(Context.attributes?["plan"] as? String, "pro")
        XCTAssertEqual(Context.attributes?["count"] as? Int, 42)
    }

    func testSetAndGetUserAgent() {
        Context.userAgent = "Mozilla/5.0"
        XCTAssertEqual(Context.userAgent, "Mozilla/5.0")
    }

    func testSetAndGetPushToken() {
        Context.pushToken = "abc-token"
        XCTAssertEqual(Context.pushToken, "abc-token")
    }

    // MARK: - Reset

    func testResetClearsAllProperties() {
        Context.identifier = "user-123"
        Context.attributes = ["key": "value"]
        Context.userAgent = "agent"
        Context.pushToken = "token"

        Context.reset()

        XCTAssertNil(Context.identifier)
        XCTAssertNil(Context.attributes)
        XCTAssertNil(Context.userAgent)
        XCTAssertNil(Context.pushToken)
    }

    // MARK: - Concurrent access

    func testConcurrentReadWriteDoesNotCrash() {
        let iterations = 1000
        let queue = DispatchQueue(label: "context-test", attributes: .concurrent)
        let group = DispatchGroup()

        for i in 0..<iterations {
            group.enter()
            queue.async {
                Context.identifier = "id-\(i)"
                Context.attributes = ["i": i, "data": Array(repeating: "x", count: 10)]
                Context.userAgent = "agent-\(i)"
                Context.pushToken = "token-\(i)"
                group.leave()
            }

            group.enter()
            queue.async {
                _ = Context.identifier
                _ = Context.attributes
                _ = Context.userAgent
                _ = Context.pushToken
                group.leave()
            }

            group.enter()
            queue.async {
                Context.reset()
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success, "Concurrent access timed out")
    }

    func testConcurrentAttributesDictionaryAccess() {
        let iterations = 500
        let queue = DispatchQueue(label: "context-attrs-test", attributes: .concurrent)
        let group = DispatchGroup()

        for i in 0..<iterations {
            group.enter()
            queue.async {
                Context.attributes = [
                    "string": "value-\(i)",
                    "number": i,
                    "array": [1, 2, 3],
                    "nested": ["key": "val"]
                ]
                group.leave()
            }

            group.enter()
            queue.async {
                if let attrs = Context.attributes {
                    _ = attrs["string"]
                    _ = attrs["number"]
                    _ = attrs.count
                }
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success, "Concurrent dictionary access timed out")
    }
}
