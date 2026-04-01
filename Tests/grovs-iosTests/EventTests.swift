import XCTest
@testable import Grovs

final class EventTests: XCTestCase {

    // MARK: - Initialization

    func testInitWithAllProperties() {
        let date = Date()
        let event = Event(type: .timeSpent, createdAt: date, link: "https://test.com", engagementTime: 60)

        XCTAssertEqual(event.type, .timeSpent)
        XCTAssertEqual(event.createdAt, date)
        XCTAssertEqual(event.link, "https://test.com")
        XCTAssertEqual(event.engagementTime, 60)
    }

    // MARK: - NSCoding Round-Trip

    func testNSCodingRoundTripPreservesAllFields() throws {
        let event = Event(type: .timeSpent, createdAt: Date(), link: "https://test.com", engagementTime: 120)

        let data = try NSKeyedArchiver.archivedData(withRootObject: event, requiringSecureCoding: false)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchiveObject(with: data) as? Event)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.type, event.type)
        XCTAssertEqual(decoded.link, event.link)
        XCTAssertEqual(decoded.engagementTime, event.engagementTime)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, event.createdAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func testNSCodingRoundTripWithNilOptionals() throws {
        let event = Event(type: .install, createdAt: Date())

        let data = try NSKeyedArchiver.archivedData(withRootObject: event, requiringSecureCoding: false)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchiveObject(with: data) as? Event)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertNil(decoded.link)
        XCTAssertNil(decoded.engagementTime)
    }

    func testNSCodingIDPersistsAcrossRoundTrips() throws {
        let event = Event(type: .appOpen, createdAt: Date(), link: "https://old.com")
        let originalID = event.id

        // First round-trip
        let data1 = try NSKeyedArchiver.archivedData(withRootObject: event, requiringSecureCoding: false)
        let decoded1 = try XCTUnwrap(NSKeyedUnarchiver.unarchiveObject(with: data1) as? Event)
        XCTAssertEqual(decoded1.id, originalID)

        // Second round-trip from decoded event
        let data2 = try NSKeyedArchiver.archivedData(withRootObject: decoded1, requiringSecureCoding: false)
        let decoded2 = try XCTUnwrap(NSKeyedUnarchiver.unarchiveObject(with: data2) as? Event)
        XCTAssertEqual(decoded2.id, originalID)
    }

    // MARK: - toBackend

    func testToBackendContainsAllFields() {
        let date = Date()
        let event = Event(type: .install, createdAt: date, link: "https://link.com", engagementTime: 30)

        let dict = event.toBackend()

        XCTAssertEqual(dict["event"] as? String, "install")
        XCTAssertEqual(dict["link"] as? String, "https://link.com")
        XCTAssertEqual(dict["engagement_time"] as? Int, 30)
        XCTAssertEqual(dict["created_at"] as? String, date.backendDateString())
    }

    func testToBackendDoesNotIncludeID() {
        let event = Event(type: .appOpen, createdAt: Date())
        let dict = event.toBackend()

        XCTAssertNil(dict["id"], "Backend payload should not contain the local UUID")
    }

    func testToBackendWithNilOptionals() {
        let event = Event(type: .appOpen, createdAt: Date())
        let dict = event.toBackend()

        XCTAssertEqual(dict["event"] as? String, "app_open")
        XCTAssertNotNil(dict["created_at"])
    }

    // MARK: - NSCoding Backward Compatibility

    func testDecodingEventWithoutUUIDGeneratesNewID() throws {
        // Create an archive that has type and createdAt but no "id" key.
        // We do this by archiving with a custom helper that skips the "id" key.
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode("app_open", forKey: "type")
        archiver.encode(Date(), forKey: "createdAt")
        archiver.finishEncoding()

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        let decoded = Event(coder: unarchiver)

        XCTAssertNotNil(decoded, "Should decode even without UUID")
        XCTAssertNotNil(decoded?.id, "Should generate a new UUID when none was persisted")
        XCTAssertEqual(decoded?.type, .appOpen)
    }

    func testDecodingEventWithCorruptedTypeReturnsNil() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode("totally_invalid_type", forKey: "type")
        archiver.encode(Date(), forKey: "createdAt")
        archiver.finishEncoding()

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        let decoded = Event(coder: unarchiver)

        XCTAssertNil(decoded, "Invalid type string should cause init to return nil")
    }

    func testDecodingEventWithMissingCreatedAtReturnsNil() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode("view", forKey: "type")
        // Deliberately omit "createdAt"
        archiver.finishEncoding()

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        let decoded = Event(coder: unarchiver)

        XCTAssertNil(decoded, "Missing createdAt should cause init to return nil")
    }
}
