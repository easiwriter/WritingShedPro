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

extension UTType {
    static var wspDocument: UTType {
        UTType(exportedAs: "com.writing-shed.wsp")
    }
}
