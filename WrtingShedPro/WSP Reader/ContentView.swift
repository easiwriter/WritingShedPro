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
    @State private var showHelp = false

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
        .sheet(isPresented: $showHelp) { ReaderHelpView() }
        .onReceive(NotificationCenter.default.publisher(for: .wspReaderShowHelp)) { _ in showHelp = true }
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
        .sheet(isPresented: $showHelp) { ReaderHelpView() }
        .onReceive(NotificationCenter.default.publisher(for: .wspReaderShowHelp)) { _ in showHelp = true }
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

    var body: some View {
        #if targetEnvironment(macCatalyst)
        homeContent
        #else
        NavigationStack { homeContent }
        #endif
    }

    @ViewBuilder
    private var homeContent: some View {
        Group {
            if appState.recentDocuments.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("WSP Reader")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            #if !targetEnvironment(macCatalyst)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    NotificationCenter.default.post(name: .wspReaderShowHelp, object: nil)
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("WSP Reader Help")
            }
            #endif
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
            }
        }
        .listStyle(.insetGrouped)
    }
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

