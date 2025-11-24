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
    
    // Get app version from bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon
                    Image("AboutIcon")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                    
                    // App Name
                    Text("Writing Shed Pro")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Version
                    Text(appVersion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Description
                    VStack(spacing: 12) {
                        Text("A professional writing environment for authors, poets, and screenwriters.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        Text("Organize your projects, manage versions, track submissions, and format your work for publication.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Copyright
                    VStack(spacing: 8) {
                        Text("© 2025 Writing Shed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("All rights reserved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Future: Add links to website, privacy policy, terms of service
                }
                .padding()
            }
            .navigationTitle("About")
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
}

#Preview {
    AboutView()
}
