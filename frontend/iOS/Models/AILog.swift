import Foundation

struct AILog: Codable {
    let query: String
    let response: String
    let latency: Double
}

// AI Chat request/response
struct AIChatRequest: Codable {
    let message: String
    let roomId: String
}

struct AIChatResponse: Codable {
    let status: String
    let message: String?
    let received: AIChatRequest?
}

