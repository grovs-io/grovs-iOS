import XCTest
@testable import Grovs

final class GrovsNotificationTests: XCTestCase {

    // MARK: - Helpers

    /// Uses the same decoder as production code — single source of truth.
    private var decoder: JSONDecoder {
        GrovsNotification.backendDecoder()
    }

    // MARK: - GrovsNotification decoding

    func testDecodeNotificationWithAllFields() throws {
        let json = """
        {
            "id": 42,
            "title": "New Feature",
            "updated_at": "2024-06-15T10:30:00.000+0000",
            "subtitle": "Check it out",
            "auto_display": true,
            "access_url": "https://example.com/feature",
            "read": false
        }
        """.data(using: .utf8)!

        let notification = try decoder.decode(GrovsNotification.self, from: json)

        XCTAssertEqual(notification.id, 42)
        XCTAssertEqual(notification.title, "New Feature")
        XCTAssertEqual(notification.subtitle, "Check it out")
        XCTAssertTrue(notification.autoDisplay)
        XCTAssertEqual(notification.accessURL?.absoluteString, "https://example.com/feature")
        XCTAssertFalse(notification.read)
    }

    func testDecodeNotificationWithNilOptionals() throws {
        let json = """
        {
            "id": 1,
            "title": "Alert",
            "updated_at": "2024-01-01T00:00:00.000+0000",
            "subtitle": null,
            "auto_display": false,
            "access_url": null,
            "read": true
        }
        """.data(using: .utf8)!

        let notification = try decoder.decode(GrovsNotification.self, from: json)

        XCTAssertEqual(notification.id, 1)
        XCTAssertEqual(notification.title, "Alert")
        XCTAssertNil(notification.subtitle)
        XCTAssertFalse(notification.autoDisplay)
        XCTAssertNil(notification.accessURL)
        XCTAssertTrue(notification.read)
    }

    func testDecodeNotificationWithMissingOptionals() throws {
        // subtitle and access_url omitted entirely (vs null)
        let json = """
        {
            "id": 5,
            "title": "Minimal",
            "updated_at": "2024-03-10T12:00:00.000+0000",
            "auto_display": false,
            "read": false
        }
        """.data(using: .utf8)!

        let notification = try decoder.decode(GrovsNotification.self, from: json)

        XCTAssertEqual(notification.id, 5)
        XCTAssertNil(notification.subtitle)
        XCTAssertNil(notification.accessURL)
    }

    func testDecodeFailsOnMissingRequiredField() {
        // Missing "title" which is required
        let json = """
        {
            "id": 1,
            "updated_at": "2024-01-01T00:00:00.000+0000",
            "auto_display": false,
            "read": false
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(GrovsNotification.self, from: json))
    }

    func testDecodeFailsOnInvalidDateFormat() {
        let json = """
        {
            "id": 1,
            "title": "Bad Date",
            "updated_at": "June 15, 2024",
            "auto_display": false,
            "read": false
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(GrovsNotification.self, from: json))
    }

    // MARK: - GrovsNotificationsResponse decoding

    func testDecodeNotificationsResponse() throws {
        let json = """
        {
            "notifications": [
                {
                    "id": 1,
                    "title": "First",
                    "updated_at": "2024-01-01T00:00:00.000+0000",
                    "auto_display": true,
                    "read": false
                },
                {
                    "id": 2,
                    "title": "Second",
                    "updated_at": "2024-02-01T00:00:00.000+0000",
                    "subtitle": "Sub",
                    "auto_display": false,
                    "read": true
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(GrovsNotificationsResponse.self, from: json)

        XCTAssertEqual(response.notifications.count, 2)
        XCTAssertEqual(response.notifications[0].id, 1)
        XCTAssertEqual(response.notifications[1].title, "Second")
    }

    func testDecodeEmptyNotificationsResponse() throws {
        let json = """
        { "notifications": [] }
        """.data(using: .utf8)!

        let response = try decoder.decode(GrovsNotificationsResponse.self, from: json)
        XCTAssertTrue(response.notifications.isEmpty)
    }

    // MARK: - Codable round-trip

    func testEncodeThenDecodePreservesAllFields() throws {
        let json = """
        {
            "id": 99,
            "title": "Round Trip",
            "updated_at": "2024-06-15T10:30:00.000+0000",
            "subtitle": "Sub",
            "auto_display": true,
            "access_url": "https://example.com",
            "read": false
        }
        """.data(using: .utf8)!

        let original = try decoder.decode(GrovsNotification.self, from: json)
        let encoded = try GrovsNotification.backendEncoder().encode(original)
        let decoded = try decoder.decode(GrovsNotification.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.subtitle, original.subtitle)
        XCTAssertEqual(decoded.autoDisplay, original.autoDisplay)
        XCTAssertEqual(decoded.accessURL, original.accessURL)
        XCTAssertEqual(decoded.read, original.read)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970,
                       original.updatedAt.timeIntervalSince1970, accuracy: 0.001)
    }
}
