import XCTest
@testable import Grovs

final class AppDetailsTests: XCTestCase {

    // MARK: - toBackend() key mapping

    func testToBackendMapsAllFieldsCorrectly() {
        let details = AppDetails(
            version: "1.0",
            build: "42",
            bundle: "com.app.test",
            device: "iPhone15,2",
            deviceID: "VENDOR-UUID",
            userAgent: "TestAgent/1.0",
            screenWidth: 390,
            screenHeight: 844,
            language: "en",
            timeZone: "America/New_York"
        )

        let dict = details.toBackend()

        XCTAssertEqual(dict["user_agent"] as? String, "TestAgent/1.0")
        XCTAssertEqual(dict["vendor_id"] as? String, "VENDOR-UUID")
        XCTAssertEqual(dict["app_version"] as? String, "1.0")
        XCTAssertEqual(dict["build"] as? String, "42")
        XCTAssertEqual(dict["device"] as? String, "iPhone15,2")
        XCTAssertEqual(dict["timezone"] as? String, "America/New_York")
        XCTAssertEqual(dict["language"] as? String, "en")
        XCTAssertEqual(dict["screen_width"] as? Int, 390)
        XCTAssertEqual(dict["screen_height"] as? Int, 844)
    }

    func testToBackendWithNilOptionals() {
        let details = AppDetails(
            version: "2.0",
            build: "1",
            bundle: "com.app",
            device: "iPad",
            deviceID: "ID",
            userAgent: "Agent",
            screenWidth: nil,
            screenHeight: nil,
            language: nil,
            timeZone: nil
        )

        let dict = details.toBackend()

        XCTAssertEqual(dict["app_version"] as? String, "2.0")

        assertValueIsNil(dict, key: "screen_width")
        assertValueIsNil(dict, key: "screen_height")
        assertValueIsNil(dict, key: "language")
        assertValueIsNil(dict, key: "timezone")
    }

    func testToBackendDoesNotIncludeBundle() {
        let details = AppDetails(
            version: "1.0",
            build: "1",
            bundle: "com.app.test",
            device: "iPhone",
            deviceID: "ID",
            userAgent: "Agent",
            screenWidth: 375,
            screenHeight: 812,
            language: "en",
            timeZone: "UTC"
        )

        let dict = details.toBackend()

        XCTAssertNil(dict["bundle"], "bundle should not be in backend representation")
    }

    // MARK: - Boundary values

    func testToBackendWithEmptyStrings() {
        let details = AppDetails(
            version: "",
            build: "",
            bundle: "",
            device: "",
            deviceID: "",
            userAgent: "",
            screenWidth: 0,
            screenHeight: 0,
            language: "",
            timeZone: ""
        )

        let dict = details.toBackend()

        XCTAssertEqual(dict["app_version"] as? String, "")
        XCTAssertEqual(dict["build"] as? String, "")
        XCTAssertEqual(dict["user_agent"] as? String, "")
        XCTAssertEqual(dict["vendor_id"] as? String, "")
        XCTAssertEqual(dict["device"] as? String, "")
        XCTAssertEqual(dict["screen_width"] as? Int, 0)
        XCTAssertEqual(dict["screen_height"] as? Int, 0)
        XCTAssertEqual(dict["language"] as? String, "")
        XCTAssertEqual(dict["timezone"] as? String, "")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesAllFields() throws {
        let original = AppDetails(
            version: "3.0",
            build: "99",
            bundle: "com.test",
            device: "iPhone",
            deviceID: "DEVICE-ID",
            userAgent: "Safari",
            screenWidth: 375,
            screenHeight: 812,
            language: "fr",
            timeZone: "Europe/Paris"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppDetails.self, from: data)

        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.build, original.build)
        XCTAssertEqual(decoded.bundle, original.bundle)
        XCTAssertEqual(decoded.device, original.device)
        XCTAssertEqual(decoded.deviceID, original.deviceID)
        XCTAssertEqual(decoded.userAgent, original.userAgent)
        XCTAssertEqual(decoded.screenWidth, original.screenWidth)
        XCTAssertEqual(decoded.screenHeight, original.screenHeight)
        XCTAssertEqual(decoded.language, original.language)
        XCTAssertEqual(decoded.timeZone, original.timeZone)
    }

    func testCodableRoundTripWithNilOptionals() throws {
        let original = AppDetails(
            version: "1.0",
            build: "1",
            bundle: "com.app",
            device: "iPhone",
            deviceID: "ID",
            userAgent: "Agent",
            screenWidth: nil,
            screenHeight: nil,
            language: nil,
            timeZone: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppDetails.self, from: data)

        XCTAssertNil(decoded.screenWidth)
        XCTAssertNil(decoded.screenHeight)
        XCTAssertNil(decoded.language)
        XCTAssertNil(decoded.timeZone)
    }
}
