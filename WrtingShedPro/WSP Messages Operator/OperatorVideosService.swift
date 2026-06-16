import Foundation
import Observation
import SwiftUI

@Observable
final class OperatorVideosService {
    var videos: [OperatorVideo] = []
    var isLoading = false
    var isUploading = false
    var isSavingOrder = false
    var uploadProgress: Double = 0
    var errorMessage: String?

    func fetch(settings: OperatorSettingsStore) async {
        guard let url = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/tutorial-videos") else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")

        await performRequestAndDecode(request)
    }

    func upload(fileURL: URL, settings: OperatorSettingsStore) async {
        let fileName = fileURL.lastPathComponent

        guard let encodedName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/tutorial-videos") else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        let uploadURL = URL(string: "\(url.absoluteString)?fileName=\(encodedName)") ?? url

        do {
            let started = fileURL.startAccessingSecurityScopedResource()
            defer {
                if started {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 300
            request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
            request.setValue(fileName, forHTTPHeaderField: "X-File-Name")
            if fileName.lowercased().hasSuffix(".mov") {
                request.setValue("video/quicktime", forHTTPHeaderField: "Content-Type")
            } else {
                request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
            }

            isUploading = true
            uploadProgress = 0
            isLoading = true
            errorMessage = nil
            defer {
                isUploading = false
                isLoading = false
            }

            let delegate = UploadProgressDelegate { [weak self] progress in
                Task { @MainActor in
                    self?.uploadProgress = progress
                }
            }

            let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL, delegate: delegate)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No server response"
                return
            }

            guard (200...299).contains(http.statusCode) else {
                errorMessage = "Request failed (\(http.statusCode))"
                return
            }

            uploadProgress = 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteVideo(key: String, settings: OperatorSettingsStore) async {
        guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/tutorial-videos/\(encodedKey)") else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")

        await performMutation(request)
    }

    func moveVideo(from source: IndexSet, to destination: Int) {
        videos.move(fromOffsets: source, toOffset: destination)
    }

    func saveOrder(settings: OperatorSettingsStore) async {
        guard let url = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/tutorial-videos/order") else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "orderedKeys": videos.map(\.key),
        ])

        isSavingOrder = true
        defer { isSavingOrder = false }

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

            let decoded = try JSONDecoder().decode(OperatorVideosResponse.self, from: data)
            videos = decoded.videos
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

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else {
            return
        }

        let progress = min(max(Double(totalBytesSent) / Double(totalBytesExpectedToSend), 0), 1)
        onProgress(progress)
    }
}
