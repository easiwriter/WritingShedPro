//
//  WSPReaderApp.swift
//  WSP Reader
//
//  A free, standalone app that opens and displays WSP documents in read-only mode.
//  Feature 026: WSP Reader App
//

import SwiftUI
import UniformTypeIdentifiers
import Observation

@main
struct WSPReaderApp: App {
    @State private var appState = ReaderAppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    // Handle file opened from Files, Mail, Safari, etc.
                    if url.pathExtension.lowercased() == "wsp" {
                        appState.openDocument(at: url)
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    appState.showFilePicker = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("Close Document") {
                    appState.closeDocument()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.currentDocument == nil)
            }
        }
        
        #if os(macOS)
        Settings {
            ReaderSettingsView()
                .environment(appState)
        }
        #endif
    }
}

// MARK: - App State

/// Global app state for the WSP Reader
@Observable
class ReaderAppState {
    /// Currently open document
    var currentDocument: WSPDocument?
    
    /// Recently opened documents
    var recentDocuments: [RecentDocument] = []
    
    /// Show file picker sheet
    var showFilePicker: Bool = false
    
    /// Current font size for reading
    var fontSize: CGFloat = 16
    
    /// Current theme
    var theme: ReaderTheme = .system
    
    /// Error to display
    var currentError: ReaderError?
    
    /// Show upgrade to pro prompt
    var showUpgradePrompt: Bool = false
    
    init() {
        loadRecentDocuments()
    }
    
    // MARK: - Recent Documents
    
    private var recentDocumentsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WSPReader")
            .appendingPathComponent("RecentDocuments.json")
    }
    
    func loadRecentDocuments() {
        do {
            let directory = recentDocumentsURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            
            if FileManager.default.fileExists(atPath: recentDocumentsURL.path) {
                let data = try Data(contentsOf: recentDocumentsURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                recentDocuments = try decoder.decode([RecentDocument].self, from: data)
                
                // Filter out documents that no longer exist
                recentDocuments = recentDocuments.filter { doc in
                    if let bookmark = doc.bookmark {
                        var isStale = false
                        if let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) {
                            return FileManager.default.fileExists(atPath: url.path)
                        }
                    }
                    return false
                }
            }
        } catch {
            #if DEBUG
            print("[WSPReader] Failed to load recent documents: \(error)")
            #endif
        }
    }
    
    func saveRecentDocuments() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(recentDocuments)
            try data.write(to: recentDocumentsURL)
        } catch {
            #if DEBUG
            print("[WSPReader] Failed to save recent documents: \(error)")
            #endif
        }
    }
    
    func addRecentDocument(url: URL, name: String) {
        // Remove existing entry for same URL
        recentDocuments.removeAll { $0.name == name }
        
        // Create security-scoped bookmark
        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            let recent = RecentDocument(
                name: name,
                bookmark: bookmark,
                lastOpened: Date()
            )
            
            recentDocuments.insert(recent, at: 0)
            
            // Keep only last 10
            if recentDocuments.count > 10 {
                recentDocuments = Array(recentDocuments.prefix(10))
            }
            
            saveRecentDocuments()
        } catch {
            #if DEBUG
            print("[WSPReader] Failed to create bookmark: \(error)")
            #endif
        }
    }
    
    func clearRecentDocuments() {
        recentDocuments = []
        saveRecentDocuments()
    }
    
    // MARK: - Document Opening
    
    func openDocument(at url: URL) {
        do {
            let document = try WSPDocument(url: url)
            currentDocument = document
            addRecentDocument(url: url, name: document.projectName)
        } catch {
            currentError = ReaderError.openFailed(error.localizedDescription)
        }
    }
    
    func openRecentDocument(_ recent: RecentDocument) {
        guard let bookmark = recent.bookmark else { return }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // Bookmark is stale, remove from recents
                recentDocuments.removeAll { $0.name == recent.name }
                saveRecentDocuments()
                currentError = ReaderError.documentNotFound
                return
            }
            
            openDocument(at: url)
        } catch {
            currentError = ReaderError.openFailed(error.localizedDescription)
        }
    }
    
    func closeDocument() {
        currentDocument = nil
    }
}

// MARK: - Supporting Types

struct RecentDocument: Codable, Identifiable {
    var id: String { name }
    let name: String
    let bookmark: Data?
    let lastOpened: Date
}

enum ReaderTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case sepia = "Sepia"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .sepia: return .light
        }
    }
}

enum ReaderError: LocalizedError, Identifiable {
    case openFailed(String)
    case documentNotFound
    case invalidFormat
    case parsingError(String)
    
    var id: String { localizedDescription }
    
    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "Failed to open document: \(message)"
        case .documentNotFound:
            return "Document not found. It may have been moved or deleted."
        case .invalidFormat:
            return "Invalid WSP file format."
        case .parsingError(let message):
            return "Error parsing document: \(message)"
        }
    }
}

// MARK: - UTType Extension

extension UTType {
    static var wspDocument: UTType {
        UTType(exportedAs: "com.writing-shed.wsp")
    }
}
