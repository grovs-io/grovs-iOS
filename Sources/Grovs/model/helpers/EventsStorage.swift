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
    private let serialQueue = DispatchQueue(label: "com.grovs-events-queue", qos: .background)

    // MARK: - Public Methods

    /// Adds or replaces events in the storage.
    ///
    /// - Parameter events: The events to add or replace.
    func addOrReplaceEvents(events: [Event], completion: @escaping GrovsEmptyClosure) {
        serialQueue.sync {
            var existingEvents: [Event] = []

            if let readEvents = self.dataCache.readArray(forKey: Constants.cachedEvents) as? [Event] {
                existingEvents = readEvents
            }

            existingEvents = self.removeDuplicateEventsIfNeeded(events: existingEvents)

            for sourceEvent in events {
                if let existingIndex = existingEvents.firstIndex(where: { $0.createdAt == sourceEvent.createdAt }) {
                    existingEvents[existingIndex] = sourceEvent
                } else {
                    existingEvents.append(sourceEvent)
                }
            }

            self.dataCache.write(array: existingEvents, forKey: Constants.cachedEvents)

            DispatchQueue.global(qos: .background).async {
                completion()
            }
        }
    }

    /// Adds an event to the storage.
    ///
    /// - Parameter event: The event to add.
    func addEvent(event: Event, completion: @escaping GrovsEmptyClosure) {
        serialQueue.sync {
            var events: [Event] = []

            if let readEvents = self.dataCache.readArray(forKey: Constants.cachedEvents) as? [Event] {
                events = readEvents
            }

            events.append(event)
            let existingEvents = self.removeDuplicateEventsIfNeeded(events: events)

            self.dataCache.write(array: existingEvents, forKey: Constants.cachedEvents)

            DispatchQueue.global(qos: .background).async {
                completion()
            }
        }
    }

    /// Removes an event from the storage.
    ///
    /// - Parameter event: The event to remove.
    func removeEvent(event: Event, completion: @escaping GrovsEmptyClosure) {
        serialQueue.sync {
            if var readEvents = self.dataCache.readArray(forKey: Constants.cachedEvents) as? [Event] {
                readEvents.removeAll(where: { $0.createdAt == event.createdAt })

                self.dataCache.write(array: readEvents, forKey: Constants.cachedEvents)
            }

            DispatchQueue.global(qos: .background).async {
                completion()
            }
        }
    }

    /// Retrieves all events from the storage.
    ///
    /// - Parameter completion: A closure to be called with the retrieved events.
    func getEvents(completion: @escaping GrovsEventsClosure) {
        serialQueue.async {
            let readEvents = self.dataCache.readArray(forKey: Constants.cachedEvents) as? [Event]

            DispatchQueue.global().async {
                completion(readEvents)
            }
        }
    }

    // Private methods

    // Remove duplicated install / reinstall events
    ///
    /// - Parameter events: A list of events
    func removeDuplicateEventsIfNeeded(events: [Event]) -> [Event] {
        var newEvents = events

        var hasInstall = false
        if let latestInstallEvent = events.filter({ $0.type == .install }).max(by: { $0.createdAt < $1.createdAt }) {
            // Remove any existing "install" events
            newEvents.removeAll { $0.type == .install }
            // Add the latest "install" event
            newEvents.append(latestInstallEvent)
            hasInstall = true
        }

        if hasInstall {
            // Remove all the reinstall events
            newEvents.removeAll { $0.type == .reinstall }

        } else if let latestReinstallEvent = events.filter({ $0.type == .reinstall }).max(by: { $0.createdAt < $1.createdAt }) {
            // Remove any existing "reinstall" events
            newEvents.removeAll { $0.type == .reinstall }
            // Add the latest "reinstall" event
            newEvents.append(latestReinstallEvent)
        }

        return newEvents
    }
}
