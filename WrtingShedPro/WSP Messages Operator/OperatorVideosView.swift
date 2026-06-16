import SwiftUI
import UniformTypeIdentifiers

struct OperatorVideosView: View {
    @State private var service = OperatorVideosService()
    @Bindable var settings: OperatorSettingsStore
    @State private var selectedUploadURL: URL?
    @State private var showingImporter = false
    @State private var pendingDeleteVideo: OperatorVideo?

    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    TextField("Endpoint", text: $settings.endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Admin API Token", text: $settings.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Upload") {
                    Button("Choose Video to Upload") {
                        showingImporter = true
                    }
                    .disabled(settings.token.isEmpty || service.isUploading || service.isSavingOrder)

                    if let selectedUploadURL {
                        Text(selectedUploadURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if service.isUploading {
                        ProgressView(value: service.uploadProgress, total: 1) {
                            Text("Uploading")
                        } currentValueLabel: {
                            Text("\(Int((service.uploadProgress * 100).rounded()))%")
                        }
                    }

                    if service.isSavingOrder {
                        ProgressView("Saving Order")
                    }
                }

                Section("Videos") {
                    if service.isLoading {
                        ProgressView()
                    }
                    ForEach(service.videos) { video in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.headline)
                            Text(video.key)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                pendingDeleteVideo = video
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        service.moveVideo(from: source, to: destination)
                        Task {
                            await service.saveOrder(settings: settings)
                            await service.fetch(settings: settings)
                        }
                    }
                }
            }
            .navigationTitle("WSP Videos Operator")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await service.fetch(settings: settings)
                        }
                    }
                    .disabled(settings.token.isEmpty || service.isUploading || service.isSavingOrder)
                }
            }
            .task {
                if !settings.token.isEmpty {
                    await service.fetch(settings: settings)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.movie, .mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    selectedUploadURL = url
                    Task {
                        await service.upload(fileURL: url, settings: settings)
                        await service.fetch(settings: settings)
                    }
                case .failure(let error):
                    service.errorMessage = error.localizedDescription
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { service.errorMessage != nil },
                    set: { if !$0 { service.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { service.errorMessage = nil }
            } message: {
                Text(service.errorMessage ?? "")
            }
            .alert(
                "Delete Video?",
                isPresented: Binding(
                    get: { pendingDeleteVideo != nil },
                    set: { if !$0 { pendingDeleteVideo = nil } }
                ),
                presenting: pendingDeleteVideo
            ) { video in
                Button("Delete", role: .destructive) {
                    Task {
                        await service.deleteVideo(key: video.key, settings: settings)
                        await service.fetch(settings: settings)
                    }
                    pendingDeleteVideo = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteVideo = nil
                }
            } message: { video in
                Text("This will permanently remove \"\(video.fileName)\" from tutorial videos.")
            }
        }
    }
}
