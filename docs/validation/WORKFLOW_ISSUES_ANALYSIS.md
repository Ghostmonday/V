# Healing Checks & UI-State Tests: Root Cause Analysis

## Executive Summary

Both workflows (`healing-checks.yml` and `ui-state-tests.yml`) are **architecturally misaligned** with the actual codebase. They were designed for a Vue.js frontend application, but this codebase is:
- **Backend**: TypeScript/Node.js API server
- **Frontend**: iOS Swift/SwiftUI (not Vue.js)
- **Monorepo**: Uses Turbo workspaces, not a single npm project

---

## 1. Healing Checks Workflow Issues

### Problem: Tests Don't Actually Run

**Location**: `.github/workflows/healing-checks.yml:40`

```yaml
run: npm test || echo "Tests not implemented yet"
continue-on-error: true
```

**Root Cause**:
- `server/package.json` has: `"test": "echo \"Tests not implemented yet\" && exit 0"`
- The workflow masks failures with `continue-on-error: true`
- No actual test infrastructure exists for healing/autonomy system
- The workflow name suggests it should test "healing" functionality, but it's just running generic server tests

**What "Healing" Actually Is**:
- Database healing logs table (`sql/07_healing_logs.sql`) tracks autonomy system errors
- No tests exist for this functionality
- No service/route tests for healing log operations

**Why It's Ongoing**:
1. Tests were never implemented
2. Workflow silently passes (due to `continue-on-error`)
3. No one notices failures because they're masked
4. The workflow doesn't actually test healing functionality

---

## 2. UI-State Tests Workflow Issues

### Problem: Workflow Expects Vue.js Frontend, But Codebase Has Swift/iOS Frontend

**Location**: `.github/workflows/ui-state-tests.yml`

#### Issue 2.1: Missing Vue Components
**Lines 6, 34, 162-164**:
- Expects: `src/components/**/*.vue`
- Expects: `src/components/ProgrammaticUI.vue`
- **Reality**: No `.vue` files exist in the codebase
- **Actual**: `ProgrammaticUI` exists in Swift: `frontend/iOS/Views/ProgrammaticUIView.swift`

#### Issue 2.2: Missing TypeScript UI State Types
**Lines 156-158**:
```yaml
grep -q "ButtonState" src/types/ui-states.ts
grep -q "InputState" src/types/ui-states.ts
grep -q "FormState" src/types/ui-states.ts
```
- **Expects**: `src/types/ui-states.ts` with TypeScript enums
- **Reality**: File doesn't exist
- **Actual**: Enums exist in Swift:
  - `frontend/iOS/Views/Shared/Modifiers/ButtonStateModifier.swift`
  - `frontend/iOS/Views/Shared/Modifiers/InputStateModifier.swift`
  - `frontend/iOS/Views/Shared/Modifiers/FormStateModifier.swift`

#### Issue 2.3: Missing Test Infrastructure
**Lines 33-34, 60, 63**:
- Expects: `src/components/__tests__/` directory
- Expects: `npm test -- src/components/__tests__/`
- Expects: `src/telemetry/ux/__tests__/privacy.test.ts`
- **Reality**: None of these exist
- **Actual**: Tests exist in `src/tests/` but are backend-focused

#### Issue 2.4: Missing State Matrix Documentation
**Line 152**:
- Expects: `tests/state-matrix.md`
- **Reality**: File doesn't exist

#### Issue 2.5: Missing Frontend Build Tools
**Lines 85, 112**:
- Expects: `npm run storybook:build` (Storybook for Vue components)
- Expects: `npm run test:e2e` (E2E tests)
- **Reality**: Neither configured
- **Reason**: No Vue.js frontend to test

#### Issue 2.6: Wrong Package Manager Usage
**Lines 31, 57, 82, 109**:
- Uses: `npm ci` at root level
- **Problem**: This is a monorepo with workspaces
- **Should use**: Workspace-aware install or Turbo commands

#### Issue 2.7: Node Version Mismatch
**Lines 27, 53, 78, 105**:
- Uses: Node.js 18
- **Root package.json**: Expects Node 20 (based on `@types/node@^20.19.25`)
- **Server package.json**: Uses Node 20

#### Issue 2.8: Missing Telemetry Files (RESOLVED)
**Lines 174-200** (OLD WORKFLOW - NOW FIXED):
- ~~Expects various telemetry files that may not exist:~~
  - ~~`src/telemetry/ux/client-sdk.ts`~~ ❌ (does not exist - was frontend SDK, now in Swift)
  - `src/routes/ux-telemetry-routes.ts` ✅ (exists)
  - `src/services/ux-telemetry-service.ts` ✅ (exists)
  - `src/services/ux-telemetry-redaction.ts` ✅ (exists)
  - ~~`src/llm-observer/watchdog.ts`~~ ❌ (does not exist - removed from workflow)
  - ~~`src/llm-observer/strategies/*.json`~~ ❌ (does not exist - removed from workflow)
  - ~~`sql/17_ux_telemetry_schema.sql`~~ ❌ (does not exist - UX telemetry schema is in other SQL files)

**Note**: The workflow has been rewritten and no longer references these non-existent files.

---

## Why These Are "Ongoing" Problems

### 1. **Architectural Drift**
- Workflows were created for a Vue.js frontend architecture
- Codebase evolved to use Swift/iOS frontend
- Workflows were never updated to match reality

### 2. **Silent Failures**
- Both workflows use `continue-on-error: true` or `|| echo` patterns
- Failures are masked, so they don't block PRs
- No one notices they're broken

### 3. **Missing Test Infrastructure**
- Tests were never written for the features being "tested"
- Workflows expect test files that don't exist
- No CI feedback loop to drive test creation

### 4. **Monorepo Misconfiguration**
- Workflows don't understand the workspace structure
- Wrong package manager usage
- Missing Turbo/npm workspace awareness

### 5. **Frontend/Backend Split**
- UI state types exist in Swift, not TypeScript
- Components exist in SwiftUI, not Vue
- Workflows test the wrong stack

---

## Recommended Solutions

### For Healing Checks:
1. **Option A**: Remove the workflow if healing functionality isn't critical
2. **Option B**: Implement actual healing tests:
   - Test healing logs table operations
   - Test autonomy system error tracking
   - Test healing log queries and RLS policies
3. **Option C**: Rename to "Server Health Checks" and test actual server functionality

### For UI-State Tests:
1. **Option A**: Delete the workflow (it tests non-existent code)
2. **Option B**: Rewrite for Swift/iOS:
   - Use Xcode build/test commands
   - Test SwiftUI components
   - Use Swift testing framework
3. **Option C**: Create TypeScript type definitions that mirror Swift enums:
   - Create `src/types/ui-states.ts` with ButtonState, InputState, FormState
   - Keep in sync with Swift definitions
   - Test TypeScript types, not Vue components

### General Fixes:
1. Remove `continue-on-error: true` to surface real failures
2. Fix Node version consistency (use 20 everywhere)
3. Use workspace-aware package manager commands
4. Add proper test infrastructure before creating workflows
5. Document architecture decisions (why Swift instead of Vue)

---

## Impact Assessment

**Current State**:
- ❌ Workflows don't test what they claim to test
- ❌ False sense of security (workflows pass but don't validate anything)
- ❌ Wasted CI resources running meaningless checks
- ❌ Confusion for developers (workflows reference non-existent files)

**If Fixed**:
- ✅ Accurate test coverage reporting
- ✅ Real validation of healing/UI state functionality
- ✅ Proper CI feedback loop
- ✅ Clear architecture documentation

---

## Files That Need to Exist (If Keeping UI-State Tests)

**UPDATE**: The UI-State Tests workflow has been rewritten to test Swift/iOS code instead of Vue.js components. See `docs/validation/UI_STATE_TESTS_MIGRATION.md` for details.

The workflow now:
- ✅ Tests actual Swift UI state enums (`ButtonState`, `InputState`, `FormState`)
- ✅ Validates `ProgrammaticUIView.swift` usage
- ✅ Tests Swift telemetry integration
- ✅ Validates backend TypeScript telemetry files
- ✅ Uses macOS runner and xcodebuild for iOS testing

