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
        Group {
            if let document = appState.currentDocument {
                DocumentReaderView(document: document)
            } else {
                HomeView()
            }
        }
        .fileImporter(
            isPresented: $appState.showFilePicker,
            allowedContentTypes: [.wspDocument, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Start accessing security-scoped resource
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        appState.openDocument(at: url)
                    } else {
                        appState.openDocument(at: url)
                    }
                }
            case .failure(let error):
                appState.currentError = ReaderError.openFailed(error.localizedDescription)
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

// MARK: - Home View

struct HomeView: View {
    @Environment(ReaderAppState.self) var appState
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // App icon
                Image(systemName: "book.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.brown)
                
                Text("WSP Reader")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Open and read Writing Shed Pro documents")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                #if os(macOS)
                // Drag and drop zone for macOS
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundStyle(.tertiary)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        
                        Text("Drop .wsp file here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 40)
                #endif
                
                // Open button
                Button {
                    appState.showFilePicker = true
                } label: {
                    Label("Open WSP Document", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
                
                Spacer()
                
                // Recent documents
                if !appState.recentDocuments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recent")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button("Clear") {
                                appState.clearRecentDocuments()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        ForEach(appState.recentDocuments) { doc in
                            RecentDocumentRow(document: doc)
                        }
                    }
                    .padding(.bottom, 24)
                }
                
                // Upgrade prompt
                UpgradePromptView()
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: 500)
            .padding()
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: ReaderSettingsView()) {
                        Image(systemName: "gear")
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Recent Document Row

struct RecentDocumentRow: View {
    @Environment(ReaderAppState.self) var appState
    let document: RecentDocument
    
    var body: some View {
        Button {
            appState.openRecentDocument(document)
        } label: {
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(.brown)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.name)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Opened \(formatter.localizedString(for: document.lastOpened, relativeTo: Date()))"
    }
}

// MARK: - Upgrade Prompt

struct UpgradePromptView: View {
    var body: some View {
        Button {
            openAppStore()
        } label: {
            HStack {
                Image(systemName: "pencil.and.outline")
                    .foregroundStyle(.brown)
                
                Text("Get Writing Shed Pro")
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    private func openAppStore() {
        // Open App Store link to Writing Shed Pro
        // Replace with actual App Store URL when available
        if let url = URL(string: "https://apps.apple.com/app/writing-shed-pro/id0000000000") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}
