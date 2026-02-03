//
//  PoetrySettingsSheet.swift
//  Writing Shed Pro
//
//  Settings sheet for poetry-specific preferences
//  Accessed from the project ellipsis menu on poetry projects
//

import SwiftUI

struct PoetrySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var poetryPrefs = PoetryPreferences.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Binding(
                        get: { poetryPrefs.showMetricsBar },
                        set: { poetryPrefs.showMetricsBar = $0 }
                    )) {
                        Label(NSLocalizedString("settings.poetry.showMetricsBar", comment: "Show Metrics Bar"), systemImage: "chart.bar")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { poetryPrefs.showStressAnalysis },
                        set: { poetryPrefs.showStressAnalysis = $0 }
                    )) {
                        Label(NSLocalizedString("settings.poetry.enableStressAnalysis", comment: "Enable Stress Analysis"), systemImage: "waveform.path")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { poetryPrefs.showSyllableHints },
                        set: { poetryPrefs.showSyllableHints = $0 }
                    )) {
                        Label(NSLocalizedString("settings.poetry.showSyllableHints", comment: "Show Syllable Hints"), systemImage: "textformat.123")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { poetryPrefs.autoOpenFormReference },
                        set: { poetryPrefs.autoOpenFormReference = $0 }
                    )) {
                        Label(NSLocalizedString("settings.poetry.autoOpenFormReference", comment: "Auto-Open Form Reference"), systemImage: "book")
                    }
                } header: {
                    Text(NSLocalizedString("settings.poetry.displaySection", comment: "Display"))
                } footer: {
                    Text(NSLocalizedString("settings.poetry.displayFooter", comment: "Control which poetry analysis features are shown in the editor."))
                }
                
                Section {
                    Picker(selection: Binding(
                        get: { poetryPrefs.englishDialect },
                        set: { poetryPrefs.englishDialect = $0 }
                    )) {
                        ForEach(EnglishDialect.allCases, id: \.self) { dialect in
                            Text(dialect.displayName).tag(dialect)
                        }
                    } label: {
                        Label(NSLocalizedString("settings.poetry.pronunciation", comment: "Pronunciation"), systemImage: "globe")
                    }
                } header: {
                    Text(NSLocalizedString("settings.poetry.dialectSection", comment: "Dialect"))
                } footer: {
                    Text(NSLocalizedString("settings.poetry.dialectFooter", comment: "Affects syllable counting and stress patterns. American and British English have different pronunciations for some words."))
                }
            }
            .navigationTitle(NSLocalizedString("settings.poetrySettings", comment: "Poetry Settings"))
            #if !targetEnvironment(macCatalyst)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
