import Foundation
import Observation
import SwiftUI

@Observable
final class OperatorVideosService {
    private let maxSingleUploadBytes = 95 * 1024 * 1024
    private let defaultMultipartPartSizeBytes = 20 * 1024 * 1024

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

        guard let fileSize = fileSize(for: fileURL), fileSize > 0 else {
            errorMessage = "Could not read the selected file size"
            return
        }

        guard let url = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/tutorial-videos"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        components.queryItems = [URLQueryItem(name: "fileName", value: fileName)]
        guard let uploadURL = components.url else {
            errorMessage = "Invalid endpoint URL"
            return
        }

        do {
            let started = fileURL.startAccessingSecurityScopedResource()
            defer {
                if started {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            isUploading = true
            uploadProgress = 0
            isLoading = true
            errorMessage = nil
            defer {
                isUploading = false
                isLoading = false
            }

            if fileSize > Int64(maxSingleUploadBytes) {
                try await uploadMultipart(fileURL: fileURL, fileName: fileName, fileSize: fileSize, settings: settings)
                uploadProgress = 1
                return
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

            let delegate = UploadProgressDelegate { [weak self] progress in
                Task { @MainActor in
                    self?.uploadProgress = progress
                }
            }

            let (data, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL, delegate: delegate)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No server response"
                return
            }

            guard (200...299).contains(http.statusCode) else {
                errorMessage = uploadError(from: data, fallback: "Request failed (\(http.statusCode))").localizedDescription
                return
            }

            guard let payload = try? JSONDecoder().decode(OperatorUploadResponse.self, from: data), !payload.key.isEmpty else {
                errorMessage = "Upload completed but the server did not confirm the video key"
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

    private func uploadMultipart(fileURL: URL, fileName: String, fileSize: Int64, settings: OperatorSettingsStore) async throws {
        guard let baseURL = URL(string: settings.endpoint)?.appendingPathComponent("api/admin/tutorial-videos") else {
            throw URLError(.badURL)
        }

        guard let startURL = multipartURL(baseURL: baseURL, path: "multipart/start", key: nil, fileName: fileName) else {
            throw URLError(.badURL)
        }

        var startRequest = URLRequest(url: startURL)
        startRequest.httpMethod = "POST"
        startRequest.timeoutInterval = 300
        startRequest.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        startRequest.setValue(fileName, forHTTPHeaderField: "X-File-Name")

        let (startData, startResponse) = try await URLSession.shared.data(for: startRequest)
        guard let startHTTP = startResponse as? HTTPURLResponse, (200...299).contains(startHTTP.statusCode) else {
            throw uploadError(from: startData, fallback: "Failed to start multipart upload")
        }

        let startPayload = try JSONDecoder().decode(MultipartStartResponse.self, from: startData)
        let partSize = max(5 * 1024 * 1024, min(startPayload.partSizeBytes ?? defaultMultipartPartSizeBytes, maxSingleUploadBytes))

        var uploadedParts: [MultipartUploadedPart] = []
        var uploadedBytes: Int64 = 0

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }

        var partNumber = 1
        while uploadedBytes < fileSize {
            let bytesRemaining = fileSize - uploadedBytes
            let bytesToRead = Int(min(Int64(partSize), bytesRemaining))
            guard let chunk = try fileHandle.read(upToCount: bytesToRead), !chunk.isEmpty else {
                throw uploadError(message: "Could not read upload data")
            }

            guard let partURL = multipartURL(
                baseURL: baseURL,
                path: "multipart/\(startPayload.uploadId)/\(partNumber)",
                key: startPayload.key,
                fileName: nil
            ) else {
                throw URLError(.badURL)
            }

            var partRequest = URLRequest(url: partURL)
            partRequest.httpMethod = "PUT"
            partRequest.timeoutInterval = 300
            partRequest.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
            partRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            partRequest.httpBody = chunk

            let (partData, partResponse) = try await URLSession.shared.data(for: partRequest)
            guard let partHTTP = partResponse as? HTTPURLResponse, (200...299).contains(partHTTP.statusCode) else {
                try? await abortMultipartUpload(baseURL: baseURL, startPayload: startPayload, settings: settings)
                throw uploadError(from: partData, fallback: "Failed to upload multipart chunk")
            }

            let partPayload = try JSONDecoder().decode(MultipartPartResponse.self, from: partData)
            uploadedParts.append(MultipartUploadedPart(partNumber: partPayload.partNumber, etag: partPayload.etag))

            uploadedBytes += Int64(chunk.count)
            uploadProgress = min(max(Double(uploadedBytes) / Double(fileSize), 0), 1)
            partNumber += 1
        }

        let completeBody = MultipartCompleteRequest(
            key: startPayload.key,
            uploadId: startPayload.uploadId,
            parts: uploadedParts.sorted { $0.partNumber < $1.partNumber }
        )

        guard let completeURL = multipartURL(baseURL: baseURL, path: "multipart/complete", key: nil, fileName: nil) else {
            throw URLError(.badURL)
        }

        var completeRequest = URLRequest(url: completeURL)
        completeRequest.httpMethod = "POST"
        completeRequest.timeoutInterval = 300
        completeRequest.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        completeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        completeRequest.httpBody = try JSONEncoder().encode(completeBody)

        let (completeData, completeResponse) = try await URLSession.shared.data(for: completeRequest)
        guard let completeHTTP = completeResponse as? HTTPURLResponse, (200...299).contains(completeHTTP.statusCode) else {
            try? await abortMultipartUpload(baseURL: baseURL, startPayload: startPayload, settings: settings)
            throw uploadError(from: completeData, fallback: "Failed to complete multipart upload")
        }

        guard let payload = try? JSONDecoder().decode(OperatorUploadResponse.self, from: completeData), !payload.key.isEmpty else {
            throw uploadError(message: "Upload completed but the server did not confirm the video key")
        }
    }

    private func abortMultipartUpload(
        baseURL: URL,
        startPayload: MultipartStartResponse,
        settings: OperatorSettingsStore
    ) async throws {
        guard let abortURL = multipartURL(baseURL: baseURL, path: "multipart/abort", key: nil, fileName: nil) else {
            return
        }

        var request = URLRequest(url: abortURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(MultipartAbortRequest(key: startPayload.key, uploadId: startPayload.uploadId))

        _ = try await URLSession.shared.data(for: request)
    }

    private func multipartURL(baseURL: URL, path: String, key: String?, fileName: String?) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []

        if let key {
            items.append(URLQueryItem(name: "key", value: key))
        }

        if let fileName {
            items.append(URLQueryItem(name: "fileName", value: fileName))
        }

        components?.queryItems = items.isEmpty ? nil : items
        return components?.url
    }

    private func uploadError(from data: Data, fallback: String) -> NSError {
        if let payload = try? JSONDecoder().decode(OperatorErrorResponse.self, from: data),
           !payload.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return uploadError(message: payload.error)
        }
        return uploadError(message: fallback)
    }

    private func uploadError(message: String) -> NSError {
        NSError(domain: "OperatorVideosService", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func fileSize(for fileURL: URL) -> Int64? {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
        if let totalSize = values?.totalFileSize {
            return Int64(totalSize)
        }
        if let fileSize = values?.fileSize {
            return Int64(fileSize)
        }
        return nil
    }
}

private struct MultipartStartResponse: Decodable {
    let key: String
    let uploadId: String
    let partSizeBytes: Int?
}

private struct MultipartPartResponse: Decodable {
    let partNumber: Int
    let etag: String
}

private struct MultipartCompleteRequest: Encodable {
    let key: String
    let uploadId: String
    let parts: [MultipartUploadedPart]
}

private struct MultipartUploadedPart: Codable {
    let partNumber: Int
    let etag: String
}

private struct MultipartAbortRequest: Encodable {
    let key: String
    let uploadId: String
}

private struct OperatorUploadResponse: Decodable {
    let key: String
}

private struct OperatorErrorResponse: Decodable {
    let error: String
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
