//
//  ImportProgressBanner.swift
//  Writing Shed Pro
//
//  Created on 14 November 2025.
//  Feature 009: Database Import - Simple progress indicator
//

import SwiftUI

/// Compact progress banner displayed at top of project list during import
struct ImportProgressBanner: View {
    var progressTracker: ImportProgressTracker
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("importProgress.importing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(progressTracker.currentPhase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("importProgress.banner.accessibility")
                
                Spacer()
                
                Text("\(Int(progressTracker.percentComplete))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            ProgressView(value: progressTracker.percentComplete / 100)
                .tint(.blue)
                .padding(.horizontal, 16)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
