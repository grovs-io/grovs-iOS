//
//  EventsHandler.swift
//
//  grovs
//

import UIKit

// Closure type definitions for event handling
typealias GrovsChangeEventClosure = (_ oldEvent: Event) -> Event
public typealias GrovsEmptyClosure = () -> Void

/// Manages event handling and dispatching for the application.
class EventsHandler {

    // Constants used internally
    private struct Constants {
        static let firstBatchEventsSendingLeeway: Double = 5.0 // Seconds
        static let numberOfDaysForReactivation: Int = 7
    }

    // MARK: Properties

    private let service: APIService
    private let storage = EventsStorage()
    private var linkForFutureActions: String?

    // MARK: Initialization

    /// Initializes the `EventsHandler` with the provided API service.
    /// - Parameter apiService: The service used for API calls
    init(apiService: APIService) {
        service = apiService

        // Set up observers and initial events
        addObservers()
        addInitialEvents()
        addOpenEvent()
    }

    // MARK: Public Methods

    /// Logs an event and sends it to the backend.
    /// - Parameter event: The event to log
    func log(event: Event) {
        let newEvent = event
        if newEvent.link == nil {
            newEvent.link = linkForFutureActions
        }

        storage.addEvent(event: newEvent)
        sendNormalEventsToBackend()
    }

    /// Sets the link for future actions to associate with new events.
    /// - Parameter link: The link to set
    func setLinkToNewFutureActions(link: String?) {
        linkForFutureActions = link
        if let link {
            addLinkToEvents(link: link)
        }
    }

    // MARK: Notifications

    /// Called when the application becomes active.
    @objc func applicationDidBecomeActive() {
        initialDispatchEvents()

        let lastResignTimestamp = UserDefaultsHelper.getInt(key: .grovsResignTimestamp)
        if lastResignTimestamp != 0 {
            handleOldEvents(timestamp: Date.fromSeconds(lastResignTimestamp))
        } else {
            // Add a time-spent event if there is no last resign timestamp
            let event = Event(type: .timeSpent, createdAt: Date())
            storage.addEvent(event: event)
        }
    }

    /// Called when the application will resign active.
    @objc func applicationWillResignActive() {
        UserDefaultsHelper.set(value: Date().toSeconds(), key: .grovsResignTimestamp)
    }

    // MARK: Private Methods

    /// Dispatches initial events after a delay.
    private func initialDispatchEvents() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + Constants.firstBatchEventsSendingLeeway, execute: { [weak self] in
            self?.sendNormalEventsToBackend()
        })
    }

    /// Adds initial events such as install or reactivation events.
    private func addInitialEvents() {
        addInstallIfNeeded()
        addReactivationIfNeeded()

        // Increment the number of opens in UserDefaults
        UserDefaultsHelper.set(value: UserDefaultsHelper.getInt(key: .grovsNumberOfOpens) + 1, key: .grovsNumberOfOpens)
    }

    /// Logs an install event if it's the first app launch.
    private func addInstallIfNeeded() {
        let numberOfOpens = UserDefaultsHelper.getInt(key: .grovsNumberOfOpens)
        let linksquaredID = KeychainHelper.getValue(forKey: .linksquaredID)

        if numberOfOpens == 0 {
            // Log an install event if it's the first open
            let event = linksquaredID != nil ? Event(type: .reinstall, createdAt: Date()) : Event(type: .install, createdAt: Date())
            storage.addEvent(event: event)
        }
    }

    /// Logs a reactivation event if the app was inactive for the specified number of days.
    private func addReactivationIfNeeded() {
        let lastResignTimestamp = UserDefaultsHelper.getInt(key: .grovsLastStartTimestamp)
        if lastResignTimestamp != 0 {
            let lastResignDate = Date.fromSeconds(lastResignTimestamp)

            if let days = lastResignDate.daysBetween(Date()), days >= Constants.numberOfDaysForReactivation {

                let event = Event(type: .reactivation, createdAt: Date())
                storage.addEvent(event: event)
            }
        }

        UserDefaultsHelper.set(value: Date().toSeconds(), key: .grovsLastStartTimestamp)
    }

    /// Logs an app open event.
    private func addOpenEvent() {
        // Log an app open event
        let event = Event(type: .appOpen, createdAt: Date())
        storage.addEvent(event: event)
    }

    /// Sets up observers for application lifecycle notifications.
    private func addObservers() {
        // Add observers for application lifecycle notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }

    /// Handles old events that occurred before the app resigned active.
    /// - Parameter timestamp: The timestamp of when the app last resigned active
    private func handleOldEvents(timestamp: Date) {
        // Handle events that occurred before the app resigned active
        let event = Event(type: .timeSpent, createdAt: Date())

        // Store the correct duration of events
        changeStorageEvents { oldEvent in
            let newEvent = oldEvent
            if oldEvent.engagementTime == nil && oldEvent.type == .timeSpent {
                let secondsPassed = Int(timestamp.timeIntervalSince(oldEvent.createdAt))
                if secondsPassed > 0 {
                    newEvent.engagementTime = secondsPassed
                }
            }
            return newEvent
        } completion: {
            // Send the time-spent events to the backend and add the new event
            self.sendTimeSpentEventsToBackend()
            self.storage.addEvent(event: event)
        }
    }

    /// Adds a link to all stored events that do not already have one.
    /// - Parameter link: The link to add
    private func addLinkToEvents(link: String) {
        // Add a link to the stored events
        changeStorageEvents { oldEvent in
            let newEvent = oldEvent
            if newEvent.link == nil {
                newEvent.link = link
            }
            return newEvent
        } completion: {
            // Send the updated events to the backend
            self.sendNormalEventsToBackend()
        }
    }

    /// Changes stored events based on a closure and performs a completion handler.
    /// - Parameter eventHandling: A closure that defines how to modify each event
    /// - Parameter completion: A completion handler to call after processing events
    private func changeStorageEvents(eventHandling: @escaping GrovsChangeEventClosure, completion: GrovsEmptyClosure?) {
        // Change stored events based on a closure and perform completion
        storage.getEvents { events in
            if let events = events {
                var newEvents = [Event]()

                for event in events {
                    let newEvent = eventHandling(event)
                    newEvents.append(newEvent)
                }

                self.storage.addOrReplaceEvents(events: newEvents)

                completion?()
            }
        }
    }

    /// Sends normal events (non-time-spent) to the backend.
    private func sendNormalEventsToBackend() {
        // Send normal events to the backend
        storage.getEvents { events in
            guard let events = events else {
                return
            }

            DebugLogger.shared.log(.info, "Sending logs to the backend")

            let group = DispatchGroup()
            for event in events {
                if event.type != .timeSpent {
                    group.enter()

                    self.service.addEvent(event: event) { value in
                        if value {
                            self.storage.removeEvent(event: event)
                        }

                        group.leave()
                    }
                }
            }

            group.wait()
        }
    }

    /// Sends time-spent events to the backend.
    private func sendTimeSpentEventsToBackend() {
        // Send time-spent events to the backend
        storage.getEvents { events in
            guard let events = events else {
                return
            }

            DebugLogger.shared.log(.info, "Sending time-spent logs to the backend")

            let group = DispatchGroup()
            for event in events {
                if event.type == .timeSpent {
                    group.enter()

                    self.service.addEvent(event: event) { value in
                        if value {
                            self.storage.removeEvent(event: event)
                        }

                        group.leave()
                    }
                }
            }

            group.wait()
        }
    }
}
