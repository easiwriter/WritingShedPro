//
//  SettingsSheet.swift
//  Writing Shed Pro
//
//  Settings presented as a sheet for better visibility and control
//

import SwiftUI
import StoreKit

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    var state: ContentViewState
    let onImport: () -> Void
    
    @Environment(\.requestReview) var requestReview
    
    private var poetryPrefs: PoetryPreferences { state.poetryPreferences }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - General Section
                Section {
                    Button {
                        isPresented = false
                        state.showAbout = true
                    } label: {
                        Label("About Writing Shed Pro", systemImage: "info.circle")
                    }
                    
                    Button {
                        isPresented = false
                        state.showStore = true
                    } label: {
                        Label("Manage Purchases", systemImage: "cart")
                    }
                    
                    Button {
                        isPresented = false
                        state.showManageStyles = true
                    } label: {
                        Label("Stylesheet Editor", systemImage: "paintbrush")
                    }
                }
                
                // MARK: - Import Section
                Section {
                    Button {
                        isPresented = false
                        onImport()
                    } label: {
                        Label("Import", systemImage: "arrow.down.doc")
                    }
                    
                    Button {
                        isPresented = false
                        state.showManualImportConfirmation = true
                    } label: {
                        Label("Import User Guide", systemImage: "book.closed")
                    }
                }
                
                // MARK: - Poetry Settings Section
                Section("Poetry Settings") {
                    Toggle(isOn: Binding(
                        get: { poetryPrefs.showMetricsBar },
                        set: { poetryPrefs.showMetricsBar = $0 }
                    )) {
                        Label("Show Metrics Bar", systemImage: "chart.bar")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { poetryPrefs.showStressAnalysis },
                        set: { poetryPrefs.showStressAnalysis = $0 }
                    )) {
                        Label("Enable Stress Analysis", systemImage: "waveform.path")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { poetryPrefs.showSyllableHints },
                        set: { poetryPrefs.showSyllableHints = $0 }
                    )) {
                        Label("Show Syllable Hints", systemImage: "textformat.123")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { poetryPrefs.autoOpenFormReference },
                        set: { poetryPrefs.autoOpenFormReference = $0 }
                    )) {
                        Label("Auto-Open Form Reference", systemImage: "book")
                    }
                    
                    // Dialect picker
                    Picker(selection: Binding(
                        get: { poetryPrefs.englishDialect },
                        set: { poetryPrefs.englishDialect = $0 }
                    )) {
                        ForEach(EnglishDialect.allCases, id: \.self) { dialect in
                            Text(dialect.displayName).tag(dialect)
                        }
                    } label: {
                        Label("Pronunciation", systemImage: "globe")
                    }
                }
                
                // MARK: - Appearance Section (iOS only)
                #if !targetEnvironment(macCatalyst)
                Section("Appearance") {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button {
                            state.appearancePreferences.appearanceMode = mode
                        } label: {
                            HStack {
                                Label(mode.displayName, systemImage: mode.icon)
                                Spacer()
                                if state.appearancePreferences.appearanceMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                #endif
                
                // MARK: - Support Section
                Section {
                    Button {
                        isPresented = false
                        state.showSyncDiagnostics = true
                    } label: {
                        Label("Sync Diagnostics", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button {
                        isPresented = false
                        state.showContactSupport = true
                    } label: {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    
                    Button {
                        Task {
                            ReviewManager.shared.requestReviewManually()
                            await MainActor.run {
                                requestReview()
                            }
                        }
                        isPresented = false
                    } label: {
                        Label("Rate This App", systemImage: "star.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(uiColor: .systemBackground))
    }
}
