import Foundation

struct TelemetryMetric: Codable {
    let eventType: String
    let timestamp: Date
    let data: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case eventType = "event"
        case timestamp
        case data
    }
}

// Backend expects: { "event": "event_name" }
struct TelemetryLogRequest: Codable {
    let event: String
}

