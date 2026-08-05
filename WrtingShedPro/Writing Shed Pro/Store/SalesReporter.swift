import Foundation
import StoreKit

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

        let payload: [String: Any] = [
            "transactionID": String(transaction.id),
            "productID": transaction.productID,
            "purchaseDate": Int(transaction.purchaseDate.timeIntervalSince1970 * 1000),
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
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
