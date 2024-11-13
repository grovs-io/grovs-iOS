//
//  EventsStorage.swift
//
//  grovs
//

import Foundation

/// A typealias for the closure used to handle events.
typealias GrovsEventsClosure = (_ events: [Event]?) -> Void

/// A class responsible for storing and managing events.
class EventsStorage {

    // MARK: - Constants

    private struct Constants {
        static let cachedEvents = "cached-events"
    }

    // MARK: - Properties

    /// The data cache instance used for storing events.
    private let dataCache = DataCache(name: "grovs-events-cache")

    /// A serial dispatch queue for managing access to shared resources.
    private let serialQueue = DispatchQueue(label: "com.grovs-events-queue")

    // MARK: - Public Methods

    /// Adds or replaces events in the storage.
    ///
    /// - Parameter events: The events to add or replace.
    func addOrReplaceEvents(events: [Event]) {
        serialQueue.async {
            var existingEvents: [Event] = []

            if let readEvents = self.dataCache.readArray(forKey: Constants.cachedEvents) as? [Event] {
                existingEvents = readEvents
            }

            for sourceEvent in events {
                if let existingIndex = existingEvents.firstIndex(where: { $0.createdAt == sourceEvent.createdAt }) {
                    existingEvents[existingIndex] = sourceEvent
                } else {
                    existingEvents.append(sourceEvent)
                }
            }

            self.dataCache.write(array: existingEvents, forKey: Constants.cachedEvents)
        }
    }

    /// Adds an event to the storage.
    ///
    /// - Parameter event: The event to add.
    func addEvent(event: Event) {
        serialQueue.async {
            var events: [Event] = []

            if let readEvents = self.dataCache.readArray(forKey: Constants.cachedEvents) as? [Event] {
                events = readEvents
            }

            events.append(event)
            self.dataCache.write(array: events, forKey: Constants.cachedEvents)
        }
    }

    /// Removes an event from the storage.
    ///
    /// - Parameter event: The event to remove.
    func removeEvent(event: Event) {
        serialQueue.async {
            if var readEvents = self.dataCache.readArray(forKey: Constants.cachedEvents) as? [Event] {
                readEvents.removeAll(where: { $0.createdAt == event.createdAt })

                self.dataCache.write(array: readEvents, forKey: Constants.cachedEvents)
            }
        }
    }

    /// Retrieves all events from the storage.
    ///
    /// - Parameter completion: A closure to be called with the retrieved events.
    func getEvents(completion: @escaping GrovsEventsClosure) {
        serialQueue.async {
            let readEvents = self.dataCache.readArray(forKey: Constants.cachedEvents) as? [Event]

            DispatchQueue.global(qos: .background).async {
                completion(readEvents)
            }
        }
    }
}
