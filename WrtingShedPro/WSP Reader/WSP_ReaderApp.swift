//
//  WSP_ReaderApp.swift
//  WSP Reader
//
//  Restored app entry point for WSP Reader target.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct WSP_ReaderApp: App {
    @State private var appState = ReaderAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    print("[WSPReader] onOpenURL received: \(url.lastPathComponent)")
                    if url.pathExtension.lowercased() == "wsp" {
                        appState.openDocument(at: url)
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    appState.openFilePicker()
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
    }
}

extension UTType {
    static var wspDocument: UTType {
        UTType(exportedAs: "com.writing-shed.wsp")
    }
}
