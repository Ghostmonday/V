# iOS Runtime Test Execution Guide

**Status:** ⚠️ Static Validation Complete | Runtime Tests Pending  
**Date:** November 17, 2025  
**Test Suite:** WebSocket Reconnection Tests (27 test cases)

---

## Overview

This guide walks you through executing the iOS WebSocket reconnection tests that have been created but require runtime validation in Xcode. All 27 test cases are ready to run once the Xcode project is properly configured.

---

## Prerequisites

### Required Software

- **Xcode**: 15.0 or later (recommended: latest version)
- **macOS**: 13.0 (Ventura) or later
- **iOS Simulator**: iPhone 15 or later (iOS 17.0+)
- **Swift**: 6.0 (comes with Xcode)

### Project Dependencies

Before running tests, ensure Swift Package Manager dependencies are configured:

1. **Firebase iOS SDK** (FirebaseCore, FirebaseAuth)
2. **GoogleSignIn-iOS**

**Note:** If you see "Unable to find module dependency" errors, see [Setting Up Dependencies](#setting-up-dependencies) below.

---

## Step-by-Step Execution Guide

### Step 1: Open Xcode Project

```bash
cd frontend/iOS
open VibeZ.xcodeproj
```

Or manually:

- Open Xcode
- File → Open → Navigate to `frontend/iOS/VibeZ.xcodeproj`

### Step 2: Set Up Swift Package Dependencies

If dependencies are not already configured:

1. **File → Add Package Dependencies...**
2. **Add Firebase:**
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Version: **Up to Next Major Version** `11.0.0`
   - Products: ✅ **FirebaseCore**, ✅ **FirebaseAuth**
3. **Add GoogleSignIn:**
   - URL: `https://github.com/google/GoogleSignIn-iOS`
   - Version: **Up to Next Major Version** `7.0.0`
   - Product: ✅ **GoogleSignIn**
4. Wait for packages to resolve (may take 2-5 minutes)

**Verify Dependencies:**

- Select project in navigator → Select **VibeZ** target → **General** tab
- Under **Frameworks, Libraries, and Embedded Content**, you should see:
  - FirebaseCore
  - FirebaseAuth
  - GoogleSignIn

### Step 3: Configure Test Scheme

1. **Product → Scheme → Edit Scheme...** (or press `Cmd+<`)
2. Select **Test** in the left sidebar
3. Ensure **VibeZ** target is checked
4. If `WebSocketReconnectionTests` appears, ensure it's checked
5. Click **Close**

**If Test Target Doesn't Appear:**

The test file may need to be added to the test target:

1. In Project Navigator, locate `Tests/WebSocketReconnectionTests.swift`
2. Select the file
3. In File Inspector (right panel), check **Target Membership** → **VibeZ** (or create a test target)
4. Ensure the file is included in the test target's **Compile Sources** build phase

### Step 4: Select iOS Simulator

1. In Xcode toolbar, click the device selector (next to scheme)
2. Select **iPhone 15** (or any iOS 17.0+ simulator)
3. If simulator isn't listed:
   - **Window → Devices and Simulators**
   - Click **+** to add iPhone 15 simulator
   - iOS Version: 17.0 or later

### Step 5: Clean Build Folder

**Important:** Clean before first test run to ensure fresh build:

- **Product → Clean Build Folder** (or `Shift+Cmd+K`)

### Step 6: Run Tests

**Option A: Run All Tests**

- **Product → Test** (or `Cmd+U`)
- This runs all tests in the project

**Option B: Run Specific Test Suite**

1. Open Test Navigator (`Cmd+6`)
2. Expand **VibeZTests** → **WebSocketReconnectionTests**
3. Right-click on **WebSocketReconnectionTests** → **Run 'WebSocketReconnectionTests'**

**Option C: Run Individual Test**

1. Open `Tests/WebSocketReconnectionTests.swift`
2. Click the diamond icon (◊) next to any test function
3. Or right-click test name → **Run 'testName'**

### Step 7: Monitor Test Execution

- **Test Navigator** (`Cmd+6`): Shows test progress and results
- **Report Navigator** (`Cmd+9`): Detailed test reports after completion
- **Console** (`Cmd+Shift+Y`): Test output and logs

---

## Expected Test Results

### Test Suite Breakdown (27 Tests)

| Category                 | Test Cases | Expected Behavior                             |
| ------------------------ | ---------- | --------------------------------------------- |
| **State Machine**        | 3          | Validates connection state transitions        |
| **Exponential Backoff**  | 2          | Verifies backoff calculation and max attempts |
| **Message Outbox**       | 4          | Tests message queuing and flushing            |
| **Room Restoration**     | 5          | Validates room tracking and re-joining        |
| **Network Reachability** | 3          | Tests network monitoring integration          |
| **Ping/Pong**            | 2          | Verifies heartbeat mechanism                  |
| **App Lifecycle**        | 2          | Tests background/foreground handling          |
| **Integration**          | 3          | End-to-end reconnection scenarios             |
| **Edge Cases**           | 3          | Handles error conditions gracefully           |

### Success Criteria

✅ **All 27 tests passing** = iOS reconnection logic fully validated  
⚠️ **Some tests failing** = Review failures and fix issues (see Troubleshooting)  
❌ **Tests won't compile** = Check dependencies and build settings

---

## Troubleshooting

### Issue 1: "Unable to find module dependency"

**Symptoms:**

```
error: Unable to find module dependency: 'FirebaseCore'
error: Unable to find module dependency: 'GoogleSignIn'
```

**Solution:**

1. Follow [Step 2: Set Up Swift Package Dependencies](#step-2-set-up-swift-package-dependencies)
2. Clean build folder (`Shift+Cmd+K`)
3. Build project (`Cmd+B`) to verify dependencies resolve
4. If still failing, try:
   - **File → Packages → Reset Package Caches**
   - **File → Packages → Resolve Package Versions**

### Issue 2: "Scheme is not currently configured for the test action"

**Symptoms:**

```
xcodebuild: error: Scheme VibeZ is not currently configured for the test action.
```

**Solution:**

1. Follow [Step 3: Configure Test Scheme](#step-3-configure-test-scheme)
2. Ensure test target exists and is added to scheme
3. If test target doesn't exist:
   - **File → New → Target**
   - Select **iOS Unit Testing Bundle**
   - Name: `VibeZTests`
   - Add `WebSocketReconnectionTests.swift` to this target

### Issue 3: Tests Don't Appear in Test Navigator

**Symptoms:**

- Test Navigator shows no tests
- Test file exists but tests aren't discoverable

**Solution:**

1. Ensure test file is in correct location: `Tests/WebSocketReconnectionTests.swift`
2. Verify file is added to test target:
   - Select test file → File Inspector → Target Membership → Check test target
3. Ensure test class inherits from `XCTestCase`:
   ```swift
   final class WebSocketReconnectionTests: XCTestCase {
   ```
4. Clean build folder and rebuild

### Issue 4: Simulator Won't Boot

**Symptoms:**

- Simulator stays in "Shutdown" state
- Error: "Unable to boot simulator"

**Solution:**

1. **Window → Devices and Simulators**
2. Right-click simulator → **Erase All Content and Settings**
3. Try booting again
4. If still failing, create new simulator:
   - Click **+** → Select iPhone 15 → iOS 17.0+

### Issue 5: Build Errors (Missing Files)

**Symptoms:**

```
error: Build input files cannot be found: 'AmbientParticles.swift', 'HomeView.swift'
```

**Solution:**

- These files have been removed from the project
- If errors persist, clean build folder (`Shift+Cmd+K`)
- If still failing, check `project.pbxproj` for stale references

### Issue 6: Tests Fail with "Network Unavailable"

**Symptoms:**

- Network reachability tests fail
- Tests expect network but simulator has no network

**Solution:**

- This is expected behavior - tests validate network detection
- Ensure simulator has network access:
  - **Settings → Wi-Fi** (in simulator)
  - Or disable network for negative test cases

### Issue 7: WebSocket Connection Fails in Tests

**Symptoms:**

- Tests fail because WebSocket can't connect
- "Connection refused" or timeout errors

**Solution:**

- Tests may require a running backend server
- Start backend: `cd server && npm run dev`
- Update test configuration if needed:
  - Check `WebSocketManager.swift` for test server URL
  - Or mock WebSocket connections for unit tests

---

## Interpreting Test Results

### Test Navigator View

- ✅ **Green checkmark**: Test passed
- ❌ **Red X**: Test failed
- ⏸️ **Gray pause**: Test skipped
- ⏳ **Spinning**: Test running

### Test Report View

1. **Report Navigator** (`Cmd+9`)
2. Select latest test run
3. View:
   - **Summary**: Overall pass/fail count
   - **Timeline**: Test execution order and duration
   - **Coverage**: Code coverage (if enabled)
   - **Logs**: Detailed output per test

### Understanding Failures

**Common Failure Patterns:**

1. **Assertion Failures:**

   ```
   XCTAssertEqual failed: ("disconnected") is not equal to ("connected")
   ```

   - Check test expectations match implementation
   - Verify state transitions are correct

2. **Timeout Failures:**

   ```
   Asynchronous wait failed: Exceeded timeout of 5.0 seconds
   ```

   - Increase timeout if operation takes longer
   - Check if async operations complete properly

3. **Nil Unwrapping:**

   ```
   Fatal error: Unexpectedly found nil while unwrapping an Optional value
   ```

   - Add nil checks before force unwrapping
   - Verify test setup initializes all required properties

---

## Command-Line Execution (Alternative)

If you prefer command-line execution:

```bash
cd /Users/rentamac/Desktop/VibeZ/frontend/iOS

# List available schemes
xcodebuild -list -project Sinapse.xcodeproj

# Run tests (requires scheme configured for testing)
xcodebuild test \
  -project Sinapse.xcodeproj \
  -scheme VibeZ \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:VibeZTests/WebSocketReconnectionTests
```

**Note:** Command-line testing requires the scheme to be properly configured for test actions. If this fails, use Xcode GUI instead.

---

## Post-Test Actions

### If All Tests Pass ✅

1. **Document Results:**
   - Update `docs/FINAL_TEST_REPORT.md` with iOS test results
   - Mark iOS runtime validation as complete

2. **Update Status:**
   - Change iOS status from ⚠️ to ✅ in project documentation
   - Update README.md with test results

3. **Next Steps:**
   - Proceed with integration testing
   - Validate cross-platform compatibility
   - Prepare for production deployment

### If Tests Fail ❌

1. **Review Failures:**
   - Check Test Report for detailed error messages
   - Identify patterns (e.g., all network tests failing)

2. **Fix Issues:**
   - Update implementation code if logic errors found
   - Adjust test expectations if they're incorrect
   - Fix test setup/teardown if needed

3. **Re-run Tests:**
   - Clean build folder
   - Run tests again
   - Iterate until all pass

4. **Document Fixes:**
   - Update test file with fixes
   - Document any changes needed

---

## Test Coverage Goals

### Current Coverage

- **Test Cases Created**: 27
- **Categories Covered**: 9
- **Static Validation**: ✅ Complete
- **Runtime Validation**: ⚠️ Pending

### Target Coverage

- **Unit Tests**: 100% of reconnection logic
- **Integration Tests**: End-to-end reconnection flows
- **Edge Cases**: All error conditions handled

---

## Additional Resources

- **Test File**: `frontend/iOS/Tests/WebSocketReconnectionTests.swift`
- **Implementation**: `frontend/iOS/Managers/WebSocketManager.swift`
- **Services**:
  - `frontend/iOS/Services/NetworkReachability.swift`
  - `frontend/iOS/Services/RoomRestorationService.swift`
- **Backend Tests**: `src/tests/integration/websocket-reconnection.test.ts` (24/24 passing ✅)
- **Validation Report**: `docs/AUTONOMOUS_VALIDATION_COMPLETE.md`

---

## Quick Reference Checklist

- [ ] Xcode 15.0+ installed
- [ ] Project opens without errors
- [ ] Swift Package dependencies resolved (Firebase, GoogleSignIn)
- [ ] Test scheme configured
- [ ] iOS Simulator selected (iPhone 15, iOS 17.0+)
- [ ] Build folder cleaned
- [ ] Tests run successfully
- [ ] All 27 tests pass
- [ ] Results documented

---

## Support

If you encounter issues not covered in this guide:

1. Check Xcode console for detailed error messages
2. Review test file comments for test-specific requirements
3. Verify backend server is running (if tests require it)
4. Check [Troubleshooting](#troubleshooting) section above

---

**Last Updated:** November 17, 2025  
**Status:** Ready for Execution  
**Expected Duration:** 5-10 minutes for full test suite
