import SwiftUI

/// Error Recovery View - Shows error with retry option
struct ErrorRecoveryView: View {
    let error: Error
    let retryAction: () -> Void
    let dismissAction: (() -> Void)?
    
    init(error: Error, retryAction: @escaping () -> Void, dismissAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("VibeZGold"))
                .accessibilityLabel("Retry")
                .accessibilityHint("Double tap to try again")
                
                if let dismiss = dismissAction {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Dismiss")
                    .accessibilityHint("Double tap to close")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(errorMessage)")
    }
    
    private var errorMessage: String {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL:
                return "Invalid request URL"
            case .invalidResponse:
                return "Invalid server response"
            case .httpError(let statusCode):
                return "Server error (\(statusCode))"
            case .decodingError:
                return "Failed to parse response"
            }
        }
        return error.localizedDescription
    }
}

/// Error Recovery Modifier
extension View {
    func errorRecovery(error: Error?, retry: @escaping () -> Void, dismiss: (() -> Void)? = nil) -> some View {
        self.overlay(
            Group {
                if let error = error {
                    ErrorRecoveryView(error: error, retryAction: retry, dismissAction: dismiss)
                        .padding()
                        .transition(.opacity.combined(with: .scale))
                }
            }
        )
    }
}

#Preview {
    ErrorRecoveryView(
        error: APIError.httpError(statusCode: 500),
        retryAction: { print("Retry") },
        dismissAction: { print("Dismiss") }
    )
}

