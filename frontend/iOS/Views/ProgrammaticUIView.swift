import SwiftUI

/// Programmatic UI View
/// Migrated from src/components/ProgrammaticUI.vue
/// Demonstrates all component states with full telemetry integration
struct ProgrammaticUIView: View {
    // Button States
    @State private var primaryButtonState: ButtonState = .idle
    @State private var secondaryButtonState: ButtonState = .idle
    @State private var iconButtonState: ButtonState = .idle
    
    // Input States
    @State private var textInputState: InputState = .idle
    @State private var passwordInputState: InputState = .idle
    @State private var textareaState: InputState = .idle
    
    // Form State
    @State private var formState: FormState = .idle
    
    // Values
    @State private var textInputValue: String = ""
    @State private var passwordInputValue: String = ""
    @State private var textareaValue: String = ""
    @State private var formEmail: String = ""
    @State private var formMessage: String = ""
    
    // Dynamic Connectors
    @State private var primaryButtonText: String = "Click Me"
    @State private var secondaryButtonText: String = "Secondary"
    
    // Focus States
    @FocusState private var textInputFocused: Bool
    @FocusState private var passwordInputFocused: Bool
    @FocusState private var textareaFocused: Bool
    @FocusState private var formEmailFocused: Bool
    @FocusState private var formMessageFocused: Bool
    
    // Hover States (for macOS/iPad with pointer)
    @State private var primaryButtonHovered: Bool = false
    @State private var secondaryButtonHovered: Bool = false
    @State private var iconButtonHovered: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Stats Panel
                statsPanel
                
                // Main Screen
                VStack(alignment: .leading, spacing: 32) {
                    Text("Programmatic UI - All States")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Buttons Section
                    buttonsSection
                    
                    // Inputs Section
                    inputsSection
                    
                    // Form Section
                    formSection
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Stats Panel
    
    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UI Component Statistics")
                .font(.headline)
            
            Text(statsReport)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .padding()
    }
    
    private var statsReport: String {
        let totalStates = 6 + 6 + 6 + 6 + 6 + 6 + 5 + 4 // 45 states
        let totalLines = 900 // Approximate
        
        return """
        ═══════════════════════════════════════════════════════════
        PROGRAMMATIC UI - COMPONENT STATISTICS
        ═══════════════════════════════════════════════════════════
        
        TOTAL LINES OF CODE: \(totalLines)
        
        ═══════════════════════════════════════════════════════════
        COMPONENT STATES ENUMERATED
        ═══════════════════════════════════════════════════════════
        
        BUTTONS:
          Primary Button: idle, hover, pressed, loading, error, disabled
          Secondary Button: idle, hover, pressed, loading, error, disabled
          Icon Button: idle, hover, pressed, loading, error, disabled
        
        INPUTS:
          Text Input: idle, focus, filled, error, disabled, loading
          Password Input: idle, focus, filled, error, disabled, loading
          Textarea: idle, focus, filled, error, disabled, loading
        
        FORM:
          Demo Form: idle, submitting, success, error
        
        ═══════════════════════════════════════════════════════════
        TOTAL COMPONENT STATES: \(totalStates)
        ═══════════════════════════════════════════════════════════
        
        CURSOR CHANGE POINTS: 8
        ═══════════════════════════════════════════════════════════
        """
    }
    
    // MARK: - Buttons Section
    
    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Buttons")
                .font(.title2)
                .fontWeight(.bold)
            
            // Primary Button
            buttonGroup(
                title: "Primary Button",
                state: $primaryButtonState,
                text: primaryButtonText,
                action: handlePrimaryClick,
                componentId: "PrimaryButton",
                type: .primary
            )
            
            // Secondary Button
            buttonGroup(
                title: "Secondary Button",
                state: $secondaryButtonState,
                text: secondaryButtonText,
                action: handleSecondaryClick,
                componentId: "SecondaryButton",
                type: .secondary
            )
            
            // Icon Button
            buttonGroup(
                title: "Icon Button",
                state: $iconButtonState,
                text: "⚙️",
                action: handleIconClick,
                componentId: "IconButton",
                type: .icon
            )
        }
    }
    
    private func buttonGroup(
        title: String,
        state: Binding<ButtonState>,
        text: String,
        action: @escaping () -> Void,
        componentId: String,
        type: ButtonStateModifier.ButtonType
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            // Main button
            Button(action: action) {
                HStack {
                    if state.wrappedValue == .loading {
                        LoadingSpinner(size: 16, color: .white)
                    } else if state.wrappedValue == .error {
                        Text("⚠️")
                    } else {
                        Text(text)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonState(state.wrappedValue, type: type)
            .disabled(state.wrappedValue == .disabled)
            .onHover { hovering in
                if state.wrappedValue == .idle || state.wrappedValue == .hover {
                    setPrimaryButtonHover(hovering, componentId: componentId)
                }
            }
            
            // State Controls
            HStack(spacing: 8) {
                stateControlButton("Idle", state: state, targetState: .idle, componentId: componentId)
                stateControlButton("Loading", state: state, targetState: .loading, componentId: componentId)
                stateControlButton("Error", state: state, targetState: .error, componentId: componentId)
                stateControlButton("Disabled", state: state, targetState: .disabled, componentId: componentId)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func stateControlButton(
        _ label: String,
        state: Binding<ButtonState>,
        targetState: ButtonState,
        componentId: String
    ) -> some View {
        Button(label) {
            setButtonState(state, to: targetState, componentId: componentId)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(4)
    }
    
    // MARK: - Inputs Section
    
    private var inputsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Inputs")
                .font(.title2)
                .fontWeight(.bold)
            
            // Text Input
            inputGroup(
                title: "Text Input",
                value: $textInputValue,
                state: $textInputState,
                focused: $textInputFocused,
                placeholder: "Enter text...",
                componentId: "TextInput"
            )
            
            // Password Input
            inputGroup(
                title: "Password Input",
                value: $passwordInputValue,
                state: $passwordInputState,
                focused: $passwordInputFocused,
                placeholder: "Enter password...",
                componentId: "PasswordInput",
                isSecure: true
            )
            
            // Textarea
            textareaGroup(
                title: "Textarea",
                value: $textareaValue,
                state: $textareaState,
                focused: $textareaFocused,
                componentId: "Textarea"
            )
        }
    }
    
    private func inputGroup(
        title: String,
        value: Binding<String>,
        state: Binding<InputState>,
        focused: FocusState<Bool>.Binding,
        placeholder: String,
        componentId: String,
        isSecure: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            if isSecure {
                SecureField(placeholder, text: value)
                    .focused(focused)
                    .textFieldStyle(.plain)
                    .inputState(state.wrappedValue)
                    .disabled(state.wrappedValue == .disabled)
                    .onChange(of: value.wrappedValue) { _ in
                        handleInputChange(value, state: state, componentId: componentId)
                    }
                    .onChange(of: focused.wrappedValue) { isFocused in
                        handleInputFocus(isFocused, state: state, componentId: componentId)
                    }
            } else {
                TextField(placeholder, text: value)
                    .focused(focused)
                    .textFieldStyle(.plain)
                    .inputState(state.wrappedValue)
                    .disabled(state.wrappedValue == .disabled)
                    .onChange(of: value.wrappedValue) { _ in
                        handleInputChange(value, state: state, componentId: componentId)
                    }
                    .onChange(of: focused.wrappedValue) { isFocused in
                        handleInputFocus(isFocused, state: state, componentId: componentId)
                    }
            }
            
            // State Controls
            HStack(spacing: 8) {
                inputStateControlButton("Idle", state: state, targetState: .idle, componentId: componentId)
                inputStateControlButton("Error", state: state, targetState: .error, componentId: componentId)
                inputStateControlButton("Disabled", state: state, targetState: .disabled, componentId: componentId)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func textareaGroup(
        title: String,
        value: Binding<String>,
        state: Binding<InputState>,
        focused: FocusState<Bool>.Binding,
        componentId: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            TextEditor(text: value)
                .focused(focused)
                .frame(minHeight: 100)
                .inputState(state.wrappedValue)
                .disabled(state.wrappedValue == .disabled)
                .onChange(of: value.wrappedValue) { _ in
                    handleInputChange(value, state: state, componentId: componentId)
                }
                .onChange(of: focused.wrappedValue) { isFocused in
                    handleInputFocus(isFocused, state: state, componentId: componentId)
                }
            
            // State Controls
            HStack(spacing: 8) {
                inputStateControlButton("Idle", state: state, targetState: .idle, componentId: componentId)
                inputStateControlButton("Error", state: state, targetState: .error, componentId: componentId)
                inputStateControlButton("Disabled", state: state, targetState: .disabled, componentId: componentId)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func inputStateControlButton(
        _ label: String,
        state: Binding<InputState>,
        targetState: InputState,
        componentId: String
    ) -> some View {
        Button(label) {
            setInputState(state, to: targetState, componentId: componentId)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(4)
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Form")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Demo Form")
                    .font(.headline)
                
                // Email Field
                TextField("Email", text: $formEmail)
                    .focused($formEmailFocused)
                    .textFieldStyle(.plain)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .inputState(formEmail.isEmpty ? .idle : .filled)
                    .disabled(formState == .submitting)
                
                // Message Field
                TextEditor(text: $formMessage)
                    .focused($formMessageFocused)
                    .frame(minHeight: 100)
                    .inputState(formMessage.isEmpty ? .idle : .filled)
                    .disabled(formState == .submitting)
                
                // Submit Button
                Button(action: handleSubmit) {
                    HStack {
                        if formState == .submitting {
                            LoadingSpinner(size: 16, color: .white)
                            Text("Submitting...")
                        } else if formState == .success {
                            Text("✓ Success")
                        } else if formState == .error {
                            Text("⚠️ Error")
                        } else {
                            Text("Submit")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonState(
                    formState == .submitting ? .loading :
                    formState == .error ? .error :
                    formState == .success ? .idle : .idle,
                    type: .primary
                )
                .disabled(formState == .submitting)
                .formState(formState)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Button Handlers
    
    private func handlePrimaryClick() {
        let prevState = primaryButtonState
        
        // Log click
        UXTelemetryService.logClick(
            componentId: "PrimaryButton",
            metadata: ["buttonType": "primary"]
        )
        
        guard primaryButtonState == .idle else { return }
        
        primaryButtonState = .loading
        
        // Log state transition
        UXTelemetryService.logStateTransition(
            componentId: "PrimaryButton",
            stateBefore: prevState.rawValue,
            stateAfter: ButtonState.loading.rawValue,
            category: .uiState,
            metadata: ["buttonType": "primary", "action": "click"]
        )
        
        // Simulate async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let loadingState = self.primaryButtonState
            self.primaryButtonState = .idle
            
            // Log completion
            UXTelemetryService.logStateTransition(
                componentId: "PrimaryButton",
                stateBefore: loadingState.rawValue,
                stateAfter: ButtonState.idle.rawValue,
                category: .uiState,
                metadata: ["buttonType": "primary", "action": "complete"]
            )
        }
    }
    
    private func handleSecondaryClick() {
        let prevState = secondaryButtonState
        
        UXTelemetryService.logClick(
            componentId: "SecondaryButton",
            metadata: ["buttonType": "secondary"]
        )
        
        guard secondaryButtonState == .idle else { return }
        
        secondaryButtonState = .loading
        
        UXTelemetryService.logStateTransition(
            componentId: "SecondaryButton",
            stateBefore: prevState.rawValue,
            stateAfter: ButtonState.loading.rawValue,
            category: .uiState,
            metadata: ["buttonType": "secondary", "action": "click"]
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let loadingState = self.secondaryButtonState
            self.secondaryButtonState = .idle
            
            UXTelemetryService.logStateTransition(
                componentId: "SecondaryButton",
                stateBefore: loadingState.rawValue,
                stateAfter: ButtonState.idle.rawValue,
                category: .uiState,
                metadata: ["buttonType": "secondary", "action": "complete"]
            )
        }
    }
    
    private func handleIconClick() {
        let prevState = iconButtonState
        
        UXTelemetryService.logClick(
            componentId: "IconButton",
            metadata: ["buttonType": "icon"]
        )
        
        guard iconButtonState == .idle else { return }
        
        iconButtonState = .loading
        
        UXTelemetryService.logStateTransition(
            componentId: "IconButton",
            stateBefore: prevState.rawValue,
            stateAfter: ButtonState.loading.rawValue,
            category: .uiState,
            metadata: ["buttonType": "icon", "action": "click"]
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let loadingState = self.iconButtonState
            self.iconButtonState = .idle
            
            UXTelemetryService.logStateTransition(
                componentId: "IconButton",
                stateBefore: loadingState.rawValue,
                stateAfter: ButtonState.idle.rawValue,
                category: .uiState,
                metadata: ["buttonType": "icon", "action": "complete"]
            )
        }
    }
    
    // MARK: - Input Handlers
    
    private func handleInputChange(_ value: Binding<String>, state: Binding<InputState>, componentId: String) {
        let prevState = state.wrappedValue
        let newState: InputState = value.wrappedValue.isEmpty ? .idle : .filled
        
        if prevState != newState {
            state.wrappedValue = newState
            
            UXTelemetryService.logStateTransition(
                componentId: componentId,
                stateBefore: prevState.rawValue,
                stateAfter: newState.rawValue,
                category: .uiState,
                metadata: ["valueLength": value.wrappedValue.count]
            )
        }
    }
    
    private func handleInputFocus(_ isFocused: Bool, state: Binding<InputState>, componentId: String) {
        let prevState = state.wrappedValue
        
        if isFocused {
            state.wrappedValue = .focus
            
            UXTelemetryService.logStateTransition(
                componentId: componentId,
                stateBefore: prevState.rawValue,
                stateAfter: InputState.focus.rawValue,
                category: .uiState,
                metadata: ["action": "focus"]
            )
        } else {
            // On blur, set to idle or filled based on value
            // This will be handled by handleInputChange
        }
    }
    
    // MARK: - Form Handler
    
    private func handleSubmit() {
        let prevState = formState
        formState = .submitting
        
        // Log form submission start
        UXTelemetryService.logStateTransition(
            componentId: "DemoForm",
            stateBefore: prevState.rawValue,
            stateAfter: FormState.submitting.rawValue,
            category: .clickstream,
            metadata: [
                "formId": "demo-form",
                "email": formEmail.isEmpty ? "empty" : "provided",
                "message": formMessage.isEmpty ? "empty" : "provided"
            ]
        )
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Random success/failure
            let success = Bool.random()
            self.formState = success ? .success : .error
            
            // Log result
            UXTelemetryService.logStateTransition(
                componentId: "DemoForm",
                stateBefore: FormState.submitting.rawValue,
                stateAfter: self.formState.rawValue,
                category: .clickstream,
                metadata: ["formId": "demo-form", "success": success, "duration": 2000]
            )
            
            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let completedState = self.formState
                self.formState = .idle
                
                UXTelemetryService.logStateTransition(
                    componentId: "DemoForm",
                    stateBefore: completedState.rawValue,
                    stateAfter: FormState.idle.rawValue,
                    category: .uiState,
                    metadata: ["formId": "demo-form", "action": "reset"]
                )
            }
        }
    }
    
    // MARK: - State Setters
    
    private func setButtonState(_ state: Binding<ButtonState>, to newState: ButtonState, componentId: String) {
        let prevState = state.wrappedValue
        state.wrappedValue = newState
        
        UXTelemetryService.logStateTransition(
            componentId: componentId,
            stateBefore: prevState.rawValue,
            stateAfter: newState.rawValue,
            category: .uiState,
            metadata: ["action": "manual_state_change"]
        )
    }
    
    private func setInputState(_ state: Binding<InputState>, to newState: InputState, componentId: String) {
        let prevState = state.wrappedValue
        state.wrappedValue = newState
        
        UXTelemetryService.logStateTransition(
            componentId: componentId,
            stateBefore: prevState.rawValue,
            stateAfter: newState.rawValue,
            category: .uiState,
            metadata: ["action": "manual_state_change"]
        )
    }
    
    private func setPrimaryButtonHover(_ hovering: Bool, componentId: String) {
        // Hover state changes (iOS/iPadOS with pointer)
        if hovering && primaryButtonState == .idle {
            primaryButtonState = .hover
            UXTelemetryService.logStateTransition(
                componentId: componentId,
                stateBefore: ButtonState.idle.rawValue,
                stateAfter: ButtonState.hover.rawValue,
                category: .uiState,
                metadata: ["action": "hover"]
            )
        } else if !hovering && primaryButtonState == .hover {
            primaryButtonState = .idle
            UXTelemetryService.logStateTransition(
                componentId: componentId,
                stateBefore: ButtonState.hover.rawValue,
                stateAfter: ButtonState.idle.rawValue,
                category: .uiState,
                metadata: ["action": "unhover"]
            )
        }
    }
}

#Preview {
    ProgrammaticUIView()
}

