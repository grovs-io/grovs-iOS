import Foundation
@testable import Grovs

class MockAPIService: APIServiceProtocol {

    /// Optional queue for dispatching completions asynchronously.
    /// When nil (default), completions fire synchronously.
    var completionQueue: DispatchQueue?

    // MARK: - addEvent

    var addEventResult: Bool = true
    var addEventCallCount = 0
    var allAddedEvents: [Event] = []
    var addEventHandler: ((Event) -> Bool)?

    func addEvent(event: Event, completion: @escaping GrovsBoolCompletion) {
        addEventCallCount += 1
        allAddedEvents.append(event)
        let result = addEventHandler?(event) ?? addEventResult
        dispatch { completion(result) }
    }

    // MARK: - addPaymentEvent

    var addPaymentEventResult: Bool = true
    var addPaymentEventCallCount = 0
    var allTransactionData: [TransactionData] = []
    var addPaymentEventHandler: ((TransactionData) -> Bool)?

    func addPaymentEvent(transactionData: TransactionData, completion: @escaping GrovsBoolCompletion) {
        addPaymentEventCallCount += 1
        allTransactionData.append(transactionData)
        let result = addPaymentEventHandler?(transactionData) ?? addPaymentEventResult
        dispatch { completion(result) }
    }

    // MARK: - Reset

    /// Resets call counts and results. Does NOT reset completionQueue — set it separately.
    func reset() {
        addEventResult = true
        addEventCallCount = 0
        allAddedEvents.removeAll()
        addEventHandler = nil
        addPaymentEventResult = true
        addPaymentEventCallCount = 0
        allTransactionData.removeAll()
        addPaymentEventHandler = nil
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
