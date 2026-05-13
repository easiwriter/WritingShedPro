//
//  EditingBlockedView.swift
//  WSP Reader
//
//  Shown when user attempts to edit in the reader.
//  Feature 026: WSP Reader App
//

import SwiftUI

struct EditingBlockedView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "pencil.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            // Title
            Text("Editing Not Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Description
            Text("WSP Reader is for viewing documents only. To create and edit your own documents, get Writing Shed Pro.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button {
                    openAppStore()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.app")
                        Text("Get Writing Shed Pro")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
                
                Button {
                    isPresented = false
                } label: {
                    Text("Continue Reading")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: 400)
    }
    
    private func openAppStore() {
        if let url = URL(string: AppConstants.appStoreURL.absoluteString) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

// MARK: - View Modifier for Blocking Edits

struct EditBlockingModifier: ViewModifier {
    @State private var showEditBlocked = false
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .editAttempted)) { _ in
                showEditBlocked = true
            }
            .sheet(isPresented: $showEditBlocked) {
                EditingBlockedView(isPresented: $showEditBlocked)
                    .presentationDetents([.medium])
            }
    }
}

extension View {
    func blockEditing() -> some View {
        modifier(EditBlockingModifier())
    }
}

extension Notification.Name {
    static let editAttempted = Notification.Name("editAttempted")
}
