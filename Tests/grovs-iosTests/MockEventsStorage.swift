import Foundation
@testable import Grovs

class MockEventsStorage: EventsStorageProtocol {
    var events: [Event] = []

    /// Optional queue for dispatching completions asynchronously.
    /// When nil (default), completions fire synchronously.
    var completionQueue: DispatchQueue?

    var addEventCallCount = 0
    var addOrReplaceCallCount = 0
    var removeEventCallCount = 0
    var getEventsCallCount = 0
    var transformEventsCallCount = 0

    /// Shared dedup implementation — delegates to the real EventsStorage so the mock
    /// never drifts from production behavior.
    private let realStorage = EventsStorage()

    func addEvent(event: Event, completion: @escaping GrovsEmptyClosure) {
        addEventCallCount += 1
        events.append(event)
        events = removeDuplicateEventsIfNeeded(events: events)
        dispatch { completion() }
    }

    func addOrReplaceEvents(events: [Event], completion: @escaping GrovsEmptyClosure) {
        addOrReplaceCallCount += 1
        // Match real EventsStorage: dedup existing, then upsert, matching production order
        var existing = removeDuplicateEventsIfNeeded(events: self.events)
        for event in events {
            if let index = existing.firstIndex(where: { $0.id == event.id }) {
                existing[index] = event
            } else {
                existing.append(event)
            }
        }
        self.events = existing
        dispatch { completion() }
    }

    func removeEvent(event: Event, completion: @escaping GrovsEmptyClosure) {
        removeEventCallCount += 1
        events.removeAll(where: { $0.id == event.id })
        dispatch { completion() }
    }

    func getEvents(completion: @escaping GrovsEventsClosure) {
        getEventsCallCount += 1
        let snapshot = events
        dispatch { completion(snapshot) }
    }

    func transformEvents(_ transform: @escaping (Event) -> Event, completion: @escaping GrovsEmptyClosure) {
        transformEventsCallCount += 1
        events = events.map(transform)
        dispatch { completion() }
    }

    /// Delegates to the real EventsStorage's stateless dedup method.
    func removeDuplicateEventsIfNeeded(events: [Event]) -> [Event] {
        return realStorage.removeDuplicateEventsIfNeeded(events: events)
    }

    func reset() {
        events.removeAll()
        addEventCallCount = 0
        addOrReplaceCallCount = 0
        removeEventCallCount = 0
        getEventsCallCount = 0
        transformEventsCallCount = 0
    }

    // MARK: - Private

    private func dispatch(_ block: @escaping () -> Void) {
        if let queue = completionQueue {
            queue.async { block() }
        } else {
            block()
        }
    }
}
