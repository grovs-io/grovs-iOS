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
        static let maxEventAgeDays: Int = 7
    }

    // MARK: Properties

    private let service: APIServiceProtocol
    private let storage: EventsStorageProtocol
    private let userDefaults: UserDefaultsHelperProtocol
    private let keychain: KeychainHelperProtocol
    private let sendingQueue = DispatchQueue(label: "com.grovs.eventsHandler.sending")
    private var linkForFutureActions: String?
    private var sendingEvents = false
    private var sendingTimeSpentEvents = false
    var hasFetchedPayloadLink = false
    private var startupTime: Date!

    var handledAppOrSceneDelegates = false {
        didSet {
            handleEventsIfNeeded(completion: nil)
        }
    }

    // MARK: Initialization

    /// Initializes the `EventsHandler` with the provided API service.
    /// - Parameter apiService: The service used for API calls
    init(apiService: APIServiceProtocol,
         storage: EventsStorageProtocol = EventsStorage(),
         userDefaults: UserDefaultsHelperProtocol = UserDefaultsHelper(),
         keychain: KeychainHelperProtocol = KeychainHelper()) {
        self.service = apiService
        self.storage = storage
        self.userDefaults = userDefaults
        self.keychain = keychain

        // Set up observers and initial events
        startupTime = Date()
        Timer.scheduledTimer(withTimeInterval: Constants.firstBatchEventsSendingLeeway, repeats: false) { [weak self] _  in
            self?.handleEventsIfNeeded(completion: nil)
        }

        addObservers()
        addInitialEvents()
        addOpenEvent()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Public Methods

    /// Logs an event and sends it to the backend.
    /// - Parameter event: The event to log
    func log(event: Event) {
        let newEvent = event
        if newEvent.link == nil {
            newEvent.link = linkForFutureActions
        }

        storage.addEvent(event: newEvent) { [weak self] in
            self?.handleEventsIfNeeded(completion: nil)
        }
    }

    /// Sets the link for future actions to associate with new events.
    /// - Parameter link: The link to set
    func setLinkToNewFutureActions(link: String?, completion: GrovsEmptyClosure?) {
        if let link {
            self.linkForFutureActions = link
            self.addLinkToEvents(link: link, completion: completion)
        } else {
            self.hasFetchedPayloadLink = true
            self.handleEventsIfNeeded(completion: completion)
        }
    }

    // MARK: Notifications

    /// Called when the application becomes active.
    @objc func applicationDidBecomeActive() {
        let lastResignTimestamp = userDefaults.getInt(key: .grovsResignTimestamp)
        if lastResignTimestamp != 0 {
            handleOldEngagementEvents(timestamp: Date.fromSeconds(lastResignTimestamp))
        } else {
            // Add a time-spent event if there is no last resign timestamp
            let event = Event(type: .timeSpent, createdAt: Date(), link: linkForFutureActions)
            storage.addEvent(event: event) {
                // Do nothing
            }
        }
    }

    /// Called when the application will resign active.
    @objc func applicationWillResignActive() {
        userDefaults.setInt(value: Date().toSeconds(), key: .grovsResignTimestamp)
    }

    // MARK: Private Methods

    /// Adds initial events such as install or reactivation events.
    private func addInitialEvents() {
        addInstallIfNeeded()
        addReactivationIfNeeded()

        // Increment the number of opens in UserDefaults
        userDefaults.setInt(value: userDefaults.getInt(key: .grovsNumberOfOpens) + 1, key: .grovsNumberOfOpens)
    }

    /// Logs an install event if it's the first app launch.
    private func addInstallIfNeeded() {
        let numberOfOpens = userDefaults.getInt(key: .grovsNumberOfOpens)
        let linksquaredID = keychain.getValue(forKey: .linksquaredID)

        if numberOfOpens == 0 {
            // Log an install event if it's the first open
            let event = linksquaredID != nil ? Event(type: .reinstall, createdAt: Date(), link: linkForFutureActions) : Event(type: .install, createdAt: Date(), link: linkForFutureActions)
            storage.addOrReplaceEvents(events: [event]) {
                // Do nothing
            }
        }
    }

    /// Logs a reactivation event if the app was inactive for the specified number of days.
    private func addReactivationIfNeeded() {
        let lastResignTimestamp = userDefaults.getInt(key: .grovsLastStartTimestamp)
        if lastResignTimestamp != 0 {
            let lastResignDate = Date.fromSeconds(lastResignTimestamp)

            if let days = lastResignDate.daysBetween(Date()), days >= Constants.numberOfDaysForReactivation {

                let event = Event(type: .reactivation, createdAt: Date(), link: linkForFutureActions)
                storage.addEvent(event: event) {
                    // Do nothing
                }
            }
        }

        userDefaults.setInt(value: Date().toSeconds(), key: .grovsLastStartTimestamp)
    }

    /// Logs an app open event.
    private func addOpenEvent() {
        // Log an app open event
        let event = Event(type: .appOpen, createdAt: Date(), link: linkForFutureActions)
        storage.addEvent(event: event) {
            // Do nothing
        }
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
    private func handleOldEngagementEvents(timestamp: Date) {
        // Handle events that occurred before the app resigned active
        let event = Event(type: .timeSpent, createdAt: Date(), link: linkForFutureActions)

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
            self.storage.addEvent(event: event) {
                // Do nothing
            }
        }
    }

    /// Adds a link to all stored events that do not already have one.
    /// - Parameter link: The link to add
    private func addLinkToEvents(link: String, completion: GrovsEmptyClosure?) {
        // Add a link to the stored events
        changeStorageEvents { oldEvent in
            let newEvent = oldEvent
            if newEvent.link == nil && newEvent.createdAt >= self.startupTime {
                newEvent.link = link
            }
            return newEvent
        } completion: {
            // Send the updated events to the backend
            self.hasFetchedPayloadLink = true
            self.handleEventsIfNeeded(completion: completion)
        }
    }

    /// Changes stored events based on a closure and performs a completion handler.
    /// Uses an atomic read-modify-write so concurrent removes cannot resurrect events.
    /// - Parameter eventHandling: A closure that defines how to modify each event
    /// - Parameter completion: A completion handler to call after processing events
    private func changeStorageEvents(eventHandling: @escaping GrovsChangeEventClosure, completion: GrovsEmptyClosure?) {
        storage.transformEvents(eventHandling) {
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    /// Sends normal events (non-time-spent) to the backend.
    private func sendNormalEventsToBackend(completion: GrovsEmptyClosure?) {
        let alreadySending = sendingQueue.sync { () -> Bool in
            if sendingEvents { return true }
            sendingEvents = true
            return false
        }

        if alreadySending {
            completion?()
            return
        }

        // Send normal events to the backend
        storage.getEvents { events in
            guard let events = events else {
                self.sendingQueue.sync { self.sendingEvents = false }
                completion?()
                return
            }

            DebugLogger.shared.log(.info, "Sending logs to the backend")

            let group = DispatchGroup()
            for event in events {
                if event.type != .timeSpent {
                    // Discard events older than the max age
                    if let days = event.createdAt.daysBetween(Date()), days >= Constants.maxEventAgeDays {
                        DebugLogger.shared.log(.error, "Discarding stale event (\(event.type.rawValue)) aged \(days) days")
                        self.storage.removeEvent(event: event) {}
                        continue
                    }

                    group.enter()

                    self.service.addEvent(event: event) { value in
                        if value {
                            self.storage.removeEvent(event: event) {
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.sendingQueue.sync { self.sendingEvents = false }
                completion?()
            }
        }
    }

    /// Sends time-spent events to the backend.
    private func sendTimeSpentEventsToBackend() {
        let alreadySending = sendingQueue.sync { () -> Bool in
            if sendingTimeSpentEvents { return true }
            sendingTimeSpentEvents = true
            return false
        }

        if alreadySending { return }

        // Send time-spent events to the backend
        storage.getEvents { events in
            guard let events = events else {
                self.sendingQueue.sync { self.sendingTimeSpentEvents = false }
                return
            }

            DebugLogger.shared.log(.info, "Sending time-spent logs to the backend")

            let group = DispatchGroup()
            for event in events {
                if event.type == .timeSpent {
                    // Discard events older than the max age
                    if let days = event.createdAt.daysBetween(Date()), days >= Constants.maxEventAgeDays {
                        DebugLogger.shared.log(.error, "Discarding stale time-spent event aged \(days) days")
                        self.storage.removeEvent(event: event) {}
                        continue
                    }

                    group.enter()
                    self.service.addEvent(event: event) { value in
                        if value {
                            self.storage.removeEvent(event: event) {
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.sendingQueue.sync { self.sendingTimeSpentEvents = false }
            }
        }
    }

    /// Send events to backend if needed
    func handleEventsIfNeeded(completion: GrovsEmptyClosure?) {
        if (handledAppOrSceneDelegates || isLeewayPassed()) && hasFetchedPayloadLink {
            sendNormalEventsToBackend(completion: completion)
        } else {
            completion?()
        }
    }

    /// Checks if the current time is greater than startupTime + leeway
    ///
    /// - Returns: `true` if the current time has exceeded the leeway period, else `false`
    func isLeewayPassed() -> Bool {
        guard let startupTime = self.startupTime else {
            // Handle the case where startupTime is not set
            return false
        }

        let leewayInterval = Constants.firstBatchEventsSendingLeeway
        let allowedTime = startupTime.addingTimeInterval(leewayInterval)
        let currentTime = Date()

        return currentTime > allowedTime
    }
}
