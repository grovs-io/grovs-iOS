//
//  TransactionData.swift
//
//  grovs
//

import Foundation

public enum TransactionType: String {
    case buy
    case cancel
}

struct TransactionData {
    let type: TransactionType
    let price: Int?
    let transactionID: UInt64?
    let oldTransactionID: UInt64?
    let currency: String?
    let productID: String?
    let bundleID: String?
    let startDate: Date?
    let store: Bool

    func toData() -> [String: Any] {
        [
            "event_type": type.rawValue,
            "price_cents": price,
            "currency": currency,
            "transaction_id": transactionID,
            "original_transaction_id": oldTransactionID,
            "product_id": productID,
            "bundle_id": bundleID,
            "date": startDate?.backendDateString(),
            "store": store
        ]
    }
}
