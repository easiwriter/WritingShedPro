import Foundation
import Observation

@Observable
final class OperatorSalesService {
    var selectedRange: OperatorSalesRange = .fiveWeeks
    var sales: [OperatorSalesRecord] = []
    var appleSales: [OperatorAppleSalesRecord] = []
    var appDownloads: [OperatorAppDownloadRecord] = []
    var appleSalesStatus: OperatorAppleSalesStatus?
    var trialMetrics: OperatorTrialMetrics?
    var verificationFailures: [OperatorVerificationFailure] = []
    var isLoading = false
    var errorMessage: String?

    var sortedSales: [OperatorSalesRecord] {
        sales.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.displayName < rhs.displayName
        }
    }

    var totalSales: Int {
        sales.reduce(0) { $0 + $1.count }
    }

    var totalApplePurchases: Int {
        appleSales.reduce(0) { $0 + $1.purchases }
    }

    var totalAppleRefunds: Int {
        appleSales.reduce(0) { $0 + $1.refunds }
    }

    var totalAppleNetPurchases: Int {
        totalApplePurchases - totalAppleRefunds
    }

    var totalAppDownloads: Int {
        appDownloads.reduce(0) { $0 + $1.downloads }
    }

    var totalFullAccessSales: Int {
        sales.reduce(0) { total, sale in
            switch sale.projectType {
            case "convertedTrial", "fullAccess":
                return total + sale.count
            default:
                return total
            }
        }
    }

    var hasFullAccessCohortData: Bool {
        sales.contains { sale in
            switch sale.projectType {
            case "trial", "convertedTrial", "fullAccess":
                return true
            default:
                return false
            }
        }
    }

    func fetch(range: OperatorSalesRange? = nil, settings: OperatorSettingsStore) async {
        guard let baseURL = URL(string: settings.endpoint),
              var components = URLComponents(
                url: baseURL.appendingPathComponent("api/admin/sales"),
                resolvingAgainstBaseURL: false
              ) else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        components.queryItems = [
            URLQueryItem(name: "range", value: (range ?? selectedRange).rawValue)
        ]

        guard let url = components.url else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        authorize(&request, token: settings.token)
        await performRequestAndDecode(request)
    }

    func clearVerificationFailures(settings: OperatorSettingsStore) async {
        guard let baseURL = URL(string: settings.endpoint) else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(
            url: baseURL.appendingPathComponent("api/admin/sales/verification-failures")
        )
        request.httpMethod = "DELETE"
        request.timeoutInterval = 20
        authorize(&request, token: settings.token)

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No server response"
                return
            }
            guard http.statusCode == 200 else {
                errorMessage = "Request failed (\(http.statusCode))"
                return
            }

            let decoded = try JSONDecoder().decode(
                OperatorClearVerificationFailuresResponse.self,
                from: data
            )
            guard decoded.ok else {
                errorMessage = "The service did not clear verification diagnostics"
                return
            }
            verificationFailures = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncAppleSales(settings: OperatorSettingsStore) async {
        guard let baseURL = URL(string: settings.endpoint),
              let baseComponents = URLComponents(
                url: baseURL.appendingPathComponent("api/admin/sales/apple-sync"),
                resolvingAgainstBaseURL: false
              ) else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        isLoading = true
        errorMessage = nil
        var cursor: String?
        var seenCursors = Set<String>()

        do {
            repeat {
                var components = baseComponents
                components.queryItems = [
                    URLQueryItem(name: "range", value: selectedRange.rawValue)
                ]
                if let cursor {
                    guard seenCursors.insert(cursor).inserted else {
                        errorMessage = "Apple sales sync returned a repeated cursor"
                        isLoading = false
                        return
                    }
                    components.queryItems?.append(
                        URLQueryItem(name: "cursor", value: cursor)
                    )
                }

                guard let url = components.url else {
                    errorMessage = "Invalid endpoint URL"
                    isLoading = false
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 120
                authorize(&request, token: settings.token)

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    errorMessage = "No server response"
                    isLoading = false
                    return
                }
                guard http.statusCode == 200 else {
                    if let serviceError = try? JSONDecoder().decode(
                        OperatorSalesServiceError.self,
                        from: data
                    ) {
                        errorMessage = serviceError.error
                    } else if http.statusCode == 401 {
                        errorMessage = "Operator authorization failed. Check the Admin API Token."
                    } else {
                        errorMessage = "Apple sales sync failed (\(http.statusCode))"
                    }
                    isLoading = false
                    return
                }

                let decoded = try JSONDecoder().decode(
                    OperatorAppleSalesSyncResponse.self,
                    from: data
                )
                guard decoded.ok else {
                    errorMessage = "The service did not sync Apple sales reports"
                    isLoading = false
                    return
                }
                cursor = decoded.nextCursor
            } while cursor != nil

            isLoading = false
            await fetch(range: selectedRange, settings: settings)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private struct OperatorSalesServiceError: Decodable {
        let error: String
    }

    private func authorize(_ request: inout URLRequest, token: String) {
        request.setValue(
            ["Bearer", token].joined(separator: " "),
            forHTTPHeaderField: "Authorization"
        )
    }

    private func performRequestAndDecode(_ request: URLRequest) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No server response"
                return
            }

            guard http.statusCode == 200 else {
                errorMessage = "Request failed (\(http.statusCode))"
                return
            }

            let decoded = try JSONDecoder().decode(OperatorSalesResponse.self, from: data)
            guard let responseRange = OperatorSalesRange(rawValue: decoded.selectedRange) else {
                errorMessage = "The service returned an unsupported sales range"
                return
            }
            selectedRange = responseRange
            sales = decoded.deviceReportedSales ?? decoded.sales
            appleSales = decoded.appleSales ?? []
            appDownloads = decoded.appDownloads ?? []
            appleSalesStatus = decoded.appleSalesStatus
            trialMetrics = decoded.trialMetrics
            verificationFailures = decoded.verificationFailures ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
