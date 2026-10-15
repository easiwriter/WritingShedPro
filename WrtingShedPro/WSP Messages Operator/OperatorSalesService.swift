import Foundation
import Observation

@Observable
final class OperatorSalesService {
    var months: [String] = []
    var selectedMonth: String = ""
    var sales: [OperatorSalesRecord] = []
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
              var components = URLComponents(url: baseURL.appendingPathComponent("api/admin/sales"), resolvingAgainstBaseURL: false) else {
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
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")

        await performRequestAndDecode(request)
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
            sales = decoded.sales
            verificationFailures = decoded.verificationFailures ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
