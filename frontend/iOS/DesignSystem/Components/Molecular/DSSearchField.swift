/**
 * Design System - Search Field Component
 * 
 * Enhanced search field with validation, clear button, and loading states.
 */

import SwiftUI

struct DSSearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSearch: (() -> Void)?
    let validation: ValidationRule?
    
    @FocusState private var isFocused: Bool
    @State private var validationError: String?
    
    enum ValidationRule {
        case minLength(Int)
        case maxLength(Int)
        case pattern(String, String) // pattern, error message
        case custom((String) -> String?) // validator function
        
        func validate(_ text: String) -> String? {
            switch self {
            case .minLength(let min):
                return text.count < min ? "Must be at least \(min) characters" : nil
            case .maxLength(let max):
                return text.count > max ? "Must be no more than \(max) characters" : nil
            case .pattern(let pattern, let error):
                let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
                return predicate.evaluate(with: text) ? nil : error
            case .custom(let validator):
                return validator(text)
            }
        }
    }
    
    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSearch: (() -> Void)? = nil,
        validation: ValidationRule? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSearch = onSearch
        self.validation = validation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: DSIcon.search)
                    .foregroundColor(.ds(.textSecondary))
                    .font(DSTypography.body)
                
                TextField(placeholder, text: $text)
                    .font(DSTypography.body)
                    .foregroundColor(.ds(.textPrimary))
                    .focused($isFocused)
                    .onSubmit {
                        validate()
                        onSearch?()
                    }
                    .onChange(of: text) { _ in
                        validate()
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        validationError = nil
                        isFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.ds(.textSecondary))
                            .font(DSTypography.body)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DSSpacing.sm)
            .background(Color.ds(.bgInput))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.base, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.base, style: .continuous)
                    .stroke(
                        isFocused ? Color.ds(.brandPrimary) : Color.ds(.controlStroke),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            
            // Validation error
            if let error = validationError {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: DSIcon.warning)
                        .font(DSTypography.caption)
                        .foregroundColor(.ds(.stateDanger))
                    
                    Text(error)
                        .font(DSTypography.caption)
                        .foregroundColor(.ds(.stateDanger))
                }
                .padding(.leading, DSSpacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(DSAnimation.spring, value: validationError != nil)
    }
    
    private func validate() {
        guard let rule = validation else {
            validationError = nil
            return
        }
        
        validationError = rule.validate(text)
    }
    
    var isValid: Bool {
        validationError == nil
    }
}

