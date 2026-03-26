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
    let onSyncNow: () -> Void
    
    @Environment(\.requestReview) var requestReview
    
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
                        onSyncNow()
                    } label: {
                        Label("Sync Now", systemImage: "arrow.clockwise.icloud")
                    }

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
            .scrollIndicatorsFlash(onAppear: true)
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(uiColor: .systemBackground))
    }
}
