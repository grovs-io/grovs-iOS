import XCTest
@testable import Grovs

final class DictionaryExtensionTests: XCTestCase {

    // MARK: - dictToData

    func testDictToDataRoundTrip() {
        let dict: [String: Any] = ["key": "value", "number": 42]
        guard let data = dict.dictToData() else {
            XCTFail("dictToData should succeed for a valid dictionary")
            return
        }

        let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(decoded?["key"] as? String, "value")
        XCTAssertEqual(decoded?["number"] as? Int, 42)
    }

    func testDictToDataWithNestedDictionary() {
        let dict: [String: Any] = ["outer": ["inner": "value"]]
        guard let data = dict.dictToData() else {
            XCTFail("dictToData should handle nested dictionaries")
            return
        }

        let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let nested = decoded?["outer"] as? [String: Any]
        XCTAssertEqual(nested?["inner"] as? String, "value")
    }

    func testDictToDataWithEmptyDictionary() {
        let dict: [String: Any] = [:]
        let data = dict.dictToData()
        XCTAssertNotNil(data, "dictToData should succeed for empty dictionary")
    }

    // MARK: - toString

    func testToStringReturnsValidJSON() {
        let dict: [String: Any] = ["hello": "world"]
        let string = dict.toString()
        XCTAssertFalse(string.isEmpty)

        // Verify it's valid JSON
        guard let data = string.data(using: .utf8) else {
            XCTFail("toString output should be valid UTF-8")
            return
        }
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(parsed?["hello"] as? String, "world")
    }

    func testToStringWithEmptyDictionary() {
        let dict: [String: Any] = [:]
        let string = dict.toString()
        XCTAssertFalse(string.isEmpty, "Empty dict should produce non-empty JSON string")

        let data = string.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertTrue(parsed?.isEmpty ?? false)
    }
}
