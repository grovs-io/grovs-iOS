import XCTest
@testable import Grovs

final class EventsHandlerTests: XCTestCase {

    private var mockService: MockAPIService!
    private var mockStorage: MockEventsStorage!
    private var mockDefaults: MockUserDefaultsHelper!
    private var mockKeychain: MockKeychainHelper!

    override func setUp() {
        super.setUp()
        mockService = MockAPIService()
        mockStorage = MockEventsStorage()
        mockDefaults = MockUserDefaultsHelper()
        mockKeychain = MockKeychainHelper()
    }

    override func tearDown() {
        mockService = nil
        mockStorage = nil
        mockDefaults = nil
        mockKeychain = nil
        super.tearDown()
    }

    private func makeHandler() -> EventsHandler {
        return EventsHandler(apiService: mockService, storage: mockStorage, userDefaults: mockDefaults, keychain: mockKeychain)
    }

    /// Creates a handler and resets mock call counts and event results so tests start clean
    /// after init side effects. The handler's init writes to defaults (numberOfOpens,
    /// lastStartTimestamp) and adds events to storage — this method clears that residue.
    ///
    /// **Important:** This resets `addEventResult` back to `true` and call counts to 0.
    /// If your test needs `addEventResult = false` or a specific `completionQueue`,
    /// set them **after** calling this method, not before.
    private func makeCleanHandler() -> EventsHandler {
        let handler = makeHandler()
        // Clear events created by init (install/appOpen/reactivation)
        mockStorage.events.removeAll()
        mockStorage.addEventCallCount = 0
        mockStorage.addOrReplaceCallCount = 0
        mockStorage.removeEventCallCount = 0
        mockStorage.getEventsCallCount = 0
        // Reset service call history and results
        mockService.reset()
        // Reset only call counts — keep store values that the handler wrote during init
        mockDefaults.getIntCallCount = 0
        mockDefaults.setIntCallCount = 0
        mockKeychain.getValueCallCount = 0
        return handler
    }

    // MARK: - log(event:)

    func testLogEventStoresEventInStorage() {
        let handler = makeHandler()
        let event = Event(type: .view, createdAt: Date())

        handler.log(event: event)

        XCTAssertTrue(mockStorage.events.contains(where: { $0.id == event.id }),
                      "Logged event should be in storage")
    }

    func testLogEventAssignsLinkForFutureActionsWhenLinkIsSet() {
        let handler = makeHandler()

        let exp = expectation(description: "link set")
        handler.setLinkToNewFutureActions(link: "https://test-link.com") {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        let event = Event(type: .view, createdAt: Date())
        handler.log(event: event)

        XCTAssertEqual(event.link, "https://test-link.com")
    }

    func testLogEventDoesNotOverwriteExistingLink() {
        let handler = makeHandler()

        let exp = expectation(description: "link set")
        handler.setLinkToNewFutureActions(link: "https://future.com") {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        let event = Event(type: .view, createdAt: Date(), link: "https://original.com")
        handler.log(event: event)

        XCTAssertEqual(event.link, "https://original.com",
                       "Should not overwrite an event's existing link")
    }

    // MARK: - setLinkToNewFutureActions

    func testSetLinkPatchesStoredEventsNilLinks() {
        let handler = makeHandler()

        // Init adds events (appOpen, possibly install). Clear all links so we can test patching.
        for event in mockStorage.events {
            event.link = nil
        }
        let eventsBeforePatch = mockStorage.events.count

        let exp = expectation(description: "link patched")
        handler.setLinkToNewFutureActions(link: "https://patched.com") {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        let patchedEvents = mockStorage.events.filter { $0.link == "https://patched.com" }
        XCTAssertEqual(patchedEvents.count, eventsBeforePatch,
                       "All events with nil links created at or after startup should be patched")
    }

    func testSetLinkDoesNotPatchEventsWithExistingLink() {
        let handler = makeHandler()

        // Give all init events a link
        for event in mockStorage.events {
            event.link = "https://existing.com"
        }

        let exp = expectation(description: "link set")
        handler.setLinkToNewFutureActions(link: "https://new.com") {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        let keptOriginal = mockStorage.events.filter { $0.link == "https://existing.com" }
        XCTAssertEqual(keptOriginal.count, mockStorage.events.count,
                       "Events with existing links should not be overwritten")
    }

    func testSetLinkToNilSetsHasFetchedPayloadLinkAndTriggersEventSending() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true

        let event = Event(type: .view, createdAt: Date(), link: "https://link.com")
        mockStorage.events.append(event)

        let exp = expectation(description: "nil link triggers send")
        handler.setLinkToNewFutureActions(link: nil) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 1,
                       "Setting nil link should trigger sending exactly 1 event")
        XCTAssertEqual(mockService.allAddedEvents.first?.id, event.id,
                       "The sent event should be the one in storage")
    }

    // MARK: - Event sending (via handleEventsIfNeeded directly)

    func testHandleEventsIfNeededSendsWhenConditionsMet() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let event = Event(type: .view, createdAt: Date(), link: "https://link.com")
        mockStorage.events.append(event)

        let exp = expectation(description: "events sent")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 1)
        XCTAssertFalse(mockStorage.events.contains(where: { $0.id == event.id }),
                       "Event should be removed from storage after successful send")
    }

    func testHandleEventsIfNeededKeepsEventsOnFailure() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let event = Event(type: .view, createdAt: Date(), link: "https://link.com")
        mockStorage.events.append(event)
        mockService.addEventResult = false

        let exp = expectation(description: "events send failed")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertTrue(mockStorage.events.contains(where: { $0.id == event.id }),
                      "Event should remain in storage after failed send")
        XCTAssertEqual(mockService.addEventCallCount, 1,
                       "API should still have been called once")
    }

    func testHandleEventsIfNeededSendsEachNonTimeSpentEvent() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let event1 = Event(type: .view, createdAt: Date(), link: "https://l.com")
        let event2 = Event(type: .open, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(contentsOf: [event1, event2])

        let exp = expectation(description: "events sent")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 2,
                       "API should be called once per non-timeSpent event")
        let sentIDs = Set(mockService.allAddedEvents.map { $0.id })
        XCTAssertTrue(sentIDs.contains(event1.id), "event1 should have been sent")
        XCTAssertTrue(sentIDs.contains(event2.id), "event2 should have been sent")
        XCTAssertTrue(mockStorage.events.isEmpty, "All events should be removed after success")
    }

    func testHandleEventsIfNeededSkipsTimeSpentEvents() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let normalEvent = Event(type: .view, createdAt: Date(), link: "https://l.com")
        let timeSpentEvent = Event(type: .timeSpent, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(contentsOf: [normalEvent, timeSpentEvent])

        let exp = expectation(description: "events sent")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 1,
                       "Only the non-timeSpent event should be sent")
        XCTAssertEqual(mockService.allAddedEvents.first?.id, normalEvent.id)
        XCTAssertTrue(mockStorage.events.contains(where: { $0.id == timeSpentEvent.id }),
                      "timeSpent event should remain in storage")
    }

    func testHandleEventsIfNeededDoesNotSendWithoutPayloadLink() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        // hasFetchedPayloadLink is false by default

        mockStorage.events.append(Event(type: .view, createdAt: Date(), link: "https://l.com"))

        let exp = expectation(description: "completion")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 0,
                       "Should not send when hasFetchedPayloadLink is false")
    }

    func testHandleEventsIfNeededDoesNotSendWithoutDelegatesOrLeeway() {
        let handler = makeCleanHandler()
        handler.hasFetchedPayloadLink = true
        // handledAppOrSceneDelegates = false (default), leeway not passed

        mockStorage.events.append(Event(type: .view, createdAt: Date(), link: "https://l.com"))

        let exp = expectation(description: "completion")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 0,
                       "Should not send when handledAppOrSceneDelegates is false and leeway not passed")
    }

    // MARK: - handledAppOrSceneDelegates didSet

    func testSettingHandledAppOrSceneDelegatesTriggersSendWhenReady() {
        let handler = makeCleanHandler()
        handler.hasFetchedPayloadLink = true

        let event = Event(type: .view, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(event)

        // Events not sent yet (handledAppOrSceneDelegates is false, leeway not passed)
        XCTAssertEqual(mockService.addEventCallCount, 0)

        // Now set handledAppOrSceneDelegates — should trigger send
        handler.handledAppOrSceneDelegates = true

        XCTAssertEqual(mockService.addEventCallCount, 1,
                       "Setting handledAppOrSceneDelegates should trigger pending event send")
    }

    // MARK: - applicationDidBecomeActive

    func testApplicationDidBecomeActiveAddsTimeSpentEvent() {
        let handler = makeHandler()
        let countBefore = mockStorage.events.count

        handler.applicationDidBecomeActive()

        let timeSpentEvents = mockStorage.events.filter { $0.type == .timeSpent }
        XCTAssertEqual(timeSpentEvents.count, 1,
                       "Should add exactly one timeSpent event when no resign timestamp exists")
        XCTAssertEqual(mockStorage.events.count, countBefore + 1)
    }

    func testApplicationDidBecomeActiveTimeSpentEventHasLinkForFutureActions() {
        let handler = makeHandler()

        let exp = expectation(description: "link set")
        handler.setLinkToNewFutureActions(link: "https://active.com") {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        handler.applicationDidBecomeActive()

        let timeSpentEvents = mockStorage.events.filter { $0.type == .timeSpent }
        XCTAssertEqual(timeSpentEvents.last?.link, "https://active.com",
                       "timeSpent event should carry the current linkForFutureActions")
    }

    // MARK: - applicationWillResignActive

    func testApplicationWillResignActiveSavesTimestamp() {
        let handler = makeHandler()

        handler.applicationWillResignActive()

        let savedTimestamp = mockDefaults.store[.grovsResignTimestamp] ?? 0
        XCTAssertGreaterThan(savedTimestamp, 0,
                             "Should save a non-zero resign timestamp to mock defaults")
    }

    // MARK: - isLeewayPassed

    func testIsLeewayPassedReturnsFalseImmediatelyAfterInit() {
        let handler = makeHandler()
        XCTAssertFalse(handler.isLeewayPassed(),
                       "Leeway (5s) should not have passed immediately after init")
    }

    func testApplicationDidBecomeActiveWithResignTimestampHandlesOldEvents() {
        // Set a resign timestamp to trigger handleOldEngagementEvents path
        mockDefaults.store[.grovsResignTimestamp] = Date().toSeconds()

        let handler = makeHandler()
        let countBefore = mockStorage.events.count

        handler.applicationDidBecomeActive()

        // handleOldEngagementEvents uses DispatchQueue.main.async internally,
        // so we need to let the main run loop drain
        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 5)

        // Should add a timeSpent event (via the handleOldEngagementEvents path)
        let timeSpentEvents = mockStorage.events.filter { $0.type == .timeSpent }
        XCTAssertGreaterThanOrEqual(timeSpentEvents.count, 1,
                                    "Should add timeSpent event even with resign timestamp")
        XCTAssertGreaterThan(mockStorage.events.count, countBefore,
                             "Should have added events")
    }

    // MARK: - Init side effects

    func testInitAddsAppOpenEvent() {
        _ = makeHandler()

        let appOpenEvents = mockStorage.events.filter { $0.type == .appOpen }
        XCTAssertEqual(appOpenEvents.count, 1,
                       "Init should add exactly one appOpen event")
    }

    func testInitAddsInstallEventOnFirstOpenWithNoKeychainID() {
        // No linksquaredID in keychain → install event
        _ = makeHandler()

        let installEvents = mockStorage.events.filter { $0.type == .install }
        XCTAssertEqual(installEvents.count, 1,
                       "First open with no keychain ID should add install event")
        let reinstallEvents = mockStorage.events.filter { $0.type == .reinstall }
        XCTAssertEqual(reinstallEvents.count, 0,
                       "Should not add reinstall when no keychain ID exists")
    }

    func testInitAddsReinstallEventOnFirstOpenWithKeychainID() {
        // linksquaredID exists in keychain → reinstall event
        mockKeychain.store[.linksquaredID] = "some-id"

        _ = makeHandler()

        let reinstallEvents = mockStorage.events.filter { $0.type == .reinstall }
        XCTAssertEqual(reinstallEvents.count, 1,
                       "First open with existing keychain ID should add reinstall event")
        let installEvents = mockStorage.events.filter { $0.type == .install }
        XCTAssertEqual(installEvents.count, 0,
                       "Should not add install when keychain ID exists")
    }

    func testInitIncrementsNumberOfOpens() {
        XCTAssertEqual(mockDefaults.store[.grovsNumberOfOpens] ?? 0, 0)

        _ = makeHandler()

        XCTAssertEqual(mockDefaults.store[.grovsNumberOfOpens], 1,
                       "Init should increment numberOfOpens")
    }

    func testInitDoesNotAddInstallEventOnSubsequentOpens() {
        mockDefaults.store[.grovsNumberOfOpens] = 5

        _ = makeHandler()

        let installEvents = mockStorage.events.filter { $0.type == .install || $0.type == .reinstall }
        XCTAssertEqual(installEvents.count, 0,
                       "Should not add install event when numberOfOpens > 0")
    }

    func testInitSavesLastStartTimestamp() {
        _ = makeHandler()

        let timestamp = mockDefaults.store[.grovsLastStartTimestamp] ?? 0
        XCTAssertGreaterThan(timestamp, 0,
                             "Init should save lastStartTimestamp")
    }

    // MARK: - Reactivation

    func testInitAddsReactivationEventAtExactly7Days() {
        // daysBetween uses Calendar.startOfDay, so 7 days back from start-of-today is the boundary
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let exactly7DaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
        mockDefaults.store[.grovsLastStartTimestamp] = exactly7DaysAgo.toSeconds()
        mockDefaults.store[.grovsNumberOfOpens] = 5

        _ = makeHandler()

        let reactivations = mockStorage.events.filter { $0.type == .reactivation }
        XCTAssertEqual(reactivations.count, 1,
                       "Should add reactivation event at exactly 7 days")
    }

    func testInitDoesNotAddReactivationEventAt6CalendarDays() {
        // daysBetween uses startOfDay, so 6 calendar days back should return 6 (< 7)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
        mockDefaults.store[.grovsLastStartTimestamp] = sixDaysAgo.toSeconds()
        mockDefaults.store[.grovsNumberOfOpens] = 5

        _ = makeHandler()

        let reactivations = mockStorage.events.filter { $0.type == .reactivation }
        XCTAssertEqual(reactivations.count, 0,
                       "Should not add reactivation event at 6 calendar days (threshold is 7)")
    }

    func testInitAddsReactivationEventWhenLastStartWas8DaysAgo() {
        let eightDaysAgo = Date(timeIntervalSinceNow: -8 * 86400)
        mockDefaults.store[.grovsLastStartTimestamp] = eightDaysAgo.toSeconds()
        mockDefaults.store[.grovsNumberOfOpens] = 5

        _ = makeHandler()

        let reactivations = mockStorage.events.filter { $0.type == .reactivation }
        XCTAssertEqual(reactivations.count, 1,
                       "Should add reactivation event when last start was 8 days ago")
    }

    func testInitDoesNotAddReactivationEventOnFirstOpen() {
        // lastStartTimestamp is 0 (default) — no previous session
        _ = makeHandler()

        let reactivations = mockStorage.events.filter { $0.type == .reactivation }
        XCTAssertEqual(reactivations.count, 0,
                       "Should not add reactivation event on first open")
    }

    // MARK: - handleOldEngagementEvents (time-spent flow)

    func testHandleOldEngagementEventsCalculatesEngagementTime() {
        let handler = makeCleanHandler()
        // Prevent sendTimeSpentEventsToBackend from removing events
        mockService.addEventResult = false

        // Add a timeSpent event created 30 seconds ago
        let createdAt = Date(timeIntervalSinceNow: -30)
        let event = Event(type: .timeSpent, createdAt: createdAt)
        mockStorage.events.append(event)

        // Set resign timestamp to 10 seconds ago (so engagement = 20 seconds)
        let resignDate = Date(timeIntervalSinceNow: -10)
        mockDefaults.store[.grovsResignTimestamp] = resignDate.toSeconds()

        handler.applicationDidBecomeActive()

        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 5)

        // The event was sent to the API — check engagementTime on the sent copy
        let sentEvent = mockService.allAddedEvents.first(where: { $0.id == event.id })
        XCTAssertNotNil(sentEvent?.engagementTime,
                        "engagementTime should be set on timeSpent events")
        if let engagement = sentEvent?.engagementTime {
            XCTAssertGreaterThan(engagement, 0,
                                 "engagementTime should be positive")
        }
    }

    func testHandleOldEngagementEventsDoesNotOverwriteExistingEngagementTime() {
        let handler = makeCleanHandler()
        // Prevent sendTimeSpentEventsToBackend from removing events
        mockService.addEventResult = false

        // Add a timeSpent event that already has engagementTime set
        let event = Event(type: .timeSpent, createdAt: Date(timeIntervalSinceNow: -60), engagementTime: 42)
        mockStorage.events.append(event)

        let resignDate = Date(timeIntervalSinceNow: -5)
        mockDefaults.store[.grovsResignTimestamp] = resignDate.toSeconds()

        handler.applicationDidBecomeActive()

        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 5)

        // Check the sent event — engagementTime should remain 42
        let sentEvent = mockService.allAddedEvents.first(where: { $0.id == event.id })
        XCTAssertEqual(sentEvent?.engagementTime, 42,
                       "Existing engagementTime should not be overwritten")
    }

    func testHandleOldEngagementEventsIgnoresNonTimeSpentEvents() {
        let handler = makeCleanHandler()

        // Add a view event — should not get engagementTime
        let event = Event(type: .view, createdAt: Date(timeIntervalSinceNow: -30))
        mockStorage.events.append(event)

        let resignDate = Date(timeIntervalSinceNow: -5)
        mockDefaults.store[.grovsResignTimestamp] = resignDate.toSeconds()

        handler.applicationDidBecomeActive()

        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 5)

        let original = mockStorage.events.first(where: { $0.id == event.id })
        XCTAssertNil(original?.engagementTime,
                     "Non-timeSpent events should not get engagementTime")
    }

    func testHandleOldEngagementEventsSkipsNegativeDuration() {
        let handler = makeCleanHandler()

        // Event created AFTER the resign timestamp → negative duration
        let event = Event(type: .timeSpent, createdAt: Date(timeIntervalSinceNow: 10))
        mockStorage.events.append(event)

        let resignDate = Date(timeIntervalSinceNow: -30)
        mockDefaults.store[.grovsResignTimestamp] = resignDate.toSeconds()

        handler.applicationDidBecomeActive()

        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 5)

        let original = mockStorage.events.first(where: { $0.id == event.id })
        XCTAssertNil(original?.engagementTime,
                     "Negative duration should not set engagementTime")
    }

    func testHandleOldEngagementEventsAddsNewTimeSpentEvent() {
        let handler = makeCleanHandler()

        let resignDate = Date(timeIntervalSinceNow: -5)
        mockDefaults.store[.grovsResignTimestamp] = resignDate.toSeconds()

        let countBefore = mockStorage.events.count

        handler.applicationDidBecomeActive()

        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 5)

        let newTimeSpent = mockStorage.events.filter { $0.type == .timeSpent }
        XCTAssertGreaterThan(newTimeSpent.count, 0,
                             "Should add a new timeSpent event after processing old ones")
        XCTAssertGreaterThan(mockStorage.events.count, countBefore,
                             "Total event count should increase")
    }

    // MARK: - Deduplication through handler

    func testInitDedupsPreventsMultipleInstallEvents() {
        // Handler init adds an install event via addOrReplaceEvents.
        // Adding another install via addEvent should be deduped (mock delegates to real dedup).
        _ = makeHandler()

        let extraInstall = Event(type: .install, createdAt: Date())
        mockStorage.addEvent(event: extraInstall) {}

        let installs = mockStorage.events.filter { $0.type == .install }
        XCTAssertEqual(installs.count, 1,
                       "Dedup should keep only one install event after adding a second")
    }

    // MARK: - Async dispatch mode

    func testHandleEventsIfNeededWorksWithAsyncMockDispatch() {
        mockService.completionQueue = .global()
        mockStorage.completionQueue = .global()

        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let event = Event(type: .view, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(event)

        let exp = expectation(description: "async send")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 1,
                       "Should still send events when mocks dispatch asynchronously")
    }

    // MARK: - Concurrency & Recovery

    func testBackToBackHandleEventsDrainsStorageOnFirstCall() {
        let handler = makeCleanHandler()
        // Set handledAppOrSceneDelegates first (while hasFetchedPayloadLink is false)
        // to avoid the didSet triggering an actual send.
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let event1 = Event(type: .view, createdAt: Date(), link: "https://l.com")
        let event2 = Event(type: .open, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(contentsOf: [event1, event2])

        let exp1 = expectation(description: "first call")
        let exp2 = expectation(description: "second call")

        // With synchronous mocks the first call completes entirely (sends both
        // events and removes them from storage) before the second call starts.
        // The second call finds an empty storage and sends nothing.
        handler.handleEventsIfNeeded { exp1.fulfill() }
        handler.handleEventsIfNeeded { exp2.fulfill() }

        wait(for: [exp1, exp2], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 2,
                       "First call should send both events; second call finds storage empty")
        XCTAssertTrue(mockStorage.events.isEmpty,
                      "All events should be drained after both calls")
    }

    func testFailedEventsRetriedOnNextHandleCall() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let event = Event(type: .view, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(event)
        mockService.addEventResult = false

        // First attempt — fails, event stays
        let exp1 = expectation(description: "first attempt")
        handler.handleEventsIfNeeded { exp1.fulfill() }
        wait(for: [exp1], timeout: 5)

        XCTAssertTrue(mockStorage.events.contains(where: { $0.id == event.id }),
                      "Event should remain after failed send")

        // Retry — succeeds
        mockService.addEventResult = true
        let exp2 = expectation(description: "retry")
        handler.handleEventsIfNeeded { exp2.fulfill() }
        wait(for: [exp2], timeout: 5)

        XCTAssertFalse(mockStorage.events.contains(where: { $0.id == event.id }),
                       "Event should be removed after successful retry")
    }

    func testMixedBatchSuccessAndFailure() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let event1 = Event(type: .view, createdAt: Date(), link: "https://l.com")
        let event2 = Event(type: .open, createdAt: Date(), link: "https://l.com")
        let event3 = Event(type: .view, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(contentsOf: [event1, event2, event3])

        // Fail only event2
        mockService.addEventHandler = { event in
            return event.id != event2.id
        }

        let exp = expectation(description: "mixed batch")
        handler.handleEventsIfNeeded { exp.fulfill() }
        wait(for: [exp], timeout: 5)

        XCTAssertFalse(mockStorage.events.contains(where: { $0.id == event1.id }),
                       "Event 1 should be removed (succeeded)")
        XCTAssertTrue(mockStorage.events.contains(where: { $0.id == event2.id }),
                      "Event 2 should remain (failed)")
        XCTAssertFalse(mockStorage.events.contains(where: { $0.id == event3.id }),
                       "Event 3 should be removed (succeeded)")
    }

    func testMultiThreadedHandleEventsDoesNotDuplicateSends() {
        // Use async mocks to widen the race window.
        mockService.completionQueue = .global()
        mockStorage.completionQueue = .global()

        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let event = Event(type: .view, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(event)

        // Fire handleEventsIfNeeded from multiple threads simultaneously.
        let iterations = 10
        let allDone = expectation(description: "all iterations done")
        allDone.expectedFulfillmentCount = iterations

        for _ in 0..<iterations {
            DispatchQueue.global().async {
                handler.handleEventsIfNeeded {
                    allDone.fulfill()
                }
            }
        }

        wait(for: [allDone], timeout: 10)

        // The sendingQueue guard ensures only one batch is sent at a time.
        // The event should be sent exactly once (subsequent calls see sendingEvents = true).
        XCTAssertEqual(mockService.addEventCallCount, 1,
                       "Only one thread should win the sendingEvents guard and send the event")
    }

    // MARK: - End-to-end batching

    func testEventsAreBatchedAndAllSentOnFlush() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true

        let events = (0..<5).map { _ in
            Event(type: .view, createdAt: Date(), link: "https://l.com")
        }
        mockStorage.events.append(contentsOf: events)

        let exp = expectation(description: "all sent")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addEventCallCount, 5,
                       "All 5 events should be sent in one flush")
        let sentIDs = Set(mockService.allAddedEvents.map { $0.id })
        for event in events {
            XCTAssertTrue(sentIDs.contains(event.id), "Event \(event.id) should have been sent")
        }
        XCTAssertTrue(mockStorage.events.isEmpty,
                      "All events should be removed after successful send")
    }

    func testEventCreatedBeforeAuthIsSentAfterLinkSet() {
        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        // hasFetchedPayloadLink is false — events won't send yet

        let event = Event(type: .view, createdAt: Date())
        mockStorage.events.append(event)

        // Verify events are NOT sent yet
        XCTAssertEqual(mockService.addEventCallCount, 0)

        // Simulate link fetch completion (like post-auth)
        let exp = expectation(description: "link set triggers send")
        handler.setLinkToNewFutureActions(link: "https://auth.com") {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        // After link is set and handledAppOrSceneDelegates is true,
        // events should be sent (hasFetchedPayloadLink becomes true via setLink(nil))
        // The event should now have the link attached
        XCTAssertEqual(event.link, "https://auth.com",
                       "Event created before auth should get the link assigned")
    }

    // MARK: - Async dispatch mode (failure)

    func testHandleEventsIfNeededKeepsEventsOnFailureWithAsyncDispatch() {
        mockService.completionQueue = .global()
        mockStorage.completionQueue = .global()

        let handler = makeCleanHandler()
        handler.handledAppOrSceneDelegates = true
        handler.hasFetchedPayloadLink = true
        mockService.addEventResult = false

        let event = Event(type: .view, createdAt: Date(), link: "https://l.com")
        mockStorage.events.append(event)

        let exp = expectation(description: "async failure")
        handler.handleEventsIfNeeded {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertTrue(mockStorage.events.contains(where: { $0.id == event.id }),
                      "Event should remain in storage after failed async send")
        XCTAssertEqual(mockService.addEventCallCount, 1)
    }
}
