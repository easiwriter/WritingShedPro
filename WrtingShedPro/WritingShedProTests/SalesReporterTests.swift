import XCTest
@testable import Writing_Shed_Pro

final class SalesReporterTests: XCTestCase {
    func testLegacyPayloadDoesNotIncludeTrialLink() throws {
        let payload = SalesReportPayload(
            transactionID: "legacy-transaction",
            productID: WSPProduct.proseWriter.rawValue,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
        )

        XCTAssertEqual(json["transactionID"] as? String, "legacy-transaction")
        XCTAssertEqual(json["productID"] as? String, WSPProduct.proseWriter.rawValue)
        XCTAssertEqual(json["purchaseDate"] as? Int, 1_700_000_000_000)
        XCTAssertNil(json["trialTransactionID"])
        XCTAssertNil(json["trialPurchaseDate"])
    }

    func testFullAccessPayloadIncludesTrialCohortLink() throws {
        let payload = SalesReportPayload(
            transactionID: "full-access-transaction",
            productID: WSPProduct.fullAccess.rawValue,
            purchaseDate: Date(timeIntervalSince1970: 1_710_000_000),
            trialTransactionID: "trial-transaction",
            trialPurchaseDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
        )

        XCTAssertEqual(json["transactionID"] as? String, "full-access-transaction")
        XCTAssertEqual(json["productID"] as? String, WSPProduct.fullAccess.rawValue)
        XCTAssertEqual(json["purchaseDate"] as? Int, 1_710_000_000_000)
        XCTAssertEqual(json["trialTransactionID"] as? String, "trial-transaction")
        XCTAssertEqual(json["trialPurchaseDate"] as? Int, 1_700_000_000_000)
    }
}
