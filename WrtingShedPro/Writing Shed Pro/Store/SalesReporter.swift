import Foundation
import StoreKit

struct SalesReportPayload: Encodable, Equatable {
    let transactionID: String
    let productID: String
    let purchaseDate: Int
    let trialTransactionID: String?
    let trialPurchaseDate: Int?

    init(
        transactionID: String,
        productID: String,
        purchaseDate: Date,
        trialTransactionID: String? = nil,
        trialPurchaseDate: Date? = nil
    ) {
        self.transactionID = transactionID
        self.productID = productID
        self.purchaseDate = Int(purchaseDate.timeIntervalSince1970 * 1000)
        self.trialTransactionID = trialTransactionID
        self.trialPurchaseDate = trialPurchaseDate.map {
            Int($0.timeIntervalSince1970 * 1000)
        }
    }
}

@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
enum SalesReporter {
    private static let endpoint = URL(string: "https://wsp-support.wsp-support.workers.dev/api/sales")!

    static func recordSale(for transaction: Transaction) async {
        guard WSPProduct.allProductIDs.contains(transaction.productID) else { return }
        guard transaction.revocationDate == nil else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var trialTransactionID: String?
        var trialPurchaseDate: Date?

        if transaction.productID == WSPProduct.fullAccess.rawValue,
           let trialResult = await Transaction.latest(for: WSPProduct.tenDayTrial.rawValue),
           case .verified(let trialTransaction) = trialResult,
           trialTransaction.revocationDate == nil {
            trialTransactionID = String(trialTransaction.id)
            trialPurchaseDate = trialTransaction.originalPurchaseDate
        }

        let payload = SalesReportPayload(
            transactionID: String(transaction.id),
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            trialTransactionID: trialTransactionID,
            trialPurchaseDate: trialPurchaseDate
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
#if DEBUG
                print("⚠️ [SalesReporter] Sale record request failed")
#endif
                return
            }
        } catch {
#if DEBUG
            print("⚠️ [SalesReporter] Sale record failed: \(error.localizedDescription)")
#endif
        }
    }
}
