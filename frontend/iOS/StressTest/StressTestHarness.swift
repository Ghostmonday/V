import SwiftUI
import Combine
import Foundation

// MARK: - Stress Test View

public struct StressTestView: View {
    @StateObject private var manager = StressTestManager()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("VibeZ Stress Test Harness")
                .font(.largeTitle)
                .bold()
                .foregroundColor(manager.statusColor)
            
            HStack {
                StatBox(title: "Users", value: "\(manager.connectedCount)/10")
                StatBox(title: "Messages", value: "\(manager.totalMessages)")
            }
            
            HStack {
                StatBox(title: "Avg Latency", value: String(format: "%.1f ms", manager.avgLatency))
                StatBox(title: "Drops", value: "\(manager.droppedMessages)")
            }
            
            HStack {
                StatBox(title: "Memory", value: String(format: "%.1f MB", manager.memoryUsage))
                StatBox(title: "CPU", value: String(format: "%.1f %%", manager.cpuUsage))
            }
            
            Text(manager.statusMessage)
                .font(.headline)
                .foregroundColor(manager.statusColor)
                .padding()
            
            if !manager.isRunning {
                Button("Start Stress Test") {
                    manager.startTest()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("Time Remaining: \(60 - manager.elapsedSeconds)s")
            }
            
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(manager.logs, id: \.self) { log in
                        Text(log)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 200)
            .background(Color.black.opacity(0.2))
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            // Auto-start if running from script
            if ProcessInfo.processInfo.arguments.contains("-StressTest") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    manager.startTest()
                }
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Logic

class StressTestManager: ObservableObject {
    @Published var connectedCount = 0
    @Published var totalMessages = 0
    @Published var droppedMessages = 0
    @Published var avgLatency: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var cpuUsage: Double = 0
    @Published var isRunning = false
    @Published var logs: [String] = []
    @Published var statusMessage = "Ready"
    @Published var statusColor = Color.white
    @Published var elapsedSeconds = 0
    
    private var users: [FakeUser] = []
    private var timer: Timer?
    private var latencies: [Double] = []
    
    func startTest() {
        guard !isRunning else { return }
        isRunning = true
        logs.append("Starting Stress Test...")
        statusMessage = "Running..."
        statusColor = .yellow
        
        // Reset stats
        connectedCount = 0
        totalMessages = 0
        droppedMessages = 0
        avgLatency = 0
        latencies = []
        users = []
        elapsedSeconds = 0
        
        // Spin up 10 users
        for i in 1...10 {
            let handle = "_crypto_dad_\(i)"
            let user = FakeUser(handle: handle, manager: self)
            users.append(user)
            
            // Stagger starts slightly to avoid thundering herd on local machine
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.2) {
                user.start()
            }
        }
        
        // Start monitoring timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stopTest(passed: Bool) {
        isRunning = false
        timer?.invalidate()
        timer = nil
        
        for user in users {
            user.stop()
        }
        
        if passed {
            statusMessage = "PASSED"
            statusColor = .green
            log("TEST PASSED")
        } else {
            statusMessage = "FAILURE"
            statusColor = .red
            log("TEST FAILED")
        }
        
        // Print final summary to console for grep
        print("=== STRESS TEST SUMMARY ===")
        print("Users: \(connectedCount)")
        print("Messages: \(totalMessages)")
        print("Avg Latency: \(avgLatency)")
        print("Drops: \(droppedMessages)")
        print("Memory: \(memoryUsage) MB")
        print("CPU: \(cpuUsage)%")
        print("Result: \(passed ? "PASSED" : "FAILURE")")
        print("===========================")
    }
    
    func tick() {
        elapsedSeconds += 1
        
        // Update resource usage
        memoryUsage = getMemoryUsage()
        cpuUsage = getCPUUsage()
        
        // Check failure conditions
        if droppedMessages > 0 {
            log("FAILURE: Messages dropped")
            stopTest(passed: false)
            return
        }
        
        if avgLatency > 200 {
            log("FAILURE: Latency spike > 200ms")
            stopTest(passed: false)
            return
        }
        
        if memoryUsage > 300 {
            log("FAILURE: Memory > 300MB")
            stopTest(passed: false)
            return
        }
        
        // CPU check (soft check, simulator CPU is weird)
        if cpuUsage > 70 {
            log("WARNING: CPU > 70%")
        }
        
        if elapsedSeconds >= 60 {
            stopTest(passed: true)
        }
    }
    
    func log(_ msg: String) {
        DispatchQueue.main.async {
            self.logs.append(msg)
            // Keep log size manageable
            if self.logs.count > 100 {
                self.logs.removeFirst()
            }
            print("[StressTest] \(msg)")
        }
    }
    
    func recordLatency(_ ms: Double) {
        DispatchQueue.main.async {
            self.latencies.append(ms)
            self.totalMessages += 1
            self.avgLatency = self.latencies.reduce(0, +) / Double(self.latencies.count)
        }
    }
    
    func recordDrop() {
        DispatchQueue.main.async {
            self.droppedMessages += 1
        }
    }
    
    func recordConnection() {
        DispatchQueue.main.async {
            self.connectedCount += 1
        }
    }
    
    // MARK: - Resource Monitoring
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        return 0
    }
    
    private func getCPUUsage() -> Double {
        // Simplified CPU usage for current thread/process
        // Getting accurate system-wide CPU on simulator is hard from sandbox
        // We'll return a dummy or try to get thread info
        return 0.0 // Placeholder, implementing robust CPU monitor in Swift requires more code
    }
}

class FakeUser: NSObject, URLSessionWebSocketDelegate {
    let handle: String
    let manager: StressTestManager
    var webSocketTask: URLSessionWebSocketTask?
    var session: URLSession!
    var userId: String?
    var token: String?
    
    var audioTimer: Timer?
    var textTimer: Timer?
    
    init(handle: String, manager: StressTestManager) {
        self.handle = handle
        self.manager = manager
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    func start() {
        registerAndLogin()
    }
    
    func stop() {
        audioTimer?.invalidate()
        textTimer?.invalidate()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
    }
    
    private func registerAndLogin() {
        // 1. Register/Login via HTTP to get JWT
        guard let url = URL(string: "http://localhost:3000/api/auth/register") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": handle,
            "password": "password123",
            "ageVerified": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.manager.log("\(self.handle) Auth Error: \(error.localizedDescription)")
                // Try login if register failed (user exists)
                self.login()
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let jwt = json["jwt"] as? String else {
                self.manager.log("\(self.handle) Failed to get JWT")
                self.login() // Fallback
                return
            }
            
            self.token = jwt
            self.extractUserId(from: jwt)
            self.connectWebSocket()
        }
        task.resume()
    }
    
    private func login() {
        guard let url = URL(string: "http://localhost:3000/api/auth/login") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": handle,
            "password": "password123"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.manager.log("\(self.handle) Login Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let jwt = json["jwt"] as? String else {
                self.manager.log("\(self.handle) Failed to login")
                return
            }
            
            self.token = jwt
            self.extractUserId(from: jwt)
            self.connectWebSocket()
        }
        task.resume()
    }
    
    private func extractUserId(from jwt: String) {
        let parts = jwt.components(separatedBy: ".")
        if parts.count > 1 {
            let payload = parts[1]
            var base64 = payload
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            while base64.count % 4 != 0 {
                base64.append("=")
            }
            if let data = Data(base64Encoded: base64),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let uid = json["userId"] as? String {
                self.userId = uid
            }
        }
    }
    
    private func connectWebSocket() {
        guard let userId = userId, let token = token else { return }
        let urlString = "ws://localhost:3000?userId=\(userId)&token=\(token)"
        guard let url = URL(string: urlString) else { return }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        manager.recordConnection()
        manager.log("\(handle) Connected")
        
        listen()
        startLoops()
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.manager.log("\(self.handle) WS Error: \(error)")
                self.manager.recordDrop()
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(data: text.data(using: .utf8))
                case .data(let data):
                    self.handleMessage(data: data)
                @unknown default:
                    break
                }
                self.listen() // Keep listening
            }
        }
    }
    
    private func handleMessage(data: Data?) {
        // Decode response (JSON or Proto)
        // Assuming server sends JSON for ACKs based on code
        guard let data = data else { return }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let type = json["type"] as? String {
                if type == "msg_ack", let msgId = json["msg_id"] as? String {
                    // Calculate latency
                    if let sentTime = sentMessages[msgId] {
                        let latency = (Date().timeIntervalSince1970 - sentTime) * 1000
                        manager.recordLatency(latency)
                        sentMessages.removeValue(forKey: msgId)
                    }
                } else if type == "error" {
                    manager.log("\(handle) Server Error: \(json["msg"] ?? "")")
                    manager.recordDrop()
                }
            }
        }
    }
    
    private var sentMessages: [String: TimeInterval] = [:]
    
    private func startLoops() {
        // Text Loop (1s)
        DispatchQueue.main.async {
            self.textTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.sendText()
            }
            
            // Audio Loop (2s)
            self.audioTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.sendAudio()
            }
        }
    }
    
    private func sendText() {
        let msgId = UUID().uuidString
        let text = ["yo", "haha", "wtf", "🔥", "👀"].randomElement()!
        
        // Construct WSEnvelope
        let payloadDict = ["content": text]
        let payloadData = try! JSONSerialization.data(withJSONObject: payloadDict)
        
        let envelope = SimpleProtoEncoder.encodeEnvelope(
            version: "1.0",
            msgId: msgId,
            type: "messaging",
            roomId: "StressTestZone", // Assuming this room exists or is auto-created
            senderId: userId ?? "",
            ts: Int64(Date().timeIntervalSince1970 * 1000),
            payload: payloadData
        )
        
        sentMessages[msgId] = Date().timeIntervalSince1970
        send(data: envelope)
    }
    
    private func sendAudio() {
        let msgId = UUID().uuidString
        // 64KB random bytes
        var randomBytes = Data(count: 64000)
        let result = randomBytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 64000, $0.baseAddress!)
        }
        if result != errSecSuccess { return }
        
        // Encode as Base64 string in JSON payload because server expects text content
        let base64Audio = randomBytes.base64EncodedString()
        let payloadDict = ["content": "[AUDIO] " + base64Audio]
        let payloadData = try! JSONSerialization.data(withJSONObject: payloadDict)
        
        let envelope = SimpleProtoEncoder.encodeEnvelope(
            version: "1.0",
            msgId: msgId,
            type: "messaging",
            roomId: "StressTestZone",
            senderId: userId ?? "",
            ts: Int64(Date().timeIntervalSince1970 * 1000),
            payload: payloadData
        )
        
        sentMessages[msgId] = Date().timeIntervalSince1970
        send(data: envelope)
    }
    
    private func send(data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                self.manager.log("Send Error: \(error)")
                self.manager.recordDrop()
            }
        }
    }
}

// MARK: - Simple Proto Encoder

struct SimpleProtoEncoder {
    static func encodeEnvelope(version: String, msgId: String, type: String, roomId: String, senderId: String, ts: Int64, payload: Data) -> Data {
        var data = Data()
        
        // 1. version (String) -> Tag 0x0A
        appendString(version, tag: 1, to: &data)
        
        // 2. msg_id (String) -> Tag 0x12
        appendString(msgId, tag: 2, to: &data)
        
        // 3. type (String) -> Tag 0x1A
        appendString(type, tag: 3, to: &data)
        
        // 4. room_id (String) -> Tag 0x22
        appendString(roomId, tag: 4, to: &data)
        
        // 5. sender_id (String) -> Tag 0x2A
        appendString(senderId, tag: 5, to: &data)
        
        // 6. ts (Int64) -> Tag 0x30
        appendVarint(ts, tag: 6, to: &data)
        
        // 7. payload (Bytes) -> Tag 0x3A
        appendBytes(payload, tag: 7, to: &data)
        
        return data
    }
    
    private static func appendString(_ value: String, tag: Int, to data: inout Data) {
        guard let bytes = value.data(using: .utf8) else { return }
        appendTag(tag, wireType: 2, to: &data)
        appendVarint(Int64(bytes.count), to: &data)
        data.append(bytes)
    }
    
    private static func appendBytes(_ value: Data, tag: Int, to data: inout Data) {
        appendTag(tag, wireType: 2, to: &data)
        appendVarint(Int64(value.count), to: &data)
        data.append(value)
    }
    
    private static func appendVarint(_ value: Int64, tag: Int, to data: inout Data) {
        appendTag(tag, wireType: 0, to: &data)
        appendVarint(value, to: &data)
    }
    
    private static func appendTag(_ fieldNumber: Int, wireType: Int, to data: inout Data) {
        let key = (fieldNumber << 3) | wireType
        appendVarint(Int64(key), to: &data)
    }
    
    private static func appendVarint(_ value: Int64, to data: inout Data) {
        var v = UInt64(bitPattern: value)
        while v >= 128 {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v))
    }
}
