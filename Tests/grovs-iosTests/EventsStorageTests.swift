import XCTest
@testable import Grovs

final class EventsStorageTests: XCTestCase {

    private var eventsCachePath: String {
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        return (appSupport as NSString).appendingPathComponent("com.grovs.cache.grovs-events-cache")
    }

    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(atPath: eventsCachePath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: eventsCachePath)
        super.tearDown()
    }

    // MARK: - Deduplication Logic

    func testRemoveDuplicateEventsKeepsLatestInstall() {
        let storage = EventsStorage()
        let old = Event(type: .install, createdAt: Date(timeIntervalSinceNow: -100))
        let new = Event(type: .install, createdAt: Date())
        let appOpen = Event(type: .appOpen, createdAt: Date())

        let result = storage.removeDuplicateEventsIfNeeded(events: [old, appOpen, new])

        let installs = result.filter { $0.type == .install }
        XCTAssertEqual(installs.count, 1)
        XCTAssertEqual(installs.first?.id, new.id)
        XCTAssertTrue(result.contains(where: { $0.id == appOpen.id }))
    }

    func testRemoveDuplicateEventsRemovesReinstallWhenInstallExists() {
        let storage = EventsStorage()
        let install = Event(type: .install, createdAt: Date())
        let reinstall = Event(type: .reinstall, createdAt: Date())

        let result = storage.removeDuplicateEventsIfNeeded(events: [install, reinstall])

        XCTAssertEqual(result.filter { $0.type == .install }.count, 1)
        XCTAssertEqual(result.filter { $0.type == .reinstall }.count, 0)
    }

    func testRemoveDuplicateEventsKeepsLatestReinstallWhenNoInstall() {
        let storage = EventsStorage()
        let old = Event(type: .reinstall, createdAt: Date(timeIntervalSinceNow: -100))
        let new = Event(type: .reinstall, createdAt: Date())

        let result = storage.removeDuplicateEventsIfNeeded(events: [old, new])

        let reinstalls = result.filter { $0.type == .reinstall }
        XCTAssertEqual(reinstalls.count, 1)
        XCTAssertEqual(reinstalls.first?.id, new.id)
    }

    func testRemoveDuplicateEventsPreservesNonInstallEvents() {
        let storage = EventsStorage()
        let appOpen = Event(type: .appOpen, createdAt: Date())
        let view = Event(type: .view, createdAt: Date())
        let timeSpent = Event(type: .timeSpent, createdAt: Date())

        let result = storage.removeDuplicateEventsIfNeeded(events: [appOpen, view, timeSpent])

        XCTAssertEqual(result.count, 3)
    }

    func testRemoveDuplicateEventsWithEmptyArray() {
        let storage = EventsStorage()
        let result = storage.removeDuplicateEventsIfNeeded(events: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testRemoveDuplicateEventsWithSingleInstall() {
        let storage = EventsStorage()
        let install = Event(type: .install, createdAt: Date())

        let result = storage.removeDuplicateEventsIfNeeded(events: [install])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, install.id)
    }

    // MARK: - Storage: Add & Retrieve

    func testAddAndRetrieveEvent() {
        let storage = EventsStorage()
        let event = Event(type: .appOpen, createdAt: Date(), link: "https://test.com")

        let addExp = expectation(description: "add")
        storage.addEvent(event: event) { addExp.fulfill() }
        wait(for: [addExp], timeout: 10)

        let getExp = expectation(description: "get")
        storage.getEvents { events in
            let found = events?.contains(where: { $0.id == event.id }) ?? false
            XCTAssertTrue(found, "Added event should be retrievable")
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }

    func testTwoEventsAtSameTimestampAreBothStored() {
        let storage = EventsStorage()
        let now = Date()
        let event1 = Event(type: .appOpen, createdAt: now, link: "link1")
        let event2 = Event(type: .view, createdAt: now, link: "link2")

        let addExp = expectation(description: "add events")
        storage.addEvent(event: event1) {
            storage.addEvent(event: event2) {
                addExp.fulfill()
            }
        }
        wait(for: [addExp], timeout: 10)

        let getExp = expectation(description: "get events")
        storage.getEvents { events in
            let ours = events?.filter { $0.id == event1.id || $0.id == event2.id } ?? []
            XCTAssertEqual(ours.count, 2, "Both events at the same timestamp should be stored")
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }

    // MARK: - Storage: Remove

    func testRemoveEventByID() {
        let storage = EventsStorage()
        let event1 = Event(type: .appOpen, createdAt: Date())
        let event2 = Event(type: .view, createdAt: Date())

        let addExp = expectation(description: "add")
        storage.addEvent(event: event1) {
            storage.addEvent(event: event2) {
                addExp.fulfill()
            }
        }
        wait(for: [addExp], timeout: 10)

        let removeExp = expectation(description: "remove")
        storage.removeEvent(event: event1) {
            removeExp.fulfill()
        }
        wait(for: [removeExp], timeout: 10)

        let getExp = expectation(description: "get")
        storage.getEvents { events in
            let hasEvent1 = events?.contains(where: { $0.id == event1.id }) ?? false
            let hasEvent2 = events?.contains(where: { $0.id == event2.id }) ?? false
            XCTAssertFalse(hasEvent1, "event1 should have been removed")
            XCTAssertTrue(hasEvent2, "event2 should still exist")
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }

    func testRemoveNonExistentEventDoesNotCrash() {
        let storage = EventsStorage()
        let event = Event(type: .appOpen, createdAt: Date())

        let removeExp = expectation(description: "remove")
        storage.removeEvent(event: event) {
            removeExp.fulfill()
        }
        wait(for: [removeExp], timeout: 10)
    }

    // MARK: - Storage: Add or Replace

    func testAddOrReplaceUpdatesExistingEventByID() {
        let storage = EventsStorage()
        let event = Event(type: .timeSpent, createdAt: Date())

        let addExp = expectation(description: "add")
        storage.addEvent(event: event) { addExp.fulfill() }
        wait(for: [addExp], timeout: 10)

        event.engagementTime = 99
        let replaceExp = expectation(description: "replace")
        storage.addOrReplaceEvents(events: [event]) { replaceExp.fulfill() }
        wait(for: [replaceExp], timeout: 10)

        let getExp = expectation(description: "get")
        storage.getEvents { events in
            let matching = events?.filter { $0.id == event.id } ?? []
            XCTAssertEqual(matching.count, 1, "Should have exactly one event with this ID")
            XCTAssertEqual(matching.first?.engagementTime, 99)
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }

    // MARK: - transformEvents

    func testTransformEventsModifiesInPlace() {
        let storage = EventsStorage()
        let event = Event(type: .timeSpent, createdAt: Date())

        let addExp = expectation(description: "add")
        storage.addEvent(event: event) { addExp.fulfill() }
        wait(for: [addExp], timeout: 10)

        let transformExp = expectation(description: "transform")
        storage.transformEvents({ e in
            e.engagementTime = 55
            return e
        }) { transformExp.fulfill() }
        wait(for: [transformExp], timeout: 10)

        let getExp = expectation(description: "get")
        storage.getEvents { events in
            XCTAssertEqual(events?.first(where: { $0.id == event.id })?.engagementTime, 55)
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }

    func testTransformEventsDoesNotResurrectDeletedEvents() {
        let storage = EventsStorage()
        let event1 = Event(type: .timeSpent, createdAt: Date())
        let event2 = Event(type: .view, createdAt: Date())

        // Add both events
        let addExp = expectation(description: "add both")
        storage.addEvent(event: event1) {
            storage.addEvent(event: event2) {
                addExp.fulfill()
            }
        }
        wait(for: [addExp], timeout: 10)

        // Remove event1, then transform. Both go through the serial queue
        // so the remove completes before the transform reads.
        let removeExp = expectation(description: "remove")
        storage.removeEvent(event: event1) { removeExp.fulfill() }

        let transformExp = expectation(description: "transform")
        storage.transformEvents({ e in
            e.link = "patched"
            return e
        }) { transformExp.fulfill() }
        wait(for: [removeExp, transformExp], timeout: 10, enforceOrder: true)

        let getExp = expectation(description: "get")
        storage.getEvents { events in
            let hasEvent1 = events?.contains(where: { $0.id == event1.id }) ?? false
            let hasEvent2 = events?.contains(where: { $0.id == event2.id }) ?? false
            XCTAssertFalse(hasEvent1, "Deleted event must not be resurrected by transformEvents")
            XCTAssertTrue(hasEvent2, "Surviving event should still exist with patch")
            XCTAssertEqual(events?.first(where: { $0.id == event2.id })?.link, "patched")
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }

    // MARK: - Corrupt Data Recovery

    func testGetEventsWithCorruptedCacheReturnsNil() {
        // Write garbage to the cache file used by EventsStorage
        let cachePath = eventsCachePath
        try? FileManager.default.createDirectory(atPath: cachePath, withIntermediateDirectories: true)
        let filePath = (cachePath as NSString).appendingPathComponent("cached-events".md5)
        FileManager.default.createFile(atPath: filePath, contents: Data([0xFF, 0xDE, 0xAD]))

        let storage = EventsStorage()
        let exp = expectation(description: "get")
        storage.getEvents { events in
            XCTAssertNil(events, "Corrupted cache should return nil, not crash")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)
    }

    func testAddEventAfterCorruptedCacheRecoversByOverwriting() {
        // Write garbage to cache
        let cachePath = eventsCachePath
        try? FileManager.default.createDirectory(atPath: cachePath, withIntermediateDirectories: true)
        let filePath = (cachePath as NSString).appendingPathComponent("cached-events".md5)
        FileManager.default.createFile(atPath: filePath, contents: Data([0xFF, 0xDE, 0xAD]))

        let storage = EventsStorage()
        let event = Event(type: .appOpen, createdAt: Date())

        let addExp = expectation(description: "add")
        storage.addEvent(event: event) { addExp.fulfill() }
        wait(for: [addExp], timeout: 10)

        let getExp = expectation(description: "get")
        storage.getEvents { events in
            let found = events?.contains(where: { $0.id == event.id }) ?? false
            XCTAssertTrue(found, "New event should be retrievable after overwriting corrupted cache")
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }

    // MARK: - Concurrency

    func testConcurrentAddAndGetDoesNotCrashOrLoseData() {
        let storage = EventsStorage()
        let count = 20
        var events: [Event] = []
        for _ in 0..<count {
            events.append(Event(type: .appOpen, createdAt: Date()))
        }

        // Add all events concurrently (each goes through the serial queue inside storage)
        let addGroup = DispatchGroup()
        for event in events {
            addGroup.enter()
            DispatchQueue.global().async {
                storage.addEvent(event: event) { addGroup.leave() }
            }
        }
        let addResult = addGroup.wait(timeout: .now() + 15)
        XCTAssertEqual(addResult, .success, "All concurrent adds should complete")

        // Verify all events are stored
        let getExp = expectation(description: "get")
        storage.getEvents { stored in
            let storedIDs = Set(stored?.map { $0.id } ?? [])
            for event in events {
                XCTAssertTrue(storedIDs.contains(event.id), "Event \(event.id) should survive concurrent add")
            }
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }

    func testConcurrentAddAndRemoveDoesNotCrash() {
        let storage = EventsStorage()
        let event1 = Event(type: .appOpen, createdAt: Date())
        let event2 = Event(type: .view, createdAt: Date())

        // Add both first
        let setupExp = expectation(description: "setup")
        storage.addEvent(event: event1) {
            storage.addEvent(event: event2) { setupExp.fulfill() }
        }
        wait(for: [setupExp], timeout: 10)

        // Concurrently: remove event1, add event3, transform all
        let event3 = Event(type: .timeSpent, createdAt: Date())
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            storage.removeEvent(event: event1) { group.leave() }
        }
        group.enter()
        DispatchQueue.global().async {
            storage.addEvent(event: event3) { group.leave() }
        }
        group.enter()
        DispatchQueue.global().async {
            storage.transformEvents({ e in
                e.link = "transformed"
                return e
            }) { group.leave() }
        }

        let result = group.wait(timeout: .now() + 15)
        XCTAssertEqual(result, .success, "Concurrent operations should all complete")
    }

    // MARK: - Add or Replace (new ID)

    func testAddOrReplaceAddsNewEventWhenIDNotFound() {
        let storage = EventsStorage()
        let existing = Event(type: .appOpen, createdAt: Date())
        let new = Event(type: .view, createdAt: Date())

        let addExp = expectation(description: "add existing")
        storage.addEvent(event: existing) { addExp.fulfill() }
        wait(for: [addExp], timeout: 10)

        let replaceExp = expectation(description: "add new via replace")
        storage.addOrReplaceEvents(events: [new]) { replaceExp.fulfill() }
        wait(for: [replaceExp], timeout: 10)

        let getExp = expectation(description: "get")
        storage.getEvents { events in
            let hasExisting = events?.contains(where: { $0.id == existing.id }) ?? false
            let hasNew = events?.contains(where: { $0.id == new.id }) ?? false
            XCTAssertTrue(hasExisting)
            XCTAssertTrue(hasNew)
            getExp.fulfill()
        }
        wait(for: [getExp], timeout: 10)
    }
}
