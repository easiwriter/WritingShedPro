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

struct SalesReportResponse: Decodable {
    let verified: Bool
}

@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
enum SalesReporter {
    private static let endpoint = URL(string: "https://wsp-support.wsp-support.workers.dev/api/sales")!
    private static let reportState = SalesReportState()

    static func reconcileCurrentEntitlements() async {
        var reportedTrial = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == WSPProduct.tenDayTrial.rawValue {
                reportedTrial = true
            }
            await recordSale(for: transaction)
        }

        if !reportedTrial,
           let trialResult = await Transaction.latest(for: WSPProduct.tenDayTrial.rawValue),
           case .verified(let trialTransaction) = trialResult {
            await recordSale(for: trialTransaction)
        }
    }

    static func recordSale(for transaction: Transaction) async {
        guard WSPProduct.allProductIDs.contains(transaction.productID) else { return }
        guard transaction.revocationDate == nil else { return }
        guard await reportState.begin(transactionID: transaction.id) else { return }

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
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  try JSONDecoder().decode(SalesReportResponse.self, from: data).verified else {
                await reportState.fail(transactionID: transaction.id)
#if DEBUG
                print("⚠️ [SalesReporter] Apple transaction verification failed")
#endif
                return
            }
            await reportState.succeed(transactionID: transaction.id)
        } catch {
            await reportState.fail(transactionID: transaction.id)
#if DEBUG
            print("⚠️ [SalesReporter] Sale record failed: \(error.localizedDescription)")
#endif
        }
    }
}

actor SalesReportState {
    private static let verifiedTransactionIDsKey = "salesReporter.verifiedTransactionIDs"

    private let defaults: UserDefaults
    private var verifiedTransactionIDs: Set<String>
    private var inFlightTransactionIDs: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        verifiedTransactionIDs = Set(
            defaults.stringArray(forKey: Self.verifiedTransactionIDsKey) ?? []
        )
    }

    func begin(transactionID: UInt64) -> Bool {
        let value = String(transactionID)
        guard !verifiedTransactionIDs.contains(value) else { return false }
        return inFlightTransactionIDs.insert(value).inserted
    }

    func succeed(transactionID: UInt64) {
        let value = String(transactionID)
        inFlightTransactionIDs.remove(value)
        verifiedTransactionIDs.insert(value)
        defaults.set(
            verifiedTransactionIDs.sorted(),
            forKey: Self.verifiedTransactionIDsKey
        )
    }

    func fail(transactionID: UInt64) {
        inFlightTransactionIDs.remove(String(transactionID))
    }
}
