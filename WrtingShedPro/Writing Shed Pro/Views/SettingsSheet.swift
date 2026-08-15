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
    let projects: [Project]
    let onImport: () -> Void
    let onSyncNow: () -> Void
    let onRestartOnboarding: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) var requestReview
    @State private var receiveOperatorMessages = SupportMessagesService.receiveOperatorMessages
    @State private var allowCriticalOperatorMessages = SupportMessagesService.allowCriticalWhenOptedOut
    @State private var showRestartOnboardingConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - General Section
                Section {
                    Button {
                        dismissSheet()
                        state.showAbout = true
                    } label: {
                        Label("About Writing Shed Pro", systemImage: "info.circle")
                    }

                    Toggle(isOn: Binding(
                        get: { state.autoOpenLastProjectOnLaunch },
                        set: { state.autoOpenLastProjectOnLaunch = $0 }
                    )) {
                        Label("Auto-open last project on launch", systemImage: "arrowshape.turn.up.right")
                    }
                    
                    Button {
                        dismissSheet()
                        state.showManageStyles = true
                    } label: {
                        Label("Stylesheet Editor", systemImage: "paintbrush")
                    }

                    Button {
                        showRestartOnboardingConfirmation = true
                    } label: {
                        Label(NSLocalizedString("onboarding.settings.restart", comment: "Restart onboarding"), systemImage: "sparkles")
                    }
                }
                
                // MARK: - Import Section
                Section {
                    Button {
                        dismissSheet()
                        onImport()
                    } label: {
                        Label("Import", systemImage: "arrow.down.doc")
                    }

                    Button {
                        state.toggleProjectVisibilityMode(using: projects, keepingProjectVisible: state.lastOpenedProjectID)
                    } label: {
                        Label(
                            state.hideAllProjects ? "Show Hidden Projects" : "Hide Existing Projects",
                            systemImage: state.hideAllProjects ? "eye" : "eye.slash"
                        )
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
                    SyncStatusView()

                    Button {
                        dismissSheet()
                        onSyncNow()
                    } label: {
                        Label("Sync Now", systemImage: "arrow.clockwise.icloud")
                    }

                    #if DEBUG || targetEnvironment(simulator)
                    Button {
                        dismissSheet()
                        state.showSyncDiagnostics = true
                    } label: {
                        Label("Sync Troubleshooting", systemImage: "arrow.triangle.2.circlepath")
                    }
                    #endif
                    
                    Button {
                        dismissSheet()
                        state.showContactSupport = true
                    } label: {
                        Label("Contact Support", systemImage: "envelope")
                    }

                    Button {
                        dismissSheet()
                        state.showSupportMessages = true
                    } label: {
                        Label("Support Messages", systemImage: "text.bubble")
                    }

                    Toggle(isOn: $receiveOperatorMessages) {
                        Label("Receive operator messages", systemImage: "megaphone")
                    }

                    Toggle(isOn: $allowCriticalOperatorMessages) {
                        Label("Allow critical messages when opted out", systemImage: "exclamationmark.triangle")
                    }
                    .disabled(receiveOperatorMessages)
                    
                    Button {
                        Task {
                            ReviewManager.shared.requestReviewManually()
                            await MainActor.run {
                                requestReview()
                            }
                        }
                        dismissSheet()
                    } label: {
                        Label("Rate This App", systemImage: "star.fill")
                    }
                }

#if DEBUG || targetEnvironment(simulator)
                // MARK: - Debug Section
                Section("Debug") {
                    Toggle(isOn: Binding(
                        get: {
                            EntitlementManager.shared.isPaywallCaptureModeEnabled
                        },
                        set: { isEnabled in
                            Task {
                                await EntitlementManager.shared.setPaywallCaptureModeEnabled(isEnabled)
                            }
                        }
                    )) {
                        Label("Force Paywall Capture Mode", systemImage: "camera.aperture")
                    }

                    Button {
                        Task {
                            await EntitlementManager.shared.resetPaywallCaptureState()
                        }
                    } label: {
                        Label("Reset Paywall Capture State", systemImage: "arrow.counterclockwise")
                    }

                    Toggle(isOn: Binding(
                        get: {
                            OnboardingCoordinator.debugForceNewUserModeEnabled
                        },
                        set: { isEnabled in
                            OnboardingCoordinator.debugForceNewUserModeEnabled = isEnabled
                            if isEnabled {
                                onRestartOnboarding()
                            }
                        }
                    )) {
                        Label("Force New User Onboarding", systemImage: "sparkles")
                    }

                    Text("When enabled, the app ignores existing purchases so creating a second project/file shows the upgrade paywall for screenshots.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("When enabled, onboarding ignores existing projects and completion state. Real project data is not deleted or hidden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
#endif
            }
            .scrollIndicatorsFlash(onAppear: true)
            .onChange(of: receiveOperatorMessages) { _, newValue in
                SupportMessagesService.receiveOperatorMessages = newValue
            }
            .onChange(of: allowCriticalOperatorMessages) { _, newValue in
                SupportMessagesService.allowCriticalWhenOptedOut = newValue
            }
            .alert(NSLocalizedString("onboarding.restart.title", comment: "Restart onboarding alert title"), isPresented: $showRestartOnboardingConfirmation) {
                Button(NSLocalizedString("onboarding.restart.confirm", comment: "Restart onboarding confirmation"), role: .destructive) {
                    onRestartOnboarding()
                }
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) { }
            } message: {
                Text(NSLocalizedString("onboarding.restart.message", comment: "Restart onboarding warning"))
            }
            #if targetEnvironment(macCatalyst)
            .navigationTitle("")
            #else
            .navigationTitle("Settings")
            #endif
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismissSheet()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(uiColor: .systemBackground))
    }

    private func dismissSheet() {
        isPresented = false
        dismiss()
        dismissPresentedSheetOnCatalyst()
    }
}
