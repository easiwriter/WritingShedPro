import Foundation
import Observation

@Observable
final class OperatorSalesService {
    var months: [String] = []
    var selectedMonth: String = ""
    var sales: [OperatorSalesRecord] = []
    var appleSales: [OperatorAppleSalesRecord] = []
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

    func fetch(month: String?, settings: OperatorSettingsStore) async {
        guard let baseURL = URL(string: settings.endpoint),
              var components = URLComponents(
                url: baseURL.appendingPathComponent("api/admin/sales"),
                resolvingAgainstBaseURL: false
              ) else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        if let month, !month.isEmpty {
            components.queryItems = [URLQueryItem(name: "month", value: month)]
        }

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
        guard !selectedMonth.isEmpty,
              let baseURL = URL(string: settings.endpoint),
              var components = URLComponents(
                url: baseURL.appendingPathComponent("api/admin/sales/apple-sync"),
                resolvingAgainstBaseURL: false
              ) else {
            errorMessage = "Invalid endpoint URL"
            return
        }
        components.queryItems = [URLQueryItem(name: "month", value: selectedMonth)]
        guard let url = components.url else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        authorize(&request, token: settings.token)

        isLoading = true
        errorMessage = nil
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No server response"
                isLoading = false
                return
            }
            guard http.statusCode == 200 else {
                errorMessage = http.statusCode == 503
                    ? "Apple Sales and Trends credentials are not configured"
                    : "Apple sales sync failed (\(http.statusCode))"
                isLoading = false
                return
            }
            isLoading = false
            await fetch(month: selectedMonth, settings: settings)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
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
            months = decoded.months
            selectedMonth = decoded.selectedMonth
            sales = decoded.deviceReportedSales ?? decoded.sales
            appleSales = decoded.appleSales ?? []
            appleSalesStatus = decoded.appleSalesStatus
            trialMetrics = decoded.trialMetrics
            verificationFailures = decoded.verificationFailures ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
