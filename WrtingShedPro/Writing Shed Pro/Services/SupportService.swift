//
//  SupportService.swift
//  Writing Shed Pro
//
//  Submits support queries to the Cloudflare Worker proxy.
//  Feature 037: AI User Support
//

import Foundation
import Observation

@Observable
class SupportService {
    var isLoading = false
    var response: String?
    var errorMessage: String?

    // Cloudflare Worker endpoint
    private let endpoint = URL(string: "https://wsp-support.writingshedpro.workers.dev")!

    func submitQuery(reportType: String, subject: String, details: String,
                     stepsToReproduce: String, deviceInfo: String, appVersion: String,
                     diagnosticsSnapshot: String = "") async {
        isLoading = true
        response = nil
        errorMessage = nil

        var queryText = "\(subject)\n\n\(details)"
        if !stepsToReproduce.trimmingCharacters(in: .whitespaces).isEmpty {
            queryText += "\n\nSteps to reproduce:\n\(stepsToReproduce)"
        }

        // Enforce max length client-side as well
        if queryText.count > 2000 {
            queryText = String(queryText.prefix(2000))
        }

        let payload: [String: String] = [
            "query": queryText,
            "reportType": reportType,
            "deviceInfo": deviceInfo,
            "appVersion": appVersion,
            "diagnosticsSnapshot": diagnosticsSnapshot
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            errorMessage = NSLocalizedString("support.error.unavailable", comment: "")
            isLoading = false
            return
        }

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                errorMessage = NSLocalizedString("support.error.unavailable", comment: "")
                isLoading = false
                return
            }

            switch httpResponse.statusCode {
            case 200:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let aiResponse = json["response"] as? String {
                    response = aiResponse
                } else {
                    errorMessage = NSLocalizedString("support.error.unavailable", comment: "")
                }
            case 429:
                errorMessage = NSLocalizedString("support.error.rateLimit", comment: "")
            default:
                errorMessage = NSLocalizedString("support.error.unavailable", comment: "")
            }
        } catch {
            errorMessage = NSLocalizedString("support.error.unavailable", comment: "")
        }

        isLoading = false
    }
}
