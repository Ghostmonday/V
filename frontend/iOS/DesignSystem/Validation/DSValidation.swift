/**
 * Design System - Validation System
 * 
 * Comprehensive validation utilities for forms, inputs, and data.
 * Incremental validation with real-time feedback.
 */

import SwiftUI
import Foundation

// MARK: - Validation Result

enum DSValidationResult {
    case valid
    case invalid(String) // error message
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Validation Rules

protocol DSValidationRule {
    func validate(_ value: String) -> DSValidationResult
}

// MARK: - Common Validation Rules

struct DSMinLengthRule: DSValidationRule {
    let minLength: Int
    let message: String
    
    init(minLength: Int, message: String? = nil) {
        self.minLength = minLength
        self.message = message ?? "Must be at least \(minLength) characters"
    }
    
    func validate(_ value: String) -> DSValidationResult {
        value.count >= minLength ? .valid : .invalid(message)
    }
}

struct DSMaxLengthRule: DSValidationRule {
    let maxLength: Int
    let message: String
    
    init(maxLength: Int, message: String? = nil) {
        self.maxLength = maxLength
        self.message = message ?? "Must be no more than \(maxLength) characters"
    }
    
    func validate(_ value: String) -> DSValidationResult {
        value.count <= maxLength ? .valid : .invalid(message)
    }
}

struct DSPatternRule: DSValidationRule {
    let pattern: String
    let message: String
    
    init(pattern: String, message: String) {
        self.pattern = pattern
        self.message = message
    }
    
    func validate(_ value: String) -> DSValidationResult {
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: value) ? .valid : .invalid(message)
    }
}

struct DSCustomRule: DSValidationRule {
    let validator: (String) -> DSValidationResult
    
    init(_ validator: @escaping (String) -> DSValidationResult) {
        self.validator = validator
    }
    
    func validate(_ value: String) -> DSValidationResult {
        validator(value)
    }
}

// MARK: - Composite Validator

struct DSCompositeValidator: DSValidationRule {
    let rules: [DSValidationRule]
    
    init(_ rules: DSValidationRule...) {
        self.rules = rules
    }
    
    func validate(_ value: String) -> DSValidationResult {
        for rule in rules {
            let result = rule.validate(value)
            if case .invalid = result {
                return result
            }
        }
        return .valid
    }
}

// MARK: - Predefined Validators

enum DSPredefinedValidators {
    static let email = DSCompositeValidator(
        DSPatternRule(
            pattern: "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$",
            message: "Please enter a valid email address"
        )
    )
    
    static let username = DSCompositeValidator(
        DSMinLengthRule(minLength: 3, message: "Username must be at least 3 characters"),
        DSMaxLengthRule(maxLength: 20, message: "Username must be no more than 20 characters"),
        DSPatternRule(
            pattern: "^[a-zA-Z0-9_]+$",
            message: "Username can only contain letters, numbers, and underscores"
        )
    )
    
    static let roomName = DSCompositeValidator(
        DSMinLengthRule(minLength: 1, message: "Room name cannot be empty"),
        DSMaxLengthRule(maxLength: 50, message: "Room name must be no more than 50 characters")
    )
    
    static let message = DSCompositeValidator(
        DSMinLengthRule(minLength: 1, message: "Message cannot be empty"),
        DSMaxLengthRule(maxLength: 4000, message: "Message must be no more than 4000 characters")
    )
    
    static let password = DSCompositeValidator(
        DSMinLengthRule(minLength: 8, message: "Password must be at least 8 characters"),
        DSPatternRule(
            pattern: ".*[A-Z].*",
            message: "Password must contain at least one uppercase letter"
        ),
        DSPatternRule(
            pattern: ".*[a-z].*",
            message: "Password must contain at least one lowercase letter"
        ),
        DSPatternRule(
            pattern: ".*[0-9].*",
            message: "Password must contain at least one number"
        )
    )
}

// MARK: - Validation State Manager

@MainActor
class DSValidationState: ObservableObject {
    @Published var value: String = ""
    @Published var result: DSValidationResult = .valid
    @Published var isValidating: Bool = false
    @Published var hasBeenTouched: Bool = false
    
    let validator: DSValidationRule
    let debounceInterval: TimeInterval
    
    private var validationTask: Task<Void, Never>?
    
    init(
        validator: DSValidationRule,
        debounceInterval: TimeInterval = 0.3,
        initialValue: String = ""
    ) {
        self.validator = validator
        self.debounceInterval = debounceInterval
        self.value = initialValue
    }
    
    func validate() {
        hasBeenTouched = true
        isValidating = true
        
        // Cancel previous validation task
        validationTask?.cancel()
        
        // Debounce validation
        validationTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            result = validator.validate(value)
            isValidating = false
        }
    }
    
    func reset() {
        value = ""
        result = .valid
        hasBeenTouched = false
        isValidating = false
        validationTask?.cancel()
    }
    
    var shouldShowError: Bool {
        hasBeenTouched && !result.isValid
    }
}

// MARK: - Validation Error View

struct DSValidationErrorView: View {
    let error: String
    let icon: String
    
    init(error: String, icon: String = DSIcon.warning) {
        self.error = error
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: icon)
                .font(DSTypography.caption)
                .foregroundColor(.ds(.stateDanger))
            
            Text(error)
                .font(DSTypography.caption)
                .foregroundColor(.ds(.stateDanger))
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                .fill(Color.ds(.stateDanger).opacity(0.1))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Validation Success Indicator

struct DSValidationSuccessView: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: DSIcon.checkmark)
                .font(DSTypography.caption)
                .foregroundColor(.ds(.stateSuccess))
            
            if let message = message {
                Text(message)
                    .font(DSTypography.caption)
                    .foregroundColor(.ds(.stateSuccess))
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                .fill(Color.ds(.stateSuccess).opacity(0.1))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Form Field with Validation

struct DSValidatedField: View {
    @StateObject private var validationState: DSValidationState
    let title: String
    let placeholder: String
    let isSecure: Bool
    
    @FocusState private var isFocused: Bool
    
    init(
        title: String,
        placeholder: String = "",
        validator: DSValidationRule,
        isSecure: Bool = false
    ) {
        self.title = title
        self.placeholder = placeholder
        self.isSecure = isSecure
        self._validationState = StateObject(wrappedValue: DSValidationState(validator: validator))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(DSTypography.label)
                .foregroundColor(.ds(.textPrimary))
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $validationState.value)
                } else {
                    TextField(placeholder, text: $validationState.value)
                }
            }
            .font(DSTypography.body)
            .foregroundColor(.ds(.textPrimary))
            .focused($isFocused)
            .padding(DSSpacing.sm)
            .background(Color.ds(.bgInput))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.base, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.base, style: .continuous)
                    .stroke(
                        borderColor,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .onChange(of: validationState.value) { _ in
                validationState.validate()
            }
            .onChange(of: isFocused) { focused in
                if !focused {
                    validationState.validate()
                }
            }
            
            // Validation feedback
            if validationState.shouldShowError, let error = validationState.result.errorMessage {
                DSValidationErrorView(error: error)
            } else if validationState.hasBeenTouched && validationState.result.isValid {
                DSValidationSuccessView()
            }
        }
    }
    
    private var borderColor: Color {
        if validationState.shouldShowError {
            return .ds(.stateDanger)
        } else if validationState.hasBeenTouched && validationState.result.isValid {
            return .ds(.stateSuccess)
        } else if isFocused {
            return .ds(.brandPrimary)
        } else {
            return .ds(.controlStroke)
        }
    }
}

