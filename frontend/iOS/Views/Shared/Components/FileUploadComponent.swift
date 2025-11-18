import SwiftUI
import UniformTypeIdentifiers

/// File Upload Component
/// Drag-drop file upload with progress indicator
/// Supports files up to 100MB (free tier)
struct FileUploadComponent: View {
    @StateObject private var viewModel = FileUploadViewModel()
    @State private var isOver = false
    
    let onUploadComplete: ((URL) -> Void)?
    
    init(onUploadComplete: ((URL) -> Void)? = nil) {
        self.onUploadComplete = onUploadComplete
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isOver ? Color("VibeZGold").opacity(0.1) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isOver ? Color("VibeZGold") : Color.gray.opacity(0.3),
                                lineWidth: isOver ? 2 : 1
                            )
                    )
                
                VStack(spacing: 12) {
                    Image(systemName: isOver ? "arrow.down.circle.fill" : "square.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(isOver ? Color("VibeZGold") : .secondary)
                    
                    Text(isOver ? "Drop files here" : "Drag files to upload")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Up to 100MB per file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 120)
            .onDrop(of: [.item], isTargeted: $isOver) { providers in
                viewModel.handleDrop(providers)
                return true
            }
            .accessibilityLabel("File upload drop zone")
            .accessibilityHint("Drag files here or tap to select files")
            .onTapGesture {
                // TODO: Show file picker
                print("Show file picker")
            }
            
            // Progress indicator
            if viewModel.isUploading {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(Color("VibeZGold"))
                    
                    Text("Uploading... \(Int(viewModel.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .accessibilityLabel("Upload progress \(Int(viewModel.progress * 100)) percent")
            }
            
            // Uploaded file info
            if let uploadedURL = viewModel.uploadedURL {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Upload complete")
                        .font(.subheadline)
                    Spacer()
                    Button("Copy URL") {
                        UIPasteboard.general.string = uploadedURL.absoluteString
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("File uploaded successfully")
            }
            
            // Error message
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .accessibilityLabel("Upload error: \(error)")
            }
        }
        .onChange(of: viewModel.uploadedURL) { _, url in
            if let url = url {
                onUploadComplete?(url)
            }
        }
    }
}

/// File Upload ViewModel
@MainActor
final class FileUploadViewModel: ObservableObject {
    @Published var isOver = false
    @Published var isUploading = false
    @Published var progress: Double = 0
    @Published var uploadedURL: URL?
    @Published var error: String?
    
    func handleDrop(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        
        // Process first file
        guard let provider = providers.first else { return }
        
        // Check file type
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            let fileName = provider.suggestedName ?? "file"
            provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] data, error in
                // Copy data immediately to avoid data race
                let fileData: Data?
                if let data = data as? Data {
                    fileData = Data(data) // Create a copy
                } else {
                    fileData = nil
                }
                
                Task { @MainActor in
                    if let error = error {
                        self?.error = "Failed to load file: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let fileData = fileData else {
                        self?.error = "Invalid file data"
                        return
                    }
                    
                    // Check file size (100MB limit)
                    let maxSize = 100 * 1024 * 1024 // 100MB
                    if fileData.count > maxSize {
                        self?.error = "File too large. Maximum size is 100MB"
                        return
                    }
                    
                    await self?.uploadFile(data: fileData, fileName: fileName)
                }
            }
        } else {
            error = "Unsupported file type"
        }
    }
    
    private func uploadFile(data: Data, fileName: String) async {
        isUploading = true
        progress = 0
        error = nil
        
        do {
            // Create multipart form data
            let boundary = UUID().uuidString
            var body = Data()
            
            // Add file data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            // Upload via APIClient
            var request = URLRequest(url: URL(string: "\(APIClient.baseURL)/api/files/upload")!)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            if let session = SupabaseAuthService.shared.currentSession {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            }
            
            request.httpBody = body
            
            // Simulate progress (in production, use URLSessionDelegate for real progress)
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                progress = Double(i) / 10.0
            }
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            
            // Parse response
            let decoder = JSONDecoder()
            let uploadResponse = try decoder.decode(FileUploadResponse.self, from: responseData)
            
            uploadedURL = URL(string: uploadResponse.url)
            isUploading = false
            progress = 1.0
            
        } catch {
            self.error = "Upload failed: \(error.localizedDescription)"
            isUploading = false
            progress = 0
        }
    }
}

/// File Upload Response Model
struct FileUploadResponse: Codable {
    let url: String
    let fileId: String
    let fileName: String
    let fileSize: Int
    
    enum CodingKeys: String, CodingKey {
        case url
        case fileId = "file_id"
        case fileName = "file_name"
        case fileSize = "file_size"
    }
}

#Preview {
    FileUploadComponent()
        .padding()
}

