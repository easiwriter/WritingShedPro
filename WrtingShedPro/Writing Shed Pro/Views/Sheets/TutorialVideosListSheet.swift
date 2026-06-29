import SwiftUI

struct RemoteTutorialVideo: Identifiable, Codable, Equatable {
    let id: String
    let key: String
    let title: String
    let fileName: String
    let fileExtension: String
    let size: Int?
    let updatedAt: TimeInterval?

    var tutorialVideo: TutorialVideo {
        TutorialVideo(
            id: id,
            title: title,
            expectedFileName: fileName,
            expectedFileExtension: fileExtension
        )
    }
}

private struct RemoteTutorialVideosResponse: Codable {
    let videos: [RemoteTutorialVideo]
}

@MainActor
final class TutorialVideosService: ObservableObject {
    @Published var isLoading = false
    @Published var videos: [RemoteTutorialVideo] = []
    @Published var errorMessage: String?

    func fetchVideos() async {
        guard let endpoint = tutorialVideosEndpoint() else {
            errorMessage = NSLocalizedString("guide.tutorialVideos.error.unavailable", comment: "")
            return
        }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = NSLocalizedString("guide.tutorialVideos.error.unavailable", comment: "")
                isLoading = false
                return
            }

            let decoded = try JSONDecoder().decode(RemoteTutorialVideosResponse.self, from: data)
            videos = decoded.videos
        } catch {
            errorMessage = NSLocalizedString("guide.tutorialVideos.error.unavailable", comment: "")
        }

        isLoading = false
    }

    private func tutorialVideosEndpoint() -> URL? {
        let fallback = "https://wsp-support.wsp-support.workers.dev"
        let legacyHost = "wsp-support.writingshedpro.workers.dev"
        let canonicalHost = "wsp-support.wsp-support.workers.dev"

        var candidates: [String] = []

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "TutorialVideoBaseURL") as? String {
            candidates.append(plistValue)
        }

        if let defaultsValue = UserDefaults.standard.string(forKey: "tutorialVideoBaseURL") {
            candidates.append(defaultsValue)
        }

        candidates.append(fallback)

        for raw in candidates {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
                continue
            }

            if components.host?.lowercased() == legacyHost {
                components.host = canonicalHost
            }

            guard let baseURL = components.url,
                  let scheme = baseURL.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                continue
            }

            return baseURL.appendingPathComponent("api/tutorial-videos")
        }

        return nil
    }
}

struct TutorialVideosListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = TutorialVideosService()
    let onSelectVideo: (TutorialVideo) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading && service.videos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.videos.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("guide.tutorialVideos.empty.title", comment: ""),
                        systemImage: "film",
                        description: Text(NSLocalizedString("guide.tutorialVideos.empty.body", comment: ""))
                    )
                } else {
                    List(service.videos) { video in
                        Button {
                            dismiss()
                            onSelectVideo(video.tutorialVideo)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title)
                                    .font(.headline)
                                if let updatedAt = video.updatedAt {
                                    Text(relativeDateText(from: updatedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(NSLocalizedString("guide.tutorialVideos.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.done", comment: "")) {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await service.fetchVideos()
            }
            .task {
                await service.fetchVideos()
            }
            .alert(
                NSLocalizedString("guide.tutorialVideos.error.title", comment: ""),
                isPresented: Binding(
                    get: { service.errorMessage != nil },
                    set: { if !$0 { service.errorMessage = nil } }
                )
            ) {
                Button(NSLocalizedString("common.ok", comment: ""), role: .cancel) {
                    service.errorMessage = nil
                }
            } message: {
                Text(service.errorMessage ?? "")
            }
        }
    }

    private func relativeDateText(from timestampMs: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestampMs / 1000.0)
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}
