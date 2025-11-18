import Foundation

/// Service for file uploads and storage
class FileService {
    static let shared = FileService()
    
    private init() {}
    
    struct FileUploadResult: Codable {
        let url: String
        let fileId: String?
        let key: String?
    }
    
    /// Upload a file to the server
    /// - Parameters:
    ///   - data: File data
    ///   - filename: Name of the file
    ///   - mimeType: MIME type (e.g. "image/jpeg", "audio/m4a")
    /// - Returns: URL of the uploaded file
    func uploadFile(data: Data, filename: String, mimeType: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var request = URLRequest(url: URL(string: "\(APIClient.baseURL)/api/files/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add Auth Token
        if let token = SupabaseAuthService.shared.currentSession?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let httpBody = createMultipartBody(data: data, boundary: boundary, filename: filename, mimeType: mimeType)
        request.httpBody = httpBody
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                throw NSError(domain: "FileService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            throw URLError(.badServerResponse)
        }
        
        let result = try JSONDecoder().decode(FileUploadResult.self, from: responseData)
        return result.url
    }
    
    private func createMultipartBody(data: Data, boundary: String, filename: String, mimeType: String) -> Data {
        var body = Data()
        
        // File data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}

