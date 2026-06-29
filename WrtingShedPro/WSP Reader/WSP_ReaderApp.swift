//
//  WSP_ReaderApp.swift
//  WSP Reader
//
//  Restored app entry point for WSP Reader target.
//

import SwiftUI
import UniformTypeIdentifiers
#if targetEnvironment(macCatalyst)
import UIKit
#endif

@main
struct WSP_ReaderApp: App {
    #if targetEnvironment(macCatalyst)
    @UIApplicationDelegateAdaptor(WSPReaderMenuAppDelegate.self) private var menuAppDelegate
    #endif

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

            CommandGroup(replacing: .help) {
                Button("WSP Reader Help") {
                    NotificationCenter.default.post(name: .wspReaderShowHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }

            #if os(macOS) || targetEnvironment(macCatalyst)
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .textFormatting) {}
            CommandGroup(replacing: .windowArrangement) {}
            #endif
        }
    }
}

extension UTType {
    static var wspDocument: UTType {
        UTType(exportedAs: "com.writing-shed.wsp")
    }
}

#if targetEnvironment(macCatalyst)
final class WSPReaderMenuAppDelegate: UIResponder, UIApplicationDelegate {
    override func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == .main else { return }
        builder.remove(menu: .edit)
        // Remove the Help Search text field from the Help menu
        builder.remove(menu: UIMenu.Identifier(rawValue: "com.apple.menu.help.helpSearch"))
    }
}
#endif
