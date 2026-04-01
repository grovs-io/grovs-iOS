//
//  TransactionData.swift
//
//  grovs
//

import Foundation

public enum TransactionType: String, Codable {
    case buy
    case cancel
    case refund
}

struct TransactionData: Codable {
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
            "identifier": bundleID,
            "date": startDate?.backendDateString(),
            "store": store
        ]
    }
}
