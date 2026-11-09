import Foundation
import Security
import StoreKit

struct SalesReportPayload: Encodable, Equatable {
    let transactionID: String
    let productID: String
    let purchaseDate: Int
    let trialTransactionID: String?
    let trialPurchaseDate: Int?
    let trialID: String?

    init(
        transactionID: String,
        productID: String,
        purchaseDate: Date,
        trialTransactionID: String? = nil,
        trialPurchaseDate: Date? = nil,
        trialID: String? = nil
    ) {
        self.transactionID = transactionID
        self.productID = productID
        self.purchaseDate = Int(purchaseDate.timeIntervalSince1970 * 1000)
        self.trialTransactionID = trialTransactionID
        self.trialPurchaseDate = trialPurchaseDate.map {
            Int($0.timeIntervalSince1970 * 1000)
        }
        self.trialID = trialID
    }
}

struct SalesReportResponse: Decodable {
    let verified: Bool
}

@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
enum SalesReporter {
    private static let endpoint = URL(string: "https://wsp-support.wsp-support.workers.dev/api/sales")!
    private static let reportState = SalesReportState()

    static func shouldReport(environment: AppStore.Environment) -> Bool {
        environment == .production
    }

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
        guard shouldReport(environment: transaction.environment) else { return }
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
            trialPurchaseDate: trialPurchaseDate,
            trialID: transaction.productID == WSPProduct.fullAccess.rawValue
                ? await TrialTelemetryReporter.shared.existingTrialID()
                : nil
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

    private struct TrialTelemetryPayload: Encodable {
        let trialID: String
        let event: String
        let startedAt: Int
        let observedAt: Int?
    }

    private enum TrialTelemetryError: Error {
        case invalidKeychainValue
        case keychainFailure(OSStatus)
        case invalidServerResponse
    }

    actor TrialTelemetryReporter {
        static let shared = TrialTelemetryReporter()

        private static let endpoint = URL(string: "https://wsp-support.wsp-support.workers.dev/api/trials")!
        private static let keychainService = "com.appworks.writingshedpro.trial-telemetry"
        private static let keychainAccount = "anonymous-trial-id"

        private let defaults: UserDefaults

        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
        }

        func reconcile(
            purchaseModel: PurchaseModel?,
            trialStartDate: Date?,
            coreAccessState: CoreAccessState
        ) async {
            guard purchaseModel == .trialAndFullAccess,
                  let trialStartDate else { return }

            do {
                guard try await isProductionApp() else { return }
                let trialID = try getOrCreateTrialID()
                try await reportIfNeeded(
                    trialID: trialID,
                    event: "started",
                    startedAt: trialStartDate,
                    observedAt: nil
                )
                if coreAccessState == .trialExpired {
                    try await reportIfNeeded(
                        trialID: trialID,
                        event: "expired",
                        startedAt: trialStartDate,
                        observedAt: Date()
                    )
                }
            } catch {
    #if DEBUG
                print("⚠️ [TrialTelemetry] Lifecycle report failed: \(error.localizedDescription)")
    #endif
            }
        }

        func existingTrialID() -> String? {
            do {
                return try readTrialID()
            } catch {
    #if DEBUG
                print("⚠️ [TrialTelemetry] Unable to read trial identity: \(error.localizedDescription)")
    #endif
                return nil
            }
        }

        private func reportIfNeeded(
            trialID: String,
            event: String,
            startedAt: Date,
            observedAt: Date?
        ) async throws {
            let reportedKey = "trialTelemetry.\(trialID).\(event)"
            guard !defaults.bool(forKey: reportedKey) else { return }

            let payload = TrialTelemetryPayload(
                trialID: trialID,
                event: event,
                startedAt: Int(startedAt.timeIntervalSince1970 * 1000),
                observedAt: observedAt.map { Int($0.timeIntervalSince1970 * 1000) }
            )
            var request = URLRequest(url: Self.endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw TrialTelemetryError.invalidServerResponse
            }
            defaults.set(true, forKey: reportedKey)
        }

        private func isProductionApp() async throws -> Bool {
            switch try await AppTransaction.shared {
            case .verified(let transaction):
                return transaction.environment == .production
            case .unverified:
                return false
            }
        }

        private func getOrCreateTrialID() throws -> String {
            if let existing = try readTrialID() {
                return existing
            }

            let value = UUID().uuidString.lowercased()
            let data = Data(value.utf8)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.keychainService,
                kSecAttrAccount as String: Self.keychainAccount,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw TrialTelemetryError.keychainFailure(status)
            }
            return value
        }

        private func readTrialID() throws -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.keychainService,
                kSecAttrAccount as String: Self.keychainAccount,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound {
                return nil
            }
            guard status == errSecSuccess else {
                throw TrialTelemetryError.keychainFailure(status)
            }
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8),
                  UUID(uuidString: value) != nil else {
                throw TrialTelemetryError.invalidKeychainValue
            }
            return value.lowercased()
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
