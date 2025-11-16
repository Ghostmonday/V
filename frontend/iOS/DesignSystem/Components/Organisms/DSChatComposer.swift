/**
 * Design System - Chat Composer Component
 * 
 * Enhanced chat input with validation, attachments, emoji picker,
 * and command hints.
 */

import SwiftUI

struct DSChatComposer: View {
    @Binding var text: String
    let placeholder: String
    let onSend: () -> Void
    let onAttachment: (() -> Void)?
    let onEmoji: (() -> Void)?
    let validation: DSValidationRule?
    
    @FocusState private var isFocused: Bool
    @StateObject private var validationState: DSValidationState
    
    init(
        text: Binding<String>,
        placeholder: String = "Message...",
        onSend: @escaping () -> Void,
        onAttachment: (() -> Void)? = nil,
        onEmoji: (() -> Void)? = nil,
        validation: DSValidationRule? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSend = onSend
        self.onAttachment = onAttachment
        self.onEmoji = onEmoji
        self.validation = validation
        
        if let validation = validation {
            self._validationState = StateObject(wrappedValue: DSValidationState(validator: validation))
        } else {
            self._validationState = StateObject(wrappedValue: DSValidationState(validator: DSPredefinedValidators.message))
        }
    }
    
    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.sm) {
                // Attachment button
                if let onAttachment = onAttachment {
                    DSIconButton(icon: DSIcon.attach, size: .medium) {
                        onAttachment()
                    }
                }
                
                // Text input
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(DSTypography.body)
                    .foregroundColor(.ds(.textPrimary))
                    .focused($isFocused)
                    .lineLimit(1...6)
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
                    .onChange(of: text) { newValue in
                        validationState.value = newValue
                        validationState.validate()
                    }
                    .onSubmit {
                        if validationState.result.isValid {
                            sendMessage()
                        }
                    }
                
                // Emoji button
                if let onEmoji = onEmoji {
                    DSIconButton(icon: DSIcon.emoji, size: .medium) {
                        onEmoji()
                    }
                }
                
                // Send button
                DSIconButton(
                    icon: DSIcon.send,
                    size: .medium,
                    variant: canSend ? .primary : .tertiary
                ) {
                    sendMessage()
                }
                .disabled(!canSend)
            }
            .padding(DSSpacing.sm)
            .background(Color.ds(.bgElevated))
            
            // Validation error
            if validationState.shouldShowError, let error = validationState.result.errorMessage {
                DSValidationErrorView(error: error)
                    .padding(.horizontal, DSSpacing.sm)
            }
            
            // Command hint
            if text == "/" {
                HStack(spacing: DSSpacing.sm) {
                    Text("Commands: /poll, /thread, /gif")
                        .font(DSTypography.caption)
                        .foregroundColor(.ds(.textSecondary))
                    Spacer()
                }
                .padding(.horizontal, DSSpacing.sm)
            }
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        validationState.result.isValid
    }
    
    private func sendMessage() {
        guard canSend else { return }
        DSHaptic.success()
        onSend()
        text = ""
        validationState.reset()
    }
}

