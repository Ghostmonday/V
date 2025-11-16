import Foundation

class SystemService {
    /// Log telemetry event to backend
    static func logTelemetry(event: String, data: [String: String] = [:]) {
        Task {
            do {
                let request = TelemetryLogRequest(event: event)
                try await APIClient.shared.request(
                    endpoint: APIClient.Endpoint.telemetryLog,
                    method: "POST",
                    body: request
                )
            } catch {
                // Fallback to local logging if backend fails
                print("Telemetry log error: \(error)")
                let metric = TelemetryMetric(eventType: event, timestamp: Date(), data: data)
                print("Logged locally: \(metric)")
            }
        }
    }
}

