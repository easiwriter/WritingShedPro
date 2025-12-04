//
//  InEditorSearchBar.swift
//  WritingShedPro
//
//  Created on 2025-12-04
//  Feature 017: Search and Replace - Phase 1, Task 1.4
//

import SwiftUI

/// Compact search bar for in-editor text search and replace
/// Appears below toolbar when activated with ⌘F
struct InEditorSearchBar: View {
    // MARK: - Properties
    
    /// Search manager that handles search logic
    @ObservedObject var manager: InEditorSearchManager
    
    /// Whether the search bar is visible
    @Binding var isVisible: Bool
    
    /// Focus state for text fields
    @FocusState private var focusedField: SearchField?
    
    /// Whether replace mode is expanded
    @State private var showReplace: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // Main search row
                HStack(spacing: 8) {
                    // Search text field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                        
                        TextField("Search", text: $manager.searchText)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .search)
                            .font(.system(size: 17))
                        
                        if !manager.searchText.isEmpty {
                            Button(action: {
                                manager.searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 18))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .frame(minWidth: 200, maxWidth: 400)
                    
                    // Match counter
                    if manager.hasMatches {
                        Text(manager.matchCountText)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .frame(minWidth: 80)
                    } else if !manager.searchText.isEmpty && manager.totalMatches == 0 {
                        Text("No results")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .frame(minWidth: 80)
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 6) {
                        Button(action: {
                            manager.previousMatch()
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .disabled(!manager.hasMatches)
                        .help("Previous match (⌘⇧G)")
                        
                        Button(action: {
                            manager.nextMatch()
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .disabled(!manager.hasMatches)
                        .help("Next match (⌘G)")
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Options toggles
                    HStack(spacing: 4) {
                        OptionToggleButton(
                            icon: "textformat",
                            isOn: $manager.isCaseSensitive,
                            tooltip: "Match case"
                        )
                        
                        OptionToggleButton(
                            icon: "w.square",
                            isOn: $manager.isWholeWord,
                            tooltip: "Match whole word"
                        )
                        
                        OptionToggleButton(
                            icon: "asterisk",
                            isOn: $manager.isRegex,
                            tooltip: "Use regular expression"
                        )
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Replace toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showReplace.toggle()
                            manager.isReplaceMode = showReplace
                            if showReplace {
                                focusedField = .replace
                            }
                        }
                    }) {
                        Image(systemName: showReplace ? "chevron.down" : "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle replace")
                    
                    // Close button
                    Button(action: {
                        dismissSearchBar()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help("Close (⎋)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Replace row (conditionally shown)
                if showReplace {
                    HStack(spacing: 8) {
                        // Replace text field (same width/style as search field)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18))
                            
                            TextField("Replace", text: $manager.replaceText)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .replace)
                                .font(.system(size: 17))
                            
                            if !manager.replaceText.isEmpty {
                                Button(action: {
                                    manager.replaceText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(8)
                        .frame(minWidth: 200, maxWidth: 400)
                        
                        // Replace buttons appear right after the text field
                        Button("Replace") {
                            let _ = manager.replaceCurrentMatch()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 15))
                        .disabled(!manager.canReplace)
                        
                        Button("Replace All") {
                            let count = manager.replaceAllMatches()
                            print("Replaced \(count) matches")
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 15))
                        .disabled(!manager.canReplace)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Regex error message
                if let error = manager.regexError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 15))
                        
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(uiColor: .separator)),
                alignment: .bottom
            )
            .onAppear {
                focusedField = .search
            }
            .background(KeyboardShortcutHandler(
                onEscape: { dismissSearchBar() },
                onReturn: {
                    if showReplace && !manager.replaceText.isEmpty {
                        manager.replaceCurrentMatch()
                    } else {
                        manager.nextMatch()
                    }
                },
                onShiftReturn: { manager.previousMatch() },
                onCommandG: { manager.nextMatch() },
                onCommandShiftG: { manager.previousMatch() }
            ))
        }
    }
    
    // MARK: - Actions
    
    /// Dismiss the search bar and clean up
    private func dismissSearchBar() {
        manager.clearSearch()
        withAnimation(.easeInOut(duration: 0.2)) {
            isVisible = false
            showReplace = false
        }
    }
}

// MARK: - Supporting Types

/// Focus state enum for text fields
private enum SearchField {
    case search
    case replace
}

/// Reusable option toggle button
private struct OptionToggleButton: View {
    let icon: String
    @Binding var isOn: Bool
    let tooltip: String
    
    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 36, height: 36)
                .background(isOn ? Color.accentColor.opacity(0.2) : Color.clear)
                .foregroundColor(isOn ? .accentColor : .secondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Keyboard Shortcut Handler

/// UIKit-based keyboard shortcut handler for search bar
private struct KeyboardShortcutHandler: UIViewRepresentable {
    let onEscape: () -> Void
    let onReturn: () -> Void
    let onShiftReturn: () -> Void
    let onCommandG: () -> Void
    let onCommandShiftG: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = ShortcutHandlerView()
        view.onEscape = onEscape
        view.onReturn = onReturn
        view.onShiftReturn = onShiftReturn
        view.onCommandG = onCommandG
        view.onCommandShiftG = onCommandShiftG
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? ShortcutHandlerView else { return }
        view.onEscape = onEscape
        view.onReturn = onReturn
        view.onShiftReturn = onShiftReturn
        view.onCommandG = onCommandG
        view.onCommandShiftG = onCommandShiftG
    }
    
    /// UIView subclass that handles keyboard shortcuts
    private class ShortcutHandlerView: UIView {
        var onEscape: (() -> Void)?
        var onReturn: (() -> Void)?
        var onShiftReturn: (() -> Void)?
        var onCommandG: (() -> Void)?
        var onCommandShiftG: (() -> Void)?
        
        override var canBecomeFirstResponder: Bool { true }
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                becomeFirstResponder()
            }
        }
        
        override var keyCommands: [UIKeyCommand]? {
            [
                UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleEscape)),
                UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleReturn)),
                UIKeyCommand(input: "\r", modifierFlags: .shift, action: #selector(handleShiftReturn)),
                UIKeyCommand(input: "g", modifierFlags: .command, action: #selector(handleCommandG)),
                UIKeyCommand(input: "g", modifierFlags: [.command, .shift], action: #selector(handleCommandShiftG))
            ]
        }
        
        @objc private func handleEscape() {
            onEscape?()
        }
        
        @objc private func handleReturn() {
            onReturn?()
        }
        
        @objc private func handleShiftReturn() {
            onShiftReturn?()
        }
        
        @objc private func handleCommandG() {
            onCommandG?()
        }
        
        @objc private func handleCommandShiftG() {
            onCommandShiftG?()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct InEditorSearchBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            InEditorSearchBar(
                manager: InEditorSearchManager(),
                isVisible: .constant(true)
            )
            
            Spacer()
        }
        .frame(width: 600)
    }
}
#endif
