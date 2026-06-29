//
//  ReaderAppState.swift
//  WSP Reader
//
//  Global app state for the WSP Reader
//  Feature 026: WSP Reader App
//

import Foundation
import SwiftUI
import Observation
import UniformTypeIdentifiers
import UIKit

/// Global app state for the WSP Reader
@Observable
class ReaderAppState {
    /// Currently open document
    var currentDocument: WSPDocument?
    
    /// Recently opened documents
    var recentDocuments: [RecentDocument] = []
    
    /// Show file picker sheet (iOS only — Catalyst uses NSOpenPanel directly)
    var showFilePicker: Bool = false
    
    /// Current font size for reading
    var fontSize: CGFloat = 16
    
    /// Current theme
    var theme: ReaderTheme = .system
    
    /// Error to display
    var currentError: ReaderError?

    /// Shared zoom scale for reader previews so pinch state carries between files.
    var readerContentScale: CGFloat = 1.0

    /// Last selected file per opened document so Catalyst can restore file context after navigation.
    var readerLastSelectedFileIDByDocumentPath: [String: String] = [:]

    /// Show upgrade to pro prompt
    var showUpgradePrompt: Bool = false

    /// Author name used when adding reader comments
    var readerAuthorName: String {
        get { UserDefaults.standard.string(forKey: "WSPReaderAuthorName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "WSPReaderAuthorName") }
    }

    /// All locally stored reader comments (across all documents)
    var localComments: [ReaderLocalComment] = []
    
    init() {
        loadRecentDocuments()
        loadLocalComments()
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
                
                // Filter out entries with no bookmark or whose file no longer exists
                recentDocuments = recentDocuments.filter { doc in
                    guard let bookmark = doc.bookmark else { return false }
                    var isStale = false
                    if let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) {
                        return FileManager.default.fileExists(atPath: url.path)
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
    
    func addRecentDocument(url: URL, name: String, projectType: String? = nil, fileCount: Int? = nil, preCreatedBookmark: Data? = nil) {
        recentDocuments.removeAll { $0.name == name }

        // Use a pre-created bookmark when available (created while security scope is active).
        // Fall back to creating one here for callers that don't pre-create (e.g. registerDocument).
        var bookmark: Data? = preCreatedBookmark
        if bookmark == nil {
            do {
                #if targetEnvironment(macCatalyst)
                bookmark = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                #else
                bookmark = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                #endif
            } catch {
                print("[WSPReader] bookmark creation failed (item added without bookmark): \(error)")
            }
        }

        let recent = RecentDocument(
            name: name,
            bookmark: bookmark,
            lastOpened: Date(),
            projectType: projectType,
            fileCount: fileCount
        )
        recentDocuments.insert(recent, at: 0)

        if recentDocuments.count > 10 {
            recentDocuments = Array(recentDocuments.prefix(10))
        }

        saveRecentDocuments()
    }
    
    func clearRecentDocuments() {
        recentDocuments = []
        saveRecentDocuments()
    }

    // MARK: - Local Comments

    private var localCommentsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WSPReader")
            .appendingPathComponent("LocalComments.json")
    }

    func loadLocalComments() {
        do {
            guard FileManager.default.fileExists(atPath: localCommentsURL.path) else { return }
            let data = try Data(contentsOf: localCommentsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            localComments = try decoder.decode([ReaderLocalComment].self, from: data)
        } catch {
            print("[WSPReader] Failed to load local comments: \(error)")
        }
    }

    func saveLocalComments() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(localComments)
            try data.write(to: localCommentsURL)
        } catch {
            print("[WSPReader] Failed to save local comments: \(error)")
        }
    }

    func localComments(forFileID fileID: String, versionID: String, documentName: String) -> [ReaderLocalComment] {
        localComments.filter {
            $0.fileID == fileID && $0.versionID == versionID && $0.documentName == documentName
        }
    }

    func addLocalComment(_ comment: ReaderLocalComment) {
        localComments.append(comment)
        saveLocalComments()
    }

    func deleteLocalComment(id: String) {
        localComments.removeAll { $0.id == id }
        saveLocalComments()
    }

    func hasLocalComments(forDocument documentName: String) -> Bool {
        localComments.contains { $0.documentName == documentName }
    }
    
    /// Whether a document is currently being loaded
    var isLoadingDocument: Bool = false

    func openDocument(at url: URL) {
        print("[WSPReader] openDocument: \(url.lastPathComponent)")
        isLoadingDocument = true
        // JSON parsing + base64 decode are CPU-heavy — do them off the main thread
        // so the UI remains responsive while loading.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let gotAccess = url.startAccessingSecurityScopedResource()
            if gotAccess {
                print("[WSPReader] security scope granted for \(url.lastPathComponent)")
            }
            defer {
                if gotAccess { url.stopAccessingSecurityScopedResource() }
            }

            do {
                let document = try WSPDocument(url: url)
                print("[WSPReader] parsed OK — project='\(document.projectName)' folders=\(document.folders.count) files=\(document.allFiles.count)")

                // Create the bookmark NOW, while security scope is still active.
                // The defer below stops scope when this block exits — before the
                // main-thread async runs — so creating it here is the only safe point.
                var bookmarkData: Data? = nil
                do {
                    #if targetEnvironment(macCatalyst)
                    bookmarkData = try url.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    #else
                    bookmarkData = try url.bookmarkData(
                        options: .minimalBookmark,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    #endif
                } catch {
                    print("[WSPReader] bookmark creation failed: \(error)")
                }

                DispatchQueue.main.async {
                    self?.currentDocument = document
                    self?.isLoadingDocument = false
                    self?.addRecentDocument(
                        url: url,
                        name: document.projectName,
                        projectType: document.projectType,
                        fileCount: document.allFiles.count,
                        preCreatedBookmark: bookmarkData
                    )
                }
            } catch {
                print("[WSPReader] openDocument FAILED: \(error)")
                DispatchQueue.main.async {
                    self?.isLoadingDocument = false
                    self?.currentError = ReaderError.openFailed(error.localizedDescription)
                }
            }
        }
    }

    /// Partially parse a WSP file to register it as a recent project without opening it.
    func registerDocument(at url: URL) {
        do {
            let document = try WSPDocument(url: url)
            addRecentDocument(
                url: url,
                name: document.projectName,
                projectType: document.projectType,
                fileCount: document.allFiles.count
            )
        } catch {
            // Silently ignore registration errors — the file will open with a proper error later
        }
    }

    func removeRecentDocuments(at offsets: IndexSet) {
        recentDocuments.remove(atOffsets: offsets)
        saveRecentDocuments()
    }
    
    func openRecentDocument(_ recent: RecentDocument) {
        guard let bookmark = recent.bookmark else {
            currentError = ReaderError.documentNotFound
            return
        }

        do {
            var isStale = false
            #if targetEnvironment(macCatalyst)
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #else
            let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            #endif

            if isStale {
                recentDocuments.removeAll { $0.name == recent.name }
                saveRecentDocuments()
                currentError = ReaderError.documentNotFound
                return
            }
            openDocument(at: url)
        } catch {
            print("[WSPReader] openRecentDocument failed: \(error)")
            currentError = ReaderError.openFailed(error.localizedDescription)
        }
    }
    
    func closeDocument() {
        currentDocument = nil
    }

    func readerSelectionFileID(for document: WSPDocument) -> String? {
        readerLastSelectedFileIDByDocumentPath[document.fileURL.path]
    }

    func storeReaderSelection(fileID: String?, for document: WSPDocument) {
        let key = document.fileURL.path
        if let fileID {
            readerLastSelectedFileIDByDocumentPath[key] = fileID
        } else {
            readerLastSelectedFileIDByDocumentPath.removeValue(forKey: key)
        }
    }

    // MARK: - File Picker

    /// Opens a file picker.
    /// On Catalyst: calls NSOpenPanel directly via AppKit (in-process) to avoid the
    /// ViewBridge Code=18 disconnect that affects both .fileImporter and
    /// UIDocumentPickerViewController on Catalyst.
    func openFilePicker() {
        #if targetEnvironment(macCatalyst)
        CatalystFilePicker.open(allowedTypes: [UTType(filenameExtension: "wsp") ?? .data]) { [weak self] url in
            guard let self, let url else {
                print("[WSPReader] NSOpenPanel: cancelled or no URL")
                return
            }
            print("[WSPReader] NSOpenPanel selected: \(url.lastPathComponent)")
            self.openDocument(at: url)
        }
        #else
        showFilePicker = true
        #endif
    }
}

// MARK: - Supporting Types

// MARK: - Reader Local Comment

struct ReaderLocalComment: Codable, Identifiable {
    var id: String = UUID().uuidString
    var text: String
    var author: String
    /// ID of the WSPReaderVersion this comment belongs to
    var versionID: String
    /// ID of the WSPReaderFile this comment belongs to
    var fileID: String
    /// Project name used to scope comments to a specific document
    var documentName: String
    var createdAt: Date = Date()
}

struct RecentDocument: Codable, Identifiable {
    var id: String { name }
    let name: String
    let bookmark: Data?
    let lastOpened: Date
    var projectType: String?
    var fileCount: Int?
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
