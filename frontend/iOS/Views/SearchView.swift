import SwiftUI

/// Search View - Full-text search across messages, rooms, and users
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search messages, rooms, users…", text: $viewModel.query)
                        .focused($isFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.query) { _, newValue in
                            viewModel.debounceSearch()
                        }
                        .accessibilityLabel("Search field")
                        .accessibilityHint("Type to find messages, rooms or users")
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .accessibilityLabel("Searching")
                    }
                    
                    if !viewModel.query.isEmpty {
                        Button(action: {
                            viewModel.query = ""
                            viewModel.results = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Results list
                if viewModel.query.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Start typing to search")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.results.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.results) { result in
                        SearchResultRow(result: result)
                            .onTapGesture {
                                viewModel.select(result)
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

/// Search Result Row Component
struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon based on type
            Image(systemName: iconForType(result.type))
                .foregroundColor(colorForType(result.type))
                .font(.title3)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.content)
                    .font(.body)
                    .lineLimit(2)
                
                if let metadata = result.metadata {
                    Text(metadataString(metadata))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.type.capitalized): \(result.content)")
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "message": return "message.fill"
        case "room": return "door.left.hand.open"
        case "user": return "person.fill"
        default: return "circle.fill"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case "message": return Color("VibeZGold")
        case "room": return .blue
        case "user": return .green
        default: return .secondary
        }
    }
    
    private func metadataString(_ metadata: [String: Any]) -> String {
        var parts: [String] = []
        if let roomId = metadata["room_id"] as? String {
            parts.append("Room")
        }
        if let username = metadata["username"] as? String {
            parts.append("@\(username)")
        }
        if let createdAt = metadata["created_at"] as? String {
            // Format date if needed
            parts.append(createdAt)
        }
        return parts.joined(separator: " • ")
    }
}

/// Search ViewModel
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    
    private var debounceTask: Task<Void, Never>?
    
    func debounceSearch() {
        debounceTask?.cancel()
        guard !query.isEmpty else {
            results = []
            return
        }
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if !Task.isCancelled {
                await performSearch()
            }
        }
    }
    
    private func performSearch() async {
        guard !query.isEmpty else {
            results = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: SearchResponse = try await APIClient.shared.request(
                endpoint: "/api/search",
                method: "GET",
                queryParams: ["query": query, "limit": "20"]
            )
            results = response.results
        } catch {
            print("[SearchView] Search failed: \(error)")
            results = []
        }
    }
    
    func select(_ result: SearchResult) {
        // Navigate based on result type
        switch result.type {
        case "message":
            if let roomId = result.metadata?["room_id"] as? String {
                // Navigate to room and highlight message
                // TODO: Implement navigation to room with message highlight
                print("Navigate to room \(roomId), highlight message \(result.id)")
            }
        case "room":
            // Navigate to room
            // TODO: Implement room navigation
            print("Navigate to room \(result.id)")
        case "user":
            // Open DM or user profile
            // TODO: Implement user navigation
            print("Open user \(result.id)")
        default:
            break
        }
    }
}

/// Search Result Model
struct SearchResult: Codable, Identifiable {
    let id: String
    let type: String // "message", "room", "user"
    let content: String
    let metadata: [String: Any]?
    let rank: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case content
        case metadata
        case rank
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        rank = try container.decodeIfPresent(Double.self, forKey: .rank)
        
        // Decode metadata as dictionary
        if let metadataData = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata) {
            metadata = metadataData.mapValues { $0.value }
        } else {
            metadata = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(rank, forKey: .rank)
        if let metadata = metadata {
            let codableMetadata = metadata.mapValues { AnyCodable($0) }
            try container.encode(codableMetadata, forKey: .metadata)
        }
    }
}

/// Search Response Model
struct SearchResponse: Codable {
    let results: [SearchResult]
    let count: Int
}

// AnyCodable is defined in Models/UXEventType.swift - using that definition

#Preview {
    SearchView()
}

