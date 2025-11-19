import SwiftUI

/// Privacy Settings View
/// Shows encryption status, ZKP commitments, and privacy controls
struct PrivacySettingsView: View {
    @State private var encryptionStatus: EncryptionStatus?
    @State private var isLoading = true
    @State private var showDataExport = false
    @State private var showDataDeletion = false
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    // Encryption Status
                    if let status = encryptionStatus {
                        Section("Encryption") {
                            HStack {
                                Image(systemName: status.hardwareAccelerated ? "lock.shield.fill" : "lock.fill")
                                    .foregroundColor(status.hardwareAccelerated ? .green : .orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(status.hardwareAccelerated ? "Hardware Accelerated" : "Software Encryption")
                                        .font(.headline)
                                    
                                    Text("Algorithm: \(status.algorithm)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if status.pfsEnabled {
                                        Label("Perfect Forward Secrecy", systemImage: "checkmark.shield")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            if let alert = status.fallbackAlert {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(alert.message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Privacy Controls
                    Section("Privacy Controls") {
                        NavigationLink("Zero-Knowledge Proofs", destination: ZKPCommitmentsView())
                            .font(.body)
                        
                        Button("View Encryption Status") {
                            Task {
                                await loadEncryptionStatus()
                            }
                        }
                        .font(.body)
                    }
                    
                    // Data Management
                    Section("Data Management") {
                        Button("Export My Data") {
                            showDataExport = true
                        }
                        .font(.body)
                        
                        Button("Delete My Data", role: .destructive) {
                            showDataDeletion = true
                        }
                        .font(.body)
                    }
                }
            }
            .navigationTitle("Privacy")
            .task {
                await loadEncryptionStatus()
            }
            .alert("Export Data", isPresented: $showDataExport) {
                Button("Cancel", role: .cancel) {}
                Button("Export") {
                    Task {
                        await exportUserData()
                    }
                }
            } message: {
                Text("Your data will be exported in JSON format. This may take a few moments.")
            }
            .alert("Delete Data", isPresented: $showDataDeletion) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteUserData()
                    }
                }
            } message: {
                Text("This will permanently delete all your data. This action cannot be undone.")
            }
        }
    }
    
    private func loadEncryptionStatus() async {
        isLoading = true
        do {
            let status: EncryptionStatusResponse = try await APIClient.shared.request(
                endpoint: "/api/privacy/encryption-status",
                method: "GET"
            )
            
            await MainActor.run {
                self.encryptionStatus = EncryptionStatus(
                    hardwareAccelerated: status.hardwareAccelerated,
                    algorithm: status.algorithm,
                    pfsEnabled: status.pfsEnabled,
                    fallbackAlert: status.fallbackAlert
                )
                self.isLoading = false
            }
        } catch {
            print("[PrivacySettings] Failed to load encryption status: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func exportUserData() async {
        // TODO: Implement data export
        print("[PrivacySettings] Exporting user data...")
    }
    
    private func deleteUserData() async {
        // TODO: Implement data deletion with confirmation
        print("[PrivacySettings] Deleting user data...")
    }
}

/// Zero-Knowledge Proof Commitments View
struct ZKPCommitmentsView: View {
    @State private var commitments: [ZKPCommitment] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if commitments.isEmpty {
                Text("No active commitments")
                    .foregroundColor(.secondary)
            } else {
                ForEach(commitments) { commitment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(commitment.attributeType)
                            .font(.headline)
                        Text("Created: \(commitment.createdAt)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("ZKP Commitments")
        .task {
            await loadCommitments()
        }
    }
    
    private func loadCommitments() async {
        do {
            guard let session = SupabaseAuthService.shared.currentSession else { return }
            let userId = session.userId
            
            let response: ZKPCommitmentsResponse = try await APIClient.shared.request(
                endpoint: "/api/privacy/zkp/commitments/\(userId)",
                method: "GET"
            )
            
            await MainActor.run {
                self.commitments = response.commitments.map { c in
                    ZKPCommitment(
                        id: c.id,
                        attributeType: c.attributeType,
                        createdAt: c.createdAt
                    )
                }
                self.isLoading = false
            }
        } catch {
            print("[ZKPCommitments] Failed to load commitments: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Types

struct EncryptionStatus {
    let hardwareAccelerated: Bool
    let algorithm: String
    let pfsEnabled: Bool
    let fallbackAlert: FallbackAlert?
}

struct EncryptionStatusResponse: Codable {
    let success: Bool
    let hardwareAccelerated: Bool
    let algorithm: String
    let pfsEnabled: Bool
    let fallbackAlert: FallbackAlert?
}

struct FallbackAlert: Codable {
    let message: String
    let severity: String
}

struct ZKPCommitment: Identifiable {
    let id: String
    let attributeType: String
    let createdAt: String
}

struct ZKPCommitmentsResponse: Codable {
    let success: Bool
    let commitments: [ZKPCommitmentItem]
}

struct ZKPCommitmentItem: Codable {
    let id: String
    let attributeType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case attributeType = "attribute_type"
        case createdAt = "created_at"
    }
}

#Preview {
    PrivacySettingsView()
}


