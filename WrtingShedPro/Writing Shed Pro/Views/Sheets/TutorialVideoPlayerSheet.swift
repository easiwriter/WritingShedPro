import SwiftUI
import AVKit
#if os(iOS) || targetEnvironment(macCatalyst)
import AVFoundation
#endif
#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

struct TutorialVideo: Identifiable, Equatable {
    let id: String
    let title: String
    let expectedFileName: String
    let expectedFileExtension: String

    var expectedBundleFile: String {
        "\(expectedFileName).\(expectedFileExtension)"
    }
}

enum TutorialVideoCatalog {
    static let writingShedProReel = TutorialVideo(
        id: "introduction",
        title: "Writing Shed Pro Introduction",
        expectedFileName: "Introduction",
        expectedFileExtension: "mov"
    )

    static let tutorial1 = TutorialVideo(
        id: "tutorial-1",
        title: "Tutorial 1",
        expectedFileName: "FirstPoem",
        expectedFileExtension: "mov"
    )

    static let quickStartGuide = TutorialVideo(
        id: "quick-start-guide",
        title: "Quick Start Guide",
        expectedFileName: "QuickStart",
        expectedFileExtension: "mov"
    )

    static func video(for id: String) -> TutorialVideo? {
        switch id {
        case writingShedProReel.id:
            return writingShedProReel
        case quickStartGuide.id:
            return quickStartGuide
        case tutorial1.id:
            return tutorial1
        default:
            return nil
        }
    }
}

struct TutorialVideoPlayerSheet: View {
    let video: TutorialVideo
    private let remoteBaseURLDefaultsKey = "tutorialVideoBaseURL"
    private let fallbackRemoteBaseURLString = "https://wsp-support.wsp-support.workers.dev"
    private let legacyRemoteBaseURLHost = "wsp-support.writingshedpro.workers.dev"
    private let canonicalRemoteBaseURLHost = "wsp-support.wsp-support.workers.dev"

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var videoAspectRatio: CGFloat = 9.0 / 16.0

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let player {
                        let playerSize = playerFrameSize(in: proxy.size)

                        TutorialVideoPlayerView(player: player)
                            .frame(width: playerSize.width, height: playerSize.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onAppear {
                                #if DEBUG
                                logDebugPlayerLayout(containerSize: proxy.size, playerSize: playerSize)
                                #endif
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                            }
                    } else {
                        ContentUnavailableView {
                            Label("Video Temporarily Unavailable", systemImage: "film")
                        } description: {
                            Text("This tutorial video is temporarily unavailable. Please try again later.")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle(video.title)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            #if os(iOS)
            configureAudioSessionForPlayback()
            #endif
            if player == nil {
                if let remoteURL = remoteVideoURL() {
                    player = AVPlayer(url: remoteURL)

                    Task {
                        let detectedAspectRatio = await extractVideoAspectRatio(from: remoteURL)
                        if let detectedAspectRatio {
                            await MainActor.run {
                                videoAspectRatio = detectedAspectRatio
                            }
                        }
                        #if DEBUG
                        logDebugVideoSetup(url: remoteURL, detectedAspectRatio: detectedAspectRatio)
                        #endif
                    }
                }
            }
        }
    }

    #if os(iOS)
    private func configureAudioSessionForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("⚠️ [TutorialVideo] Failed to configure audio session: \(error)")
            #endif
        }
    }
    #endif

    private func playerFrameSize(in containerSize: CGSize) -> CGSize {
        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 8

        let availableWidth = max(120, containerSize.width - (horizontalPadding * 2))
        let availableHeight = max(200, containerSize.height - (verticalPadding * 2))

        var width = availableWidth
        var height = width / videoAspectRatio

        if height > availableHeight {
            height = availableHeight
            width = height * videoAspectRatio
        }

        return CGSize(width: width, height: height)
    }

    private func extractVideoAspectRatio(from url: URL) async -> CGFloat? {
        let asset = AVURLAsset(url: url)

        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return nil
            }

            let naturalSize = try await track.load(.naturalSize)
            let preferredTransform = try await track.load(.preferredTransform)
            let transformedSize = naturalSize.applying(preferredTransform)
            let width = abs(transformedSize.width)
            let height = abs(transformedSize.height)
            guard width > 0, height > 0 else {
                return nil
            }

            return width / height
        } catch {
            return nil
        }
    }

    #if DEBUG
    private func logDebugVideoSetup(url: URL, detectedAspectRatio: CGFloat?) {
        let ratioText = detectedAspectRatio.map { String(format: "%.4f", $0) } ?? "unavailable (using fallback)"
        print("[TutorialVideo] Source: \(url.lastPathComponent), aspectRatio: \(ratioText)")
    }

    private func logDebugPlayerLayout(containerSize: CGSize, playerSize: CGSize) {
        let ratioText = String(format: "%.4f", videoAspectRatio)
        print(
            "[TutorialVideo] Layout container=\(Int(containerSize.width))x\(Int(containerSize.height)) " +
            "player=\(Int(playerSize.width))x\(Int(playerSize.height)) ratio=\(ratioText)"
        )
    }
    #endif

    private func remoteVideoURL() -> URL? {
        for base in configuredRemoteBaseURLs() {
            let candidate = base
                .appendingPathComponent("tutorials", isDirectory: true)
                .appendingPathComponent(video.expectedBundleFile)
            if let scheme = candidate.scheme?.lowercased(), scheme == "https" || scheme == "http" {
                return candidate
            }
        }
        return nil
    }

    private func configuredRemoteBaseURLs() -> [URL] {
        var candidates: [String] = []

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "TutorialVideoBaseURL") as? String {
            candidates.append(plistValue)
        }

        if let defaultsValue = UserDefaults.standard.string(forKey: remoteBaseURLDefaultsKey) {
            candidates.append(defaultsValue)
        }

        candidates.append(fallbackRemoteBaseURLString)

        var urls: [URL] = []
        var seen: Set<String> = []

        for rawCandidate in candidates {
            let trimmed = rawCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
                continue
            }

            if components.host?.lowercased() == legacyRemoteBaseURLHost {
                components.host = canonicalRemoteBaseURLHost
            }

            guard let url = components.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                continue
            }

            let key = url.absoluteString
            if !seen.contains(key) {
                seen.insert(key)
                urls.append(url)
            }
        }

        return urls
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
private struct TutorialVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.videoGravity = .resizeAspect
    }
}
#else
private struct TutorialVideoPlayerView: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
    }
}
#endif
