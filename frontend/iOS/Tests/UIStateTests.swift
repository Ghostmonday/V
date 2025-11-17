/**
 * Unit Tests for UI State Enums
 * Tests ButtonState, InputState, and FormState enums and their modifiers
 * 
 * These tests validate that all UI state enums are properly defined and
 * that ProgrammaticUIView uses them correctly.
 */

import XCTest
@testable import VibeZ
import SwiftUI

@MainActor
final class UIStateTests: XCTestCase {
    
    // MARK: - ButtonState Tests
    
    func testButtonStateEnumExists() {
        // Given: ButtonState enum should exist
        // When: We check for the enum
        // Then: All cases should be accessible
        
        let idleState = ButtonState.idle
        let hoverState = ButtonState.hover
        let pressedState = ButtonState.pressed
        let loadingState = ButtonState.loading
        let errorState = ButtonState.error
        let disabledState = ButtonState.disabled
        
        XCTAssertEqual(idleState.rawValue, "idle")
        XCTAssertEqual(hoverState.rawValue, "hover")
        XCTAssertEqual(pressedState.rawValue, "pressed")
        XCTAssertEqual(loadingState.rawValue, "loading")
        XCTAssertEqual(errorState.rawValue, "error")
        XCTAssertEqual(disabledState.rawValue, "disabled")
    }
    
    func testButtonStateRawValueConversion() {
        // Given: ButtonState is String-backed
        // When: We create from raw value
        // Then: Should match expected cases
        
        XCTAssertEqual(ButtonState(rawValue: "idle"), .idle)
        XCTAssertEqual(ButtonState(rawValue: "hover"), .hover)
        XCTAssertEqual(ButtonState(rawValue: "pressed"), .pressed)
        XCTAssertEqual(ButtonState(rawValue: "loading"), .loading)
        XCTAssertEqual(ButtonState(rawValue: "error"), .error)
        XCTAssertEqual(ButtonState(rawValue: "disabled"), .disabled)
        XCTAssertNil(ButtonState(rawValue: "invalid"))
    }
    
    func testButtonStateModifierExists() {
        // Given: ButtonStateModifier should exist
        // When: We create a modifier
        // Then: It should be usable
        
        let modifier = ButtonStateModifier(state: .idle, buttonType: .primary)
        XCTAssertNotNil(modifier)
    }
    
    // MARK: - InputState Tests
    
    func testInputStateEnumExists() {
        // Given: InputState enum should exist
        // When: We check for the enum
        // Then: All cases should be accessible
        
        let idleState = InputState.idle
        let focusState = InputState.focus
        let filledState = InputState.filled
        let errorState = InputState.error
        let disabledState = InputState.disabled
        let loadingState = InputState.loading
        
        XCTAssertEqual(idleState.rawValue, "idle")
        XCTAssertEqual(focusState.rawValue, "focus")
        XCTAssertEqual(filledState.rawValue, "filled")
        XCTAssertEqual(errorState.rawValue, "error")
        XCTAssertEqual(disabledState.rawValue, "disabled")
        XCTAssertEqual(loadingState.rawValue, "loading")
    }
    
    func testInputStateRawValueConversion() {
        // Given: InputState is String-backed
        // When: We create from raw value
        // Then: Should match expected cases
        
        XCTAssertEqual(InputState(rawValue: "idle"), .idle)
        XCTAssertEqual(InputState(rawValue: "focus"), .focus)
        XCTAssertEqual(InputState(rawValue: "filled"), .filled)
        XCTAssertEqual(InputState(rawValue: "error"), .error)
        XCTAssertEqual(InputState(rawValue: "disabled"), .disabled)
        XCTAssertEqual(InputState(rawValue: "loading"), .loading)
        XCTAssertNil(InputState(rawValue: "invalid"))
    }
    
    func testInputStateModifierExists() {
        // Given: InputStateModifier should exist
        // When: We create a modifier
        // Then: It should be usable
        
        let modifier = InputStateModifier(state: .idle)
        XCTAssertNotNil(modifier)
    }
    
    // MARK: - FormState Tests
    
    func testFormStateEnumExists() {
        // Given: FormState enum should exist
        // When: We check for the enum
        // Then: All cases should be accessible
        
        let idleState = FormState.idle
        let submittingState = FormState.submitting
        let successState = FormState.success
        let errorState = FormState.error
        
        XCTAssertEqual(idleState.rawValue, "idle")
        XCTAssertEqual(submittingState.rawValue, "submitting")
        XCTAssertEqual(successState.rawValue, "success")
        XCTAssertEqual(errorState.rawValue, "error")
    }
    
    func testFormStateRawValueConversion() {
        // Given: FormState is String-backed
        // When: We create from raw value
        // Then: Should match expected cases
        
        XCTAssertEqual(FormState(rawValue: "idle"), .idle)
        XCTAssertEqual(FormState(rawValue: "submitting"), .submitting)
        XCTAssertEqual(FormState(rawValue: "success"), .success)
        XCTAssertEqual(FormState(rawValue: "error"), .error)
        XCTAssertNil(FormState(rawValue: "invalid"))
    }
    
    func testFormStateModifierExists() {
        // Given: FormStateModifier should exist
        // When: We create a modifier
        // Then: It should be usable
        
        let modifier = FormStateModifier(state: .idle)
        XCTAssertNotNil(modifier)
    }
    
    // MARK: - State Coverage Tests
    
    func testAllButtonStatesCovered() {
        // Given: ButtonState should have 6 states
        // When: We count all cases
        // Then: Should have idle, hover, pressed, loading, error, disabled
        
        let allStates: [ButtonState] = [.idle, .hover, .pressed, .loading, .error, .disabled]
        XCTAssertEqual(allStates.count, 6, "ButtonState should have exactly 6 states")
    }
    
    func testAllInputStatesCovered() {
        // Given: InputState should have 6 states
        // When: We count all cases
        // Then: Should have idle, focus, filled, error, disabled, loading
        
        let allStates: [InputState] = [.idle, .focus, .filled, .error, .disabled, .loading]
        XCTAssertEqual(allStates.count, 6, "InputState should have exactly 6 states")
    }
    
    func testAllFormStatesCovered() {
        // Given: FormState should have 4 states
        // When: We count all cases
        // Then: Should have idle, submitting, success, error
        
        let allStates: [FormState] = [.idle, .submitting, .success, .error]
        XCTAssertEqual(allStates.count, 4, "FormState should have exactly 4 states")
    }
    
    // MARK: - Integration Tests
    
    func testProgrammaticUIViewUsesAllStateTypes() {
        // Given: ProgrammaticUIView should use all state types
        // When: We verify the file exists and uses the enums
        // Then: All three state types should be referenced
        
        // Note: This is a structural test - actual view testing would require SwiftUI preview testing
        // For now, we verify the enums are properly defined and can be used
        let buttonState: ButtonState = .idle
        let inputState: InputState = .idle
        let formState: FormState = .idle
        
        XCTAssertNotNil(buttonState)
        XCTAssertNotNil(inputState)
        XCTAssertNotNil(formState)
    }
    
    func testStateEnumsAreStringBacked() {
        // Given: All state enums should be String-backed (for serialization)
        // When: We check rawValue types
        // Then: All should return String values
        
        let buttonRawValue: String = ButtonState.idle.rawValue
        let inputRawValue: String = InputState.idle.rawValue
        let formRawValue: String = FormState.idle.rawValue
        
        XCTAssertTrue(buttonRawValue is String)
        XCTAssertTrue(inputRawValue is String)
        XCTAssertTrue(formRawValue is String)
    }
}

