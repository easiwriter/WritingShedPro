//
//  ImportProgressView.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import SwiftUI
import SwiftData

/// Displays import progress and handles the import workflow
struct ImportProgressView: View {
    @Environment(\.modelContext) var modelContext
    @Binding var isPresented: Bool
    @State private var importService = ImportService()
    @State private var isImporting = false
    @State private var importCompleted = false
    @State private var importError: String?
    @State private var showErrorAlert = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title
                Text("Importing Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Description
                Text("Importing your data from the original Writing Shed app...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                // Progress bar
                if isImporting {
                    // Percentage display
                    Text("\(Int(importService.getProgressTracker().percentComplete))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    
                    ProgressView(value: importService.getProgressTracker().percentComplete / 100)
                        .tint(.blue)
                    
                    // Progress text
                    VStack(spacing: 4) {
                        Text(importService.getProgressTracker().currentPhase)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !importService.getProgressTracker().currentItem.isEmpty {
                            Text(importService.getProgressTracker().currentItem)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                // Success message
                if importCompleted && importError == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("Import Complete")
                            .font(.headline)
                        
                        Text("Your data has been imported successfully.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Note about no cancel
                if isImporting {
                    Text("This process cannot be cancelled. Please keep the app open.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .onAppear {
            startImport()
        }
        .alert("Import Failed", isPresented: $showErrorAlert) {
            Button("OK") {
                // Dismiss and let user retry on next launch
            }
        } message: {
            Text(importError ?? "An unknown error occurred during import.")
        }
    }
    
    private func startImport() {
        isImporting = true
        
        // Capture the container from the main thread context
        let container = modelContext.container
        
        Task.detached {
            // Create a background ModelContext for this thread
            let backgroundContext = ModelContext(container)
            
            let success = await importService.executeImport(modelContext: backgroundContext)
            
            await MainActor.run {
                isImporting = false
                
                if success {
                    importCompleted = true
                    // Auto-dismiss after 2 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        isPresented = false
                    }
                } else {
                    importError = importService.getErrorReport()
                    showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    ImportProgressView(isPresented: $isPresented)
        .modelContainer(for: Project.self, inMemory: true)
}
