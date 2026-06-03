import SwiftUI
import AVKit
#if os(iOS)
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
    private let portraitAspectRatio: CGFloat = 9.0 / 16.0

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
                player = makePlayerIfAvailable()
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
        var height = width / portraitAspectRatio

        if height > availableHeight {
            height = availableHeight
            width = height * portraitAspectRatio
        }

        return CGSize(width: width, height: height)
    }

    private func makePlayerIfAvailable() -> AVPlayer? {
        if let remoteURL = remoteVideoURL() {
            return AVPlayer(url: remoteURL)
        }

        return nil
    }

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
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.videoGravity = .resizeAspectFill
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
