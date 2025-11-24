//
//  ContactSupportView.swift
//  Writing Shed Pro
//
//  Contact support screen
//  Feature 019: Settings Menu
//

import SwiftUI
import MessageUI

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let supportURL = "https://www.writing-shed.com/support-2"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Web Support
                    Link(destination: URL(string: supportURL)!) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Get Support")
                                    .foregroundStyle(.primary)
                                Text("Visit our support page")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Get Help")
                }
                
                Section {
                    // Documentation
                    Link(destination: URL(string: "https://writing-shed.com/docs")!) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            Text("Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // FAQ
                    Link(destination: URL(string: "https://writing-shed.com/faq")!) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            Text("FAQ")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Resources")
                }
                
                Section {
                    // App Version (for support reference)
                    HStack {
                        Text("App Version")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Device Info (for support reference)
                    HStack {
                        Text("Device")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(UIDevice.current.model) - iOS \(UIDevice.current.systemVersion)")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("System Information")
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    ContactSupportView()
}
