//
//  AboutView.swift
//  Writing Shed Pro
//
//  About screen showing app information
//  Feature 019: Settings Menu
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    private let ensemblesURL = URL(string: "https://ensembles.io")!
    
    // Get app version from bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - App Identity
                Section {
                    VStack(spacing: 12) {
                        Image("AboutIcon")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .cornerRadius(20)
                            .shadow(radius: 5)
                        
                        Text("Writing Shed Pro")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(appVersion)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                
                // MARK: - Description & Help Hint
                Section {
                    Text("A professional writing environment for authors, poets, and screenwriters.")
                        .foregroundStyle(.secondary)
                    
                    (Text("You can find out how to use Writing Shed Pro by tapping the ")
                     + Text(Image(systemName: "questionmark.circle"))
                     + Text(" button in the toolbar"))
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }

                // MARK: - Credits
                Section(NSLocalizedString("about.credits.title", comment: "Credits section title")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("about.ensembles.credit", comment: "Credit for Ensembles sync support"))
                            .foregroundStyle(.secondary)
                        Link("ensembles.io", destination: ensemblesURL)
                    }
                    .font(.subheadline)
                }
                
                // MARK: - Copyright
                Section {
                    VStack(spacing: 4) {
                        Text("© 2025 Writing Shed")
                        Text("All rights reserved")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollIndicatorsFlash(onAppear: true)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
