//
//  WorkflowStatusPickerSheet.swift
//  Writing Shed Pro
//
//  Sheet for changing the workflow status of one or more files
//

import SwiftUI

/// Sheet for selecting a new workflow status for files
struct WorkflowStatusPickerSheet: View {
    
    let files: [TextFile]
    let onStatusSelected: (WorkflowStatus) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(WorkflowStatus.allCases, id: \.self) { status in
                        Button {
                            onStatusSelected(status)
                        } label: {
                            HStack {
                                Image(systemName: status.systemImage)
                                    .foregroundColor(Color(status.color))
                                    .frame(width: 24)
                                
                                Text(status.localizedName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // Show checkmark if all selected files have this status
                                if allFilesHaveStatus(status) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("workflow.picker.header", comment: "Select Status"))
                } footer: {
                    if files.count == 1 {
                        Text(String(format: NSLocalizedString("workflow.picker.footer.single", comment: "Change status for file"), files.first?.name ?? ""))
                    } else {
                        Text(String(format: NSLocalizedString("workflow.picker.footer.multiple", comment: "Change status for files"), files.count))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("workflow.picker.title", comment: "Change Status"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .presentationDetents([.medium])
    }
    
    private func allFilesHaveStatus(_ status: WorkflowStatus) -> Bool {
        files.allSatisfy { $0.workflowStatus == status }
    }
}
