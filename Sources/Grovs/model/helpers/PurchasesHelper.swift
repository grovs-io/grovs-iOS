//
//  PurchasesHelper.swift
//
//  grovs
//

import StoreKit
import Foundation

typealias TransactionsClosure = (_ result: [TransactionData]? ) -> Void

public class PurchasesHelper: NSObject {

    // Call this method when app comes to foreground
    @available(iOS 15.0, *)
    func fetchTransactions(completion: @escaping TransactionsClosure) {
        handleStoreKit2Transactions(completion: completion)
    }

    // MARK: Private methods

    // StoreKit 2 (iOS 15+) implementation
    @available(iOS 15.0, *)
    private func handleStoreKit2Transactions(completion: @escaping TransactionsClosure) {
        Task {
            do {
                var transactions = [TransactionData]()
                // Get all transactions
                for await verification in Transaction.all {
                    // Check verification result
                    switch verification {
                    case .verified(let transaction):
                        let transactionData = await createTransactionData(from: transaction)
                        transactions.append(transactionData)
                    case .unverified(_, let error):
                        print("Unverified transaction: \(error)")
                    }
                }

                completion(transactions)
            } catch {
                print("Error handling StoreKit 2 transactions: \(error)")
                completion(nil)
            }
        }
    }

    @available(iOS 15.0, *)
    private func createTransactionData(from transaction: Transaction) async -> TransactionData {
        // Get product details
        let product = try? await Product.products(for: [transaction.productID]).first

        return TransactionData(
            type: transaction.revocationDate == nil ? .buy : .cancel,
            price: priceToCents(product?.price),
            transactionID: transaction.id,
            oldTransactionID: transaction.originalID,
            currency: product?.priceFormatStyle.currencyCode ?? "USD",
            productID: transaction.productID,
            bundleID: Bundle.main.bundleIdentifier ?? "",
            startDate: transaction.purchaseDate,
            store: true
        )
    }

    private func priceToCents(_ price: Decimal?) -> Int? {
        guard let price else {
            return nil
        }

        let valueInCents = price * 100
        return NSDecimalNumber(decimal: valueInCents).intValue
    }
}
