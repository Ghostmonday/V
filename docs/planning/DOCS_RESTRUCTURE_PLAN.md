# VibeZ Documentation Restructure Plan

## 📋 Decision Matrix

### ✅ KEEP (Essential Docs)

#### Root Level
- `README.md` - Main project README
- `handover.md` - Architecture reference (referenced in onboarding)

#### Core Documentation (move to /docs)
- `docs/SELF_HOSTING_GUIDE.md` → `/docs/setup/self-hosting.md`
- `docs/iOS_RUNTIME_TEST_GUIDE.md` → `/docs/ios/testing.md`
- `docs/VALIDATION_QUICK_START.md` → `/docs/validation/quick-start.md`
- `docs/DOCKER_SETUP.md` → `/docs/setup/docker.md`
- `docs/SQL_OPTIMIZATION_QUICK_START.md` → `/docs/sql/optimization.md`
- `sql/SUPABASE_SQL_MASTER_SHEET.md` → `/docs/sql/master-reference.md`
- `sql/SECURITY_FIX_STEP_BY_STEP.md` → `/docs/security/sql-security.md`

#### Security Docs (consolidate to /docs/security)
- `SECURITY_AUDIT.md` → `/docs/security/audit.md`
- `SECURITY_AUDIT_REPORT.md` → `/docs/security/audit-report.md` (keep latest)
- `SECURITY_FIXES_APPLIED.md` → `/docs/security/fixes.md`
- `docs/PRIVACY_COMPLETE.md` → DELETE (consolidate into privacy.md)
- `docs/PRIVACY_ENHANCEMENTS.md` → `/docs/security/privacy.md`
- `docs/PRIVACY_FINAL_REFINEMENTS.md` → DELETE (consolidate)
- `docs/PRIVACY_IMPLEMENTATION_SUMMARY.md` → DELETE (historical)
- `docs/PRIVACY_POLISH_SUMMARY.md` → DELETE (historical)
- `docs/PRIVACY_VALIDATION_REPORT.md` → `/docs/security/privacy-validation.md`
- `docs/RLS_SECURITY_SUMMARY.md` → DELETE (covered in SQL docs)

#### User-Facing Strings (keep one)
- `USER_FACING_STRINGS_REWRITE.md` → `/docs/copy/user-facing-strings.md` (keep latest)
- `USER_FACING_STRINGS.md` → DELETE (superseded)
- `USER_FACING_STRINGS_AUTO.md` → DELETE (superseded)

### ❌ DELETE (Historical/Redundant)

#### Completion Summaries
- `AUDIT_REPORT.md`
- `BRANCH_CLEANUP_REPORT.md`
- `CODEBASE_COMPLETE.md`
- `COPY_EDITING_SUMMARY.md`
- `PHASE3_COMPLETION_SUMMARY.md`
- `PHASE7_COMPLETION_SUMMARY.md`
- `PHASE8_COMPLETION_SUMMARY.md`
- `PRODUCTION_READY.md` (info moved to README)
- `REDIS_CLUSTERING_SUMMARY.md`
- `STABILITY_REPORT.md`

#### Historical Docs
- `docs/AUTONOMOUS_VALIDATION_COMPLETE.md`
- `docs/CLEANUP_SUMMARY.md`
- `docs/GRADE_AUDIT.md`
- `docs/GRADE_AUDIT_2.md`
- `docs/LAUNCH_PACKAGE.md` (outdated)
- `docs/COMPLETE_EXECUTION_PLAN.md`
- `docs/execution/PHASE9_COMPLETION_SUMMARY.md`
- `docs/validation/PHASE5_COMPLETION.md`
- `docs/validation/PHASE6_COMPLETION.md`
- `docs/validation/PHASE7_VALIDATION_REPORT.md`
- `docs/validation/DEAD_CODE_CLEANUP_REPORT.md`
- `docs/validation/VALIDATION_SUMMARY.md`
- `sql/ALL_SQL_MARKDOWN_FILES_CONSOLIDATED.md` (superseded by master sheet)
- `sql/COMPLETE_SECURITY_AUDIT.md` (historical)
- `sql/RLS_STATUS_SUMMARY.md` (covered in master sheet)

#### Redundant/Outdated
- `CODEBASE_QUICKREF.md` (outdated stats)
- `docs/READING_GUIDE.md` (outdated)
- `docs/README_ACCURACY_VERIFICATION.md` (one-time check)
- `docs/AUTHENTICATION_BOTTLENECK_ANALYSIS.md` (historical analysis)
- `docs/TEST_EXECUTION_STATUS.md` (outdated)
- `docs/TEST_EXECUTION_FINAL_REPORT.md` (historical)
- `docs/FINAL_TEST_REPORT.md` (historical)
- `docs/WEBSOCKET_RECONNECTION_VALIDATION_REPORT.md` (covered in iOS guide)
- `docs/OPTIMIZATION_PLAN.md` (outdated)
- `docs/GROWTH_STRATEGY.md` (business doc, not technical)
- `docs/MVP_ENTRY_FLOW.md` (outdated UX doc)
- `docs/LAZY_SIGNUP_FLOW.md` (outdated UX doc)
- `docs/PERSISTENT_PRESENCE_AND_FEATURED.md` (outdated feature doc)
- `docs/VIBEZ_UI_UX_CONCEPT.md` (outdated UX doc)
- `docs/UX_BLUEPRINT.md` (outdated UX doc)
- `docs/UX_UI_AUDIT.md` (outdated audit)
- `docs/redis-clustering.md` (covered in setup docs)
- `docs/ARCHIVE_INSTRUCTIONS.md` (outdated)
- `docs/validation/VALIDATION_READY.md` (status doc)
- `docs/validation/VALIDATION_STATUS.md` (status doc)
- `docs/validation/VALIDATION_DOCKER.md` (covered in docker setup)
- `docs/validation/TEST_RESULTS.md` (outdated)
- `docs/validation/UI_STATE_TESTS_MIGRATION.md` (historical)
- `docs/validation/WORKFLOW_ISSUES_ANALYSIS.md` (historical)
- `frontend/iOS/FIX_PACKAGE_DEPENDENCIES.md` (one-time fix)
- `src/components/MOVE_TO_FRONTEND.md` (one-time note)
- `src/components/TELEMETRY_README.md` (covered in handover)

### 📁 New Structure

```
/docs
  /security
    - audit.md
    - audit-report.md
    - fixes.md
    - privacy.md
    - privacy-validation.md
    - sql-security.md
  
  /setup
    - self-hosting.md
    - docker.md
  
  /ios
    - testing.md
  
  /sql
    - master-reference.md
    - optimization.md
  
  /validation
    - quick-start.md
    - checklist.md
  
  /copy
    - user-facing-strings.md
```

### 🔍 Files Needing Fact-Check

1. `handover.md` - Verify architecture matches current code
2. `docs/SELF_HOSTING_GUIDE.md` - Check docker-compose.yml paths
3. `docs/iOS_RUNTIME_TEST_GUIDE.md` - Verify Xcode project name/paths
4. `README.md` - Verify env vars, commands, links

