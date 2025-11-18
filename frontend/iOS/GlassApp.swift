/**
 * GlassApp.swift - Complete Glass Morphism UI Implementation
 * 
 * A single, self-contained SwiftUI file implementing all VibeZ UI components
 * using programmatic glass morphism effects. No storyboards, no asset packs,
 * no PNGs - everything generated through code using blur, saturation, and opacity layers.
 * 
 * Competitive Advantage:
 * - Discord: Flat design → VibeZ: Depth, premium glass morphism
 * - WhatsApp: Simple backgrounds → VibeZ: Modern iOS design language
 */

import SwiftUI

// MARK: - Glass Effect System

/// Glass material intensity levels
enum GlassMaterial: CGFloat, CaseIterable {
    case ultraThin = 10.0
    case thin = 20.0
    case regular = 30.0
    case thick = 40.0
    case frosted = 60.0
    
    var material: Material {
        switch self {
        case .ultraThin: return .ultraThinMaterial
        case .thin: return .thinMaterial
        case .regular: return .regularMaterial
        case .thick: return .thickMaterial
        case .frosted: return .ultraThickMaterial
        }
    }
}

/// Background tint options for glass effects
enum GlassTint {
    case none
    case light
    case dark
    case brand
    case custom(Color)
    
    var color: Color? {
        switch self {
        case .none: return nil
        case .light: return .white.opacity(0.1)
        case .dark: return .black.opacity(0.1)
        case .brand: return Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.15) // VibeZGold
        case .custom(let color): return color.opacity(0.15)
        }
    }
}

/// Border styles for glass components
enum GlassBorder {
    case none
    case subtle
    case standard
    case glow(Color)
    
    var stroke: (color: Color, width: CGFloat)? {
        switch self {
        case .none: return nil
        case .subtle: return (.white.opacity(0.2), 0.5)
        case .standard: return (.white.opacity(0.3), 1.0)
        case .glow(let color): return (color.opacity(0.6), 1.5)
        }
    }
}

/// Glass modifier for applying glass morphism effects
struct GlassModifier: ViewModifier {
    let material: GlassMaterial
    let tint: GlassTint
    let border: GlassBorder
    let cornerRadius: CGFloat
    let shadow: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(material.material)
                    if let tintColor = tint.color {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tintColor)
                    }
                }
            )
            .overlay(
                Group {
                    if let stroke = border.stroke {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(stroke.color, lineWidth: stroke.width)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: shadow ? .black.opacity(0.1) : .clear,
                radius: shadow ? 8 : 0,
                x: 0,
                y: shadow ? 4 : 0
            )
    }
}

extension View {
    func glass(
        material: GlassMaterial = .regular,
        tint: GlassTint = .none,
        border: GlassBorder = .subtle,
        cornerRadius: CGFloat = 16,
        shadow: Bool = true
    ) -> some View {
        modifier(GlassModifier(
            material: material,
            tint: tint,
            border: border,
            cornerRadius: cornerRadius,
            shadow: shadow
        ))
    }
    
    func glassCard(tint: GlassTint = .none, cornerRadius: CGFloat = 16) -> some View {
        glass(material: .thin, tint: tint, border: .subtle, cornerRadius: cornerRadius, shadow: true)
    }
    
    func glassInput(tint: GlassTint = .light) -> some View {
        glass(material: .ultraThin, tint: tint, border: .subtle, cornerRadius: 20, shadow: false)
    }
    
    func glassPanel(tint: GlassTint = .brand) -> some View {
        glass(
            material: .thick,
            tint: tint,
            border: .glow(Color(red: 1.0, green: 0.84, blue: 0.0)),
            cornerRadius: 20,
            shadow: true
        )
    }
}

// MARK: - Data Models

struct Room: Identifiable, Codable {
    let id: UUID
    let name: String?
    let owner_id: UUID?
    let is_public: Bool?
    let users: [User]?
    let maxOrbs: Int?
    let activityLevel: String?
    let room_tier: String?
    let ai_moderation: Bool?
    let expires_at: String?
    let is_self_hosted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, owner_id, is_public, users, maxOrbs = "max_orbs"
        case activityLevel = "activity_level", room_tier, ai_moderation
        case expires_at, is_self_hosted
    }
    
    var isTemp: Bool { room_tier == "pro" && expires_at != nil }
    var isModerated: Bool { ai_moderation == true }
}

struct Message: Identifiable, Codable {
    let id: UUID
    let senderId: UUID
    let content: String
    let type: String
    let timestamp: Date
    let emotion: String?
    let renderedHTML: String?
    let reactions: [MessageReaction]?
    let seenAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, senderId = "sender_id", content, type, timestamp
        case emotion, renderedHTML = "rendered_html", reactions, seenAt = "seen_at"
    }
}

struct MessageReaction: Identifiable, Codable {
    let id: UUID
    let emoji: String
    let count: Int
    let userIds: [UUID]?
}

struct User: Identifiable, Codable {
    let id: UUID
    let handle: String?
    let metadata: [String: String]?
}

// MARK: - Mock Data Generators

class MockDataGenerator {
    static func generateRooms(count: Int = 5) -> [Room] {
        (0..<count).map { i in
            Room(
                id: UUID(),
                name: ["General", "Random", "Tech Talk", "Design", "Music"][i % 5],
                owner_id: UUID(),
                is_public: true,
                users: [],
                maxOrbs: 10,
                activityLevel: ["calm", "active", "busy"][i % 3],
                room_tier: ["free", "pro", "enterprise"][i % 3],
                ai_moderation: i % 2 == 0,
                expires_at: i % 3 == 0 ? ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)) : nil,
                is_self_hosted: i % 4 == 0
            )
        }
    }
    
    static func generateMessages(count: Int = 10, roomId: UUID) -> [Message] {
        (0..<count).map { i in
            Message(
                id: UUID(),
                senderId: UUID(),
                content: "Message \(i + 1): This is a sample message for testing glass morphism UI.",
                type: "text",
                timestamp: Date().addingTimeInterval(-Double(i * 60)),
                emotion: nil,
                renderedHTML: nil,
                reactions: nil,
                seenAt: nil
            )
        }
    }
    
    static func generateUsers(count: Int = 3) -> [User] {
        (0..<count).map { i in
            User(
                id: UUID(),
                handle: "user\(i + 1)",
                metadata: ["email": "user\(i + 1)@example.com"]
            )
        }
    }
}

// MARK: - Loading States

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.gray.opacity(0.2),
                    Color.gray.opacity(0.4),
                    Color.gray.opacity(0.2)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: phase * geometry.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
        }
    }
}

struct LoadingSkeleton: View {
    let width: CGFloat?
    let height: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        ShimmerView()
            .frame(width: width, height: height)
            .cornerRadius(8)
    }
}

// MARK: - Empty States

struct EmptyStateView: View {
    let message: String
    @State private var pulse: CGFloat = 0.5
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .opacity(pulse)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulse = 0.3
                }
            }
    }
}

// MARK: - Error States

struct ErrorIndicator: View {
    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Animated Background

struct AnimatedGradientBackground: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        AngularGradient(
            colors: [
                Color(red: 0.2, green: 0.1, blue: 0.4),
                Color(red: 0.4, green: 0.2, blue: 0.6),
                Color(red: 0.2, green: 0.3, blue: 0.5),
                Color(red: 0.1, green: 0.2, blue: 0.4)
            ],
            center: .center,
            angle: .degrees(rotation)
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RoomListView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(Color(red: 1.0, green: 0.84, blue: 0.0))
    }
}

// MARK: - Room List View

struct RoomListView: View {
    @State private var rooms: [Room] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Loading rooms...")
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else if rooms.isEmpty {
                    EmptyStateView(message: "No messages yet")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(rooms) { room in
                                RoomRow(room: room)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Rooms")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    }
                }
            }
        }
        .task {
            await loadRooms()
        }
    }
    
    private func loadRooms() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        rooms = MockDataGenerator.generateRooms()
        isLoading = false
    }
}

struct RoomRow: View {
    let room: Room
    @State private var showSettings = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        NavigationLink(destination: ChatView(room: room)) {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "door.left.hand.open")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.name ?? "Unnamed Room")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let activityLevel = room.activityLevel {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(activityColor(activityLevel))
                                .frame(width: 6, height: 6)
                            Text(activityLevel.capitalized)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .glassCard(tint: .none)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if dragOffset < -100 {
                                showSettings = true
                            }
                            dragOffset = 0
                        }
                    }
            )
            .contextMenu {
                Button(action: { showSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                }
                Button(role: .destructive, action: {}) {
                    Label("Leave Room", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }
    
    private func activityColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "calm": return .green
        case "active": return .blue
        case "busy": return .orange
        case "intense": return .red
        default: return .gray
        }
    }
}

// MARK: - Chat View

struct ChatView: View {
    let room: Room?
    @State private var messages: [Message] = []
    @State private var isLoading = true
    @State private var showVoicePanel = false
    @State private var inputText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                VStack(spacing: 0) {
                    if showVoicePanel {
                        VoiceVideoPanelView()
                            .padding()
                            .transition(.move(edge: .top))
                    }
                    
                    if isLoading {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(0..<5) { _ in
                                    LoadingSkeleton(width: nil, height: 60)
                                }
                            }
                            .padding()
                        }
                    } else if messages.isEmpty {
                        EmptyStateView(message: "No messages yet")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadMessages()
                    }
                    }
                    
                    ChatInputView(text: $inputText, onSend: sendMessage)
                }
            }
            .navigationTitle(room?.name ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { withAnimation { showVoicePanel.toggle() } }) {
                        Image(systemName: showVoicePanel ? "mic.fill" : "mic.slash")
                            .foregroundColor(showVoicePanel ? .green : .white.opacity(0.7))
                    }
                }
            }
        }
        .task {
            await loadMessages()
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        if let room = room {
            messages = MockDataGenerator.generateMessages(count: 10, roomId: room.id)
        }
        isLoading = false
    }
    
    private func sendMessage(_ text: String) {
        guard !text.isEmpty, let room = room else { return }
        let newMessage = Message(
            id: UUID(),
            senderId: UUID(),
            content: text,
            type: "text",
            timestamp: Date(),
            emotion: nil,
            renderedHTML: nil,
            reactions: nil,
            seenAt: nil
        )
        withAnimation {
            messages.append(newMessage)
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: Message
    @State private var isOwn = false
    @State private var showContextMenu = false
    @State private var dragOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isOwn {
                Circle()
                    .fill(.blue)
                    .frame(width: 32, height: 32)
            }
            
            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isOwn ? .black : .white)
                    .padding(12)
                    .glass(
                        material: isOwn ? .thin : .regular,
                        tint: isOwn ? .brand : .none,
                        border: .subtle,
                        cornerRadius: 16
                    )
                    .offset(x: dragOffset)
                    .scaleEffect(scale)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                if !isOwn {
                                    dragOffset = value.translation.width
                                    if dragOffset > 50 {
                                        dragOffset = 50
                                    }
                                }
                            }
                            .onEnded { value in
                                withAnimation(.spring()) {
                                    if dragOffset > 30 {
                                        // Trigger reply action
                                        dragOffset = 0
                                    } else {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                showContextMenu = true
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                if value > 1.0 {
                                    scale = min(value, 1.5)
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) {
                                    scale = 1.0
                                }
                            }
                    )
                    .contextMenu {
                        Button(action: {}) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button(action: {}) {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                        }
                        Button(action: {}) {
                            Label("React", systemImage: "face.smiling")
                        }
                        if isOwn {
                            Button(role: .destructive, action: {}) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            if isOwn {
                Circle()
                    .fill(.blue)
                    .frame(width: 32, height: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
        .padding(.horizontal)
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {
    @Binding var text: String
    let onSend: (String) -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Image(systemName: "paperclip.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            TextField("Type a message...", text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundColor(.white)
                .padding(12)
                .glassInput(tint: .light)
                .onSubmit {
                    if !text.isEmpty {
                        onSend(text)
                        text = ""
                    }
                }
            
            Button(action: {
                if !text.isEmpty {
                    onSend(text)
                    text = ""
                }
            }) {
                Image(systemName: text.isEmpty ? "circle" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(text.isEmpty ? .white.opacity(0.5) : Color(red: 1.0, green: 0.84, blue: 0.0))
            }
            .disabled(text.isEmpty)
        }
        .padding()
    }
}

// MARK: - Voice Video Panel View

struct VoiceVideoPanelView: View {
    @State private var isMuted = false
    @State private var isVideoOn = false
    @State private var isConnected = true
    
    var body: some View {
        VStack(spacing: 16) {
            if isConnected {
                HStack(spacing: 24) {
                    Button(action: { isMuted.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.title2)
                                .foregroundColor(isMuted ? .red : .white)
                                .frame(width: 50, height: 50)
                                .glass(material: .thin, tint: .none, border: .subtle, cornerRadius: 25)
                            
                            Text(isMuted ? "Unmute" : "Mute")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Button(action: {}) {
                        VStack(spacing: 4) {
                            Image(systemName: "phone.down.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(.red)
                                .clipShape(Circle())
                            
                            Text("Leave")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Button(action: { isVideoOn.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: isVideoOn ? "video.fill" : "video.slash.fill")
                                .font(.title2)
                                .foregroundColor(isVideoOn ? .white : .white.opacity(0.7))
                                .frame(width: 50, height: 50)
                                .glass(material: .thin, tint: .none, border: .subtle, cornerRadius: 25)
                            
                            Text("Video")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .glassPanel(tint: .brand)
            } else {
                Button(action: { isConnected = true }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Join Audio")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glass(material: .regular, tint: .custom(.green), border: .none, cornerRadius: 20)
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var aiModeration = false
    @State private var lowBandwidth = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 16) {
                        SettingsSection(title: "Rooms") {
                            Toggle("AI Moderation", isOn: $aiModeration)
                                .tint(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .padding()
                                .glassCard()
                        }
                        
                        SettingsSection(title: "Performance") {
                            Toggle("Low-bandwidth mode", isOn: $lowBandwidth)
                                .tint(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .padding()
                                .glassCard()
                        }
                        
                        SettingsSection(title: "Privacy") {
                            NavigationLink(destination: PrivacySettingsView()) {
                                HStack {
                                    Text("Privacy & Security")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding()
                                .glassCard()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal)
            
            content
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                )
                            
                            Text("User Name")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("@username")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                        .glassCard()
                        
                        NavigationLink(destination: SettingsView()) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Settings")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding()
                            .glassCard()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Search View

struct SearchView: View {
    @State private var searchText = ""
    @State private var results: [Room] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                VStack(spacing: 16) {
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .glassInput(tint: .light)
                        .padding()
                        .onChange(of: searchText) { _, newValue in
                            if !newValue.isEmpty {
                                performSearch(newValue)
                            } else {
                                results = []
                            }
                        }
                    
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if results.isEmpty && !searchText.isEmpty {
                        EmptyStateView(message: "No results found")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(results) { room in
                                    RoomRow(room: room)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Search")
        }
    }
    
    private func performSearch(_ query: String) {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            results = MockDataGenerator.generateRooms().filter { room in
                room.name?.lowercased().contains(query.lowercased()) ?? false
            }
            isLoading = false
        }
    }
}

// MARK: - Thread View

struct ThreadView: View {
    let parentMessage: Message
    @State private var threadMessages: [Message] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                if isLoading {
                    VStack {
                        ForEach(0..<3) { _ in
                            LoadingSkeleton(width: nil, height: 60)
                        }
                    }
                    .padding()
                } else if threadMessages.isEmpty {
                    EmptyStateView(message: "No replies yet")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            MessageBubbleView(message: parentMessage)
                            
                            ForEach(threadMessages) { message in
                                MessageBubbleView(message: message)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Thread")
        }
        .task {
            await loadThread()
        }
    }
    
    private func loadThread() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        threadMessages = MockDataGenerator.generateMessages(count: 5, roomId: parentMessage.id)
        isLoading = false
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MetricCard(title: "Messages", value: "1,234")
                        MetricCard(title: "Rooms", value: "12")
                        MetricCard(title: "Users", value: "456")
                        MetricCard(title: "Activity", value: "98%")
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard()
    }
}

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {
    @State private var e2eeEnabled = true
    @State private var metadataScrubbing = true
    @State private var sealedSender = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 16) {
                        SettingsSection(title: "Encryption") {
                            Toggle("End-to-End Encryption", isOn: $e2eeEnabled)
                                .tint(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .padding()
                                .glassCard()
                            
                            Toggle("Sealed Sender", isOn: $sealedSender)
                                .tint(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .padding()
                                .glassCard()
                        }
                        
                        SettingsSection(title: "Metadata") {
                            Toggle("Metadata Scrubbing", isOn: $metadataScrubbing)
                                .tint(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .padding()
                                .glassCard()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Privacy & Security")
        }
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    @State private var selectedTier = "pro"
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Choose Your Plan")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.top)
                        
                        VStack(spacing: 16) {
                            TierCard(
                                name: "Free",
                                price: "$0",
                                features: ["Basic messaging", "5 rooms"],
                                isSelected: selectedTier == "free",
                                action: { selectedTier = "free" }
                            )
                            
                            TierCard(
                                name: "Pro",
                                price: "$9.99/mo",
                                features: ["Unlimited rooms", "Voice & video", "AI moderation"],
                                isSelected: selectedTier == "pro",
                                action: { selectedTier = "pro" }
                            )
                            
                            TierCard(
                                name: "Enterprise",
                                price: "Custom",
                                features: ["Self-hosting", "Custom domains", "Priority support"],
                                isSelected: selectedTier == "enterprise",
                                action: { selectedTier = "enterprise" }
                            )
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Subscription")
        }
    }
}

struct TierCard: View {
    let name: String
    let price: String
    let features: [String]
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    }
                }
                
                Text(price)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding()
            .glassCard(tint: isSelected ? .brand : .none)
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showMainApp = false
    
    let pages = [
        OnboardingPage(
            title: "Welcome to VibeZ",
            description: "Privacy-first communication platform",
            icon: "lock.shield.fill"
        ),
        OnboardingPage(
            title: "End-to-End Encryption",
            description: "Your messages are encrypted and private",
            icon: "key.fill"
        ),
        OnboardingPage(
            title: "Glass Morphism UI",
            description: "Beautiful, modern interface",
            icon: "sparkles"
        )
    ]
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            if showMainApp {
                MainTabView()
            } else {
                VStack(spacing: 32) {
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page)
                    
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            showMainApp = true
                        }
                    }) {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .glass(material: .regular, tint: .brand, border: .none, cornerRadius: 25)
                    }
                }
                .padding()
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.white)
                .padding()
                .glassCard()
            
            Text(page.title)
                .font(.title)
                .foregroundColor(.white)
            
            Text(page.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - App Entry Point

@main
struct GlassApp: App {
    var body: some Scene {
        WindowGroup {
            OnboardingView()
        }
    }
}

// MARK: - Preview Providers

#Preview("Main Tab") {
    MainTabView()
}

#Preview("Room List") {
    RoomListView()
}

#Preview("Chat") {
    ChatView(room: MockDataGenerator.generateRooms().first)
}

#Preview("Glass Card") {
    VStack(spacing: 20) {
        Text("Glass Card")
            .padding()
            .glassCard()
        
        Text("Glass Input")
            .padding()
            .glassInput()
        
        Text("Glass Panel")
            .padding()
            .glassPanel()
    }
    .padding()
    .background(AnimatedGradientBackground())
}

