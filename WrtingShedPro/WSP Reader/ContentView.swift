//
//  ContentView.swift
//  WSP Reader
//
//  Main content view - shows home screen or document reader.
//  Feature 026: WSP Reader App
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(ReaderAppState.self) var appState
    
    var body: some View {
        @Bindable var appState = appState
        #if targetEnvironment(macCatalyst)
        // On Catalyst: NavigationStack with push/pop gives a system back button
        // and a home screen that behaves like the iOS version.
        NavigationStack {
            HomeView()
                .navigationDestination(isPresented: Binding(
                    get: { appState.currentDocument != nil },
                    set: { if !$0 { appState.closeDocument() } }
                )) {
                    if let doc = appState.currentDocument {
                        DocumentReaderView(document: doc)
                    }
                }
        }
        .overlay {
            if appState.isLoadingDocument {
                loadingOverlay
            }
        }
        .alert(item: $appState.currentError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
        .onDrop(of: [.wspDocument, .fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        #else
        Group {
            if let document = appState.currentDocument {
                DocumentReaderView(document: document)
            } else {
                HomeView()
            }
        }
        .overlay {
            if appState.isLoadingDocument {
                loadingOverlay
            }
        }
        .fileImporter(
            isPresented: $appState.showFilePicker,
            allowedContentTypes: [.wspDocument, UTType(filenameExtension: "wsp") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            print("[WSPReader] fileImporter callback fired")
            DispatchQueue.main.async {
                switch result {
                case .success(let urls):
                    print("[WSPReader] picker success, urls: \(urls.count)")
                    guard let url = urls.first else {
                        print("[WSPReader] no URL in success result")
                        return
                    }
                    print("[WSPReader] opening: \(url.lastPathComponent) path=\(url.path)")
                    appState.openDocument(at: url)
                case .failure(let error):
                    let nsError = error as NSError
                    print("[WSPReader] picker failure: \(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription)")
                    guard !(nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError) else { return }
                    appState.currentError = ReaderError.openFailed(error.localizedDescription)
                }
            }
        }
        .alert(item: $appState.currentError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
        .onDrop(of: [.wspDocument, .fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        #endif
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Opening…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        // Try WSP document type first
        if provider.hasItemConformingToTypeIdentifier(UTType.wspDocument.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.wspDocument.identifier, options: nil) { item, error in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        appState.openDocument(at: url)
                    }
                }
            }
            return true
        }
        
        // Fall back to file URL
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   url.pathExtension.lowercased() == "wsp" {
                    DispatchQueue.main.async {
                        appState.openDocument(at: url)
                    }
                }
            }
            return true
        }
        
        return false
    }
}

// MARK: - Home View (Project Browser)

struct HomeView: View {
    @Environment(ReaderAppState.self) var appState
    @Environment(\.openURL) private var openURL
    @State private var homeMode: HomeMode = .openFiles

    var body: some View {
        #if targetEnvironment(macCatalyst)
        homeContent
        #else
        NavigationStack { homeContent }
        #endif
    }

    @ViewBuilder
    private var homeContent: some View {
        VStack(spacing: 0) {
            Picker("Home Mode", selection: $homeMode) {
                ForEach(HomeMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Group {
                switch homeMode {
                case .openFiles:
                    if appState.recentDocuments.isEmpty {
                        emptyState
                    } else {
                        projectList
                    }
                case .videos:
                    videoLinks
                case .samples:
                    sampleProjects
                }
            }
        }
        .navigationTitle("WSP Reader")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if homeMode == .openFiles {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appState.openFilePicker()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Open WSP Project")
                }
            }
        }
    }

    private var videoLinks: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("See How Writing Shed Pro Works")
                        .font(.headline)
                    Text("These short videos show real workflows in the full app. Open any project here, then explore these demos to see what you can create.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Video Walkthroughs") {
                ForEach(ReaderPromoVideo.all) { video in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.headline)
                        Text(video.commentary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            openURL(video.url)
                        } label: {
                            Label("Watch video", systemImage: "play.rectangle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brown)
                    }
                    .padding(.vertical, 6)
                }
            }

            Section {
                GetWSPButton()
            }
        }
        .listStyle(.insetGrouped)
    }

    private var sampleProjects: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sample Projects")
                        .font(.headline)
                    Text("Download ready-to-read WSP examples that demonstrate poetry forms, drama formatting, and fiction manuscripts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Available Samples") {
                ForEach(ReaderSampleProject.all) { sample in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sample.title)
                            .font(.headline)
                        Text(sample.commentary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            appState.openRemoteSample(named: sample.title, from: sample.url)
                        } label: {
                            Label("Open sample", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brown)
                    }
                    .padding(.vertical, 6)
                }
            }

            Section {
                GetWSPButton()
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundStyle(.brown)

            Text("No Projects")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Open a .wsp file exported from\nWriting Shed Pro to start reading.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            #if os(macOS)
            VStack(spacing: 8) {
                Text("Drop .wsp files here or use the + button")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
            #endif

            Button {
                appState.openFilePicker()
            } label: {
                Label("Open WSP File", systemImage: "doc.badge.plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)
            .padding(.top, 8)

            Spacer()

            GetWSPButton()
                .padding(.bottom, 24)
        }
        .padding()
    }

    // MARK: - Project List

    private var projectList: some View {
        List {
            Section {
                ForEach(appState.recentDocuments) { doc in
                    ProjectRow(document: doc)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.openRecentDocument(doc)
                        }
                }
                .onDelete { offsets in
                    appState.removeRecentDocuments(at: offsets)
                }
            } footer: {
                GetWSPButton()
                    .padding(.top, 16)
            }
        }
        .listStyle(.insetGrouped)
    }
}

private enum HomeMode: String, CaseIterable, Identifiable {
    case openFiles
    case videos
    case samples

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openFiles:
            return "Open Files"
        case .videos:
            return "Videos"
        case .samples:
            return "Samples"
        }
    }

    var systemImage: String {
        switch self {
        case .openFiles:
            return "doc.badge.plus"
        case .videos:
            return "play.rectangle"
        case .samples:
            return "shippingbox"
        }
    }
}

private struct ReaderPromoVideo: Identifiable {
    let id: String
    let title: String
    let commentary: String
    let url: URL

    static let all: [ReaderPromoVideo] = [
        ReaderPromoVideo(
            id: "introduction",
            title: "Writing Shed Pro Introduction",
            commentary: "A fast overview of the writing workspace, project types, and how everything stays organized while you draft.",
            url: URL(string: "https://wsp-support.wsp-support.workers.dev/tutorials/Introduction.mov")!
        ),
        ReaderPromoVideo(
            id: "quick-start-guide",
            title: "Quick Start Guide",
            commentary: "See the quickest path from creating a project to writing your first pages with ready-to-use defaults.",
            url: URL(string: "https://wsp-support.wsp-support.workers.dev/tutorials/QuickStart.mov")!
        ),
        ReaderPromoVideo(
            id: "tutorial-1",
            title: "First Poem Walkthrough",
            commentary: "A focused demo of poetry tools including structure support and editing flow in a real poem project.",
            url: URL(string: "https://wsp-support.wsp-support.workers.dev/tutorials/FirstPoem.mov")!
        ),
    ]
}

private struct ReaderSampleProject: Identifiable {
    let id: String
    let title: String
    let commentary: String
    let url: URL

    static let all: [ReaderSampleProject] = [
        ReaderSampleProject(
            id: "poetry-forms",
            title: "Poetry Forms",
            commentary: "A poetry project containing one poem for each supported poetry form.",
            url: URL(string: "https://wsp-support.wsp-support.workers.dev/samples/Poetry%20forms.wsp")!
        ),
        ReaderSampleProject(
            id: "a-play-for-today",
            title: "A Play for Today",
            commentary: "A short drama project demonstrating DML script formatting in context.",
            url: URL(string: "https://wsp-support.wsp-support.workers.dev/samples/A%20Play%20for%20Today.wsp")!
        ),
        ReaderSampleProject(
            id: "devils-triangle",
            title: "The Devil's Triangle",
            commentary: "A fiction project demonstrating novel structure and manuscript assembly.",
            url: URL(string: "https://wsp-support.wsp-support.workers.dev/samples/The%20Devil's%20Triangle.wsp")!
        ),
    ]
}

// MARK: - Project Row

struct ProjectRow: View {
    let document: RecentDocument

    var body: some View {
        HStack(spacing: 14) {
            // Project type icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(document.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(projectTypeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let count = document.fileCount, count > 0 {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("\(count) \(count == 1 ? "file" : "files")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch document.projectType {
        case "poetry":           return "text.quote"
        case "fiction":          return "book.closed"
        case "shortFiction":     return "doc.text"
        case "drama":            return "theatermasks"
        case "manual":           return "books.vertical"
        default:                 return "doc.richtext"
        }
    }

    private var iconBackground: Color {
        switch document.projectType {
        case "poetry":           return .purple
        case "fiction":          return .blue
        case "shortFiction":     return .teal
        case "drama":            return .orange
        case "manual":           return .indigo
        default:                 return .brown
        }
    }

    private var projectTypeLabel: String {
        switch document.projectType {
        case "poetry":           return "Poetry"
        case "fiction":          return "Fiction"
        case "shortFiction":     return "Short Fiction"
        case "drama":            return "Drama"
        case "manual":           return "Manual"
        case "prose":            return "Prose"
        default:                 return "Project"
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Opened \(formatter.localizedString(for: document.lastOpened, relativeTo: Date()))"
    }
}

// MARK: - Get WSP Button

struct GetWSPButton: View {
    var body: some View {
        Button {
            openAppStore()
        } label: {
            HStack {
                Image(systemName: "pencil.and.outline")
                    .foregroundStyle(.brown)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Get Writing Shed Pro")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("Create and manage your writing projects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func openAppStore() {
        if let url = URL(string: AppConstants.appStoreURL.absoluteString) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}
