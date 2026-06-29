//
//  ReaderSettingsView.swift
//  WSP Reader
//
//  Settings view for reader preferences.
//  Feature 026: WSP Reader App
//

import SwiftUI

struct ReaderSettingsView: View {
    @Environment(ReaderAppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            Form {
                // Reading settings
                Section("Reading") {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(appState.fontSize))pt")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $appState.fontSize, in: 12...32, step: 1) {
                        Text("Font Size")
                    } minimumValueLabel: {
                        Image(systemName: "textformat.size.smaller")
                    } maximumValueLabel: {
                        Image(systemName: "textformat.size.larger")
                    }
                    
                    Picker("Theme", selection: $appState.theme) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                }
                
                // Recent documents
                Section("Recent Documents") {
                    if appState.recentDocuments.isEmpty {
                        Text("No recent documents")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.recentDocuments) { doc in
                            Text(doc.name)
                        }
                        
                        Button("Clear Recent Documents", role: .destructive) {
                            appState.clearRecentDocuments()
                        }
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: AppConstants.websiteURL) {
                        HStack {
                            Text("Website")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: AppConstants.supportURL) {
                        HStack {
                            Text("Support")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: AppConstants.privacyURL) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }
}
