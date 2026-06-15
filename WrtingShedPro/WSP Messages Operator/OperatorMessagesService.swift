import Foundation
import Observation

@Observable
final class OperatorMessagesService {
    var messages: [OperatorMessage] = []
    var isLoading = false
    var errorMessage: String?

    func fetch(includeArchived: Bool, settings: OperatorSettingsStore) async {
        guard let baseURL = URL(string: settings.endpoint) else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("api/admin/messages"), resolvingAgainstBaseURL: false)
        if includeArchived {
            components?.queryItems = [URLQueryItem(name: "includeArchived", value: "1")]
        }

        guard let url = components?.url else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")

        await performRequestAndDecode(request)
    }

    func create(title: String, body: String, settings: OperatorSettingsStore) async {
        guard let url = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/messages") else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = ["title": title, "body": body]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        await performMutation(request)
    }

    func update(_ message: OperatorMessage, settings: OperatorSettingsStore) async {
        guard let url = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/messages/\(message.id)") else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "title": message.title,
            "body": message.body,
            "isArchived": message.isArchived,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        await performMutation(request)
    }

    func archive(_ messageID: String, settings: OperatorSettingsStore) async {
        guard let url = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/messages/\(messageID)") else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 20
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")

        await performMutation(request)
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

            let decoded = try JSONDecoder().decode(OperatorMessagesResponse.self, from: data)
            messages = decoded.messages.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performMutation(_ request: URLRequest) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No server response"
                return
            }

            guard (200...299).contains(http.statusCode) else {
                errorMessage = "Request failed (\(http.statusCode))"
                return
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
