#!/usr/bin/env tsx
/**
 * Phase 5: Moderation & Safety - Validation Script
 *
 * Usage:
 *   tsx scripts/validate-phase5.ts              # Code-level validation (runs now)
 *   tsx scripts/validate-phase5.ts --full      # Full validation (requires running system)
 */

import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface ValidationResult {
  phase: string;
  section: string;
  test: string;
  passed: boolean;
  message: string;
  details?: any;
}

const results: ValidationResult[] = [];

function recordResult(
  phase: string,
  section: string,
  test: string,
  passed: boolean,
  message: string,
  details?: any
) {
  results.push({ phase, section, test, passed, message, details });
  const icon = passed ? '✅' : '❌';
  console.log(`  ${icon} ${test}: ${message}`);
}

// ===============================================
// 5.1: Perspective API Integration
// ===============================================
async function validatePhase5_1() {
  console.log('\n🔍 Phase 5.1: Perspective API Integration\n');

  // Check perspective-api-service.ts exists
  const perspectiveServicePath = path.join(__dirname, '../src/services/perspective-api-service.ts');
  const perspectiveExists = fs.existsSync(perspectiveServicePath);
  recordResult(
    'Phase 5',
    '5.1',
    'perspective-api-service.ts exists',
    perspectiveExists,
    perspectiveExists ? 'File found' : 'File not found'
  );

  if (perspectiveExists) {
    const content = fs.readFileSync(perspectiveServicePath, 'utf-8') as string;

    // Check for analyzeWithPerspective function
    const hasAnalyzeFunction = content.includes('analyzeWithPerspective');
    recordResult(
      'Phase 5',
      '5.1',
      'analyzeWithPerspective function',
      hasAnalyzeFunction,
      hasAnalyzeFunction ? 'Function found' : 'Function missing'
    );

    // Check for error handling
    const hasErrorHandling = content.includes('catch') && content.includes('logError');
    recordResult(
      'Phase 5',
      '5.1',
      'Error handling',
      hasErrorHandling,
      hasErrorHandling ? 'Error handling present' : 'Error handling missing'
    );

    // Check for fallback to DeepSeek (in moderation.service.ts, not here)
    // This will be checked in the moderation service validation below

    // Check for API key configuration
    const hasApiKey = content.includes('getApiKey') || content.includes('perspective_api_key');
    recordResult(
      'Phase 5',
      '5.1',
      'API key configuration',
      hasApiKey,
      hasApiKey ? 'API key config found' : 'API key config missing'
    );
  }

  // Check moderation.service.ts integration
  const moderationServicePath = path.join(__dirname, '../src/services/moderation.service.ts');
  const moderationExists = fs.existsSync(moderationServicePath);
  recordResult(
    'Phase 5',
    '5.1',
    'moderation.service.ts exists',
    moderationExists,
    moderationExists ? 'File found' : 'File not found'
  );

  if (moderationExists) {
    const content = fs.readFileSync(moderationServicePath, 'utf-8') as string;
    const usesPerspective = content.includes('analyzeWithPerspective');
    const hasDeepSeekFallback =
      content.includes('DeepSeek') ||
      content.includes('deepseek') ||
      content.includes('deepseek-chat');
    recordResult(
      'Phase 5',
      '5.1',
      'Uses Perspective API',
      usesPerspective,
      usesPerspective ? 'Integration found' : 'Integration missing'
    );
    recordResult(
      'Phase 5',
      '5.1',
      'DeepSeek fallback',
      hasDeepSeekFallback,
      hasDeepSeekFallback ? 'Fallback configured' : 'Fallback missing'
    );
  }
}

// ===============================================
// 5.2: Configurable Thresholds
// ===============================================
async function validatePhase5_2() {
  console.log('\n⚙️  Phase 5.2: Configurable Thresholds\n');

  // Check getModerationThresholds function
  const perspectiveServicePath = path.join(__dirname, '../src/services/perspective-api-service.ts');
  if (fs.existsSync(perspectiveServicePath)) {
    const content = fs.readFileSync(perspectiveServicePath, 'utf-8') as string;

    const hasGetThresholds = content.includes('getModerationThresholds');
    recordResult(
      'Phase 5',
      '5.2',
      'getModerationThresholds function',
      hasGetThresholds,
      hasGetThresholds ? 'Function found' : 'Function missing'
    );

    // Check for room-specific threshold support
    const hasRoomSupport =
      content.includes('roomId') && content.includes('room_moderation_thresholds');
    recordResult(
      'Phase 5',
      '5.2',
      'Per-room threshold support',
      hasRoomSupport,
      hasRoomSupport ? 'Room-specific thresholds supported' : 'Room-specific thresholds missing'
    );

    // Check default thresholds
    const hasDefaults = content.includes('0.6') && content.includes('0.8');
    recordResult(
      'Phase 5',
      '5.2',
      'Default thresholds (0.6/0.8)',
      hasDefaults,
      hasDefaults ? 'Default thresholds found' : 'Default thresholds missing'
    );
  }

  // Check migration file
  const migrationPath = path.join(
    __dirname,
    '../sql/migrations/2025-01-XX-phase5-per-room-thresholds.sql'
  );
  const migrationExists = fs.existsSync(migrationPath);
  recordResult(
    'Phase 5',
    '5.2',
    'Migration file exists',
    migrationExists,
    migrationExists ? 'Migration file found' : 'Migration file missing'
  );

  if (migrationExists) {
    const content = fs.readFileSync(migrationPath, 'utf-8') as string;
    const hasTable = content.includes('room_moderation_thresholds');
    const hasRLS = content.includes('ROW LEVEL SECURITY') || content.includes('POLICY');
    recordResult(
      'Phase 5',
      '5.2',
      'Migration creates table',
      hasTable,
      hasTable ? 'Table creation found' : 'Table creation missing'
    );
    recordResult(
      'Phase 5',
      '5.2',
      'RLS policies',
      hasRLS,
      hasRLS ? 'RLS policies found' : 'RLS policies missing'
    );
  }

  // Check API endpoints
  const configRoutesPath = path.join(__dirname, '../src/routes/chat-room-config-routes.ts');
  if (fs.existsSync(configRoutesPath)) {
    const content = fs.readFileSync(configRoutesPath, 'utf-8') as string;
    const hasGetEndpoint = content.includes('moderation-thresholds') && content.includes('GET');
    const hasPostEndpoint = content.includes('moderation-thresholds') && content.includes('POST');
    recordResult(
      'Phase 5',
      '5.2',
      'GET threshold endpoint',
      hasGetEndpoint,
      hasGetEndpoint ? 'GET endpoint found' : 'GET endpoint missing'
    );
    recordResult(
      'Phase 5',
      '5.2',
      'POST threshold endpoint',
      hasPostEndpoint,
      hasPostEndpoint ? 'POST endpoint found' : 'POST endpoint missing'
    );
  }
}

// ===============================================
// 5.3: Flagging System Enhancement
// ===============================================
async function validatePhase5_3() {
  console.log('\n🚩 Phase 5.3: Flagging System Enhancement\n');

  // Check message-flagging-service.ts
  const flaggingServicePath = path.join(__dirname, '../src/services/message-flagging-service.ts');
  const flaggingExists = fs.existsSync(flaggingServicePath);
  recordResult(
    'Phase 5',
    '5.3',
    'message-flagging-service.ts exists',
    flaggingExists,
    flaggingExists ? 'File found' : 'File not found'
  );

  if (flaggingExists) {
    const content = fs.readFileSync(flaggingServicePath, 'utf-8') as string;

    const hasFlagMessage = content.includes('flagMessage');
    const hasGetFlagged = content.includes('getFlaggedMessages');
    const hasReview = content.includes('reviewFlaggedMessage');

    recordResult(
      'Phase 5',
      '5.3',
      'flagMessage function',
      hasFlagMessage,
      hasFlagMessage ? 'Function found' : 'Function missing'
    );
    recordResult(
      'Phase 5',
      '5.3',
      'getFlaggedMessages function',
      hasGetFlagged,
      hasGetFlagged ? 'Function found' : 'Function missing'
    );
    recordResult(
      'Phase 5',
      '5.3',
      'reviewFlaggedMessage function',
      hasReview,
      hasReview ? 'Function found' : 'Function missing'
    );
  }

  // Check user-facing moderation routes
  const moderationRoutesPath = path.join(__dirname, '../src/routes/moderation-routes.ts');
  const routesExist = fs.existsSync(moderationRoutesPath);
  recordResult(
    'Phase 5',
    '5.3',
    'moderation-routes.ts exists',
    routesExist,
    routesExist ? 'File found' : 'File not found'
  );

  if (routesExist) {
    const content = fs.readFileSync(moderationRoutesPath, 'utf-8') as string;
    const hasFlagEndpoint = content.includes('POST') && content.includes('/flag');
    const hasMyFlagsEndpoint = content.includes('GET') && content.includes('my-flags');
    recordResult(
      'Phase 5',
      '5.3',
      'POST /flag endpoint',
      hasFlagEndpoint,
      hasFlagEndpoint ? 'Flag endpoint found' : 'Flag endpoint missing'
    );
    recordResult(
      'Phase 5',
      '5.3',
      'GET /my-flags endpoint',
      hasMyFlagsEndpoint,
      hasMyFlagsEndpoint ? 'My flags endpoint found' : 'My flags endpoint missing'
    );
  }

  // Check auto-flagging in moderation service
  const moderationServicePath = path.join(__dirname, '../src/services/moderation.service.ts');
  if (fs.existsSync(moderationServicePath)) {
    const content = fs.readFileSync(moderationServicePath, 'utf-8') as string;
    const hasAutoFlag = content.includes('flagMessage') && content.includes('warnThreshold');
    recordResult(
      'Phase 5',
      '5.3',
      'Auto-flagging on toxicity',
      hasAutoFlag,
      hasAutoFlag ? 'Auto-flagging found' : 'Auto-flagging missing'
    );
  }

  // Check migration for flagged_messages table
  const flaggedMigrationPath = path.join(
    __dirname,
    '../sql/migrations/2025-01-XX-flagged-messages.sql'
  );
  const flaggedMigrationExists = fs.existsSync(flaggedMigrationPath);
  recordResult(
    'Phase 5',
    '5.3',
    'Flagged messages migration',
    flaggedMigrationExists,
    flaggedMigrationExists ? 'Migration found' : 'Migration missing'
  );
}

// ===============================================
// Integration Checks
// ===============================================
async function validateIntegration() {
  console.log('\n🔗 Integration Checks\n');

  // Check server registration
  const serverPath = path.join(__dirname, '../src/server/index.ts');
  if (fs.existsSync(serverPath)) {
    const content = fs.readFileSync(serverPath, 'utf-8') as string;
    const hasModerationRoutes =
      content.includes('moderation-routes') || content.includes('moderationRoutes');
    recordResult(
      'Phase 5',
      'Integration',
      'Moderation routes registered',
      hasModerationRoutes,
      hasModerationRoutes ? 'Routes registered' : 'Routes not registered'
    );
  }

  // Check WebSocket integration
  const wsMessagingPath = path.join(__dirname, '../src/ws/handlers/messaging.ts');
  if (fs.existsSync(wsMessagingPath)) {
    const content = fs.readFileSync(wsMessagingPath, 'utf-8') as string;
    const hasModeration = content.includes('scanForToxicity');
    recordResult(
      'Phase 5',
      'Integration',
      'WebSocket moderation',
      hasModeration,
      hasModeration ? 'WebSocket integration found' : 'WebSocket integration missing'
    );
  }

  // Check message service integration
  const messageServicePath = path.join(__dirname, '../src/services/message-service.ts');
  if (fs.existsSync(messageServicePath)) {
    const content = fs.readFileSync(messageServicePath, 'utf-8') as string;
    const hasModeration = content.includes('scanForToxicity') || content.includes('isUserMuted');
    recordResult(
      'Phase 5',
      'Integration',
      'Message service moderation',
      hasModeration,
      hasModeration ? 'Message service integration found' : 'Message service integration missing'
    );
  }
}

// ===============================================
// Full Validation (requires running system)
// ===============================================
async function validateFull() {
  console.log('\n🔬 Full Validation (requires running system)\n');
  console.log('⚠️  This requires:');
  console.log('   - Database migrations run');
  console.log('   - Server running');
  console.log('   - Perspective API key configured\n');

  // These would require actual database/server connections
  recordResult(
    'Phase 5',
    'Full',
    'Database migration run',
    false,
    '⚠️  Run: psql $DATABASE_URL -f sql/migrations/2025-01-XX-phase5-per-room-thresholds.sql'
  );
  recordResult(
    'Phase 5',
    'Full',
    'API endpoints testable',
    false,
    '⚠️  Start server and test: POST /api/moderation/flag'
  );
  recordResult(
    'Phase 5',
    'Full',
    'Perspective API configured',
    false,
    '⚠️  Set PERSPECTIVE_API_KEY environment variable'
  );
  recordResult(
    'Phase 5',
    'Full',
    'End-to-end flow test',
    false,
    '⚠️  Test: Send message → Check moderation → Verify flagging'
  );
}

// ===============================================
// Main
// ===============================================
async function main() {
  const args = process.argv.slice(2);
  const fullValidation = args.includes('--full');

  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Phase 5: Moderation & Safety - Validation');
  console.log('═══════════════════════════════════════════════════════════');

  await validatePhase5_1();
  await validatePhase5_2();
  await validatePhase5_3();
  await validateIntegration();

  if (fullValidation) {
    await validateFull();
  } else {
    console.log('\n💡 Tip: Run with --full flag for full validation (requires running system)');
  }

  // Summary
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('  Summary');
  console.log('═══════════════════════════════════════════════════════════');

  const passed = results.filter((r) => r.passed).length;
  const total = results.length;
  const failed = total - passed;

  console.log(`\n✅ Passed: ${passed}/${total}`);
  if (failed > 0) {
    console.log(`❌ Failed: ${failed}/${total}\n`);
    console.log('Failed checks:');
    results
      .filter((r) => !r.passed)
      .forEach((r) => {
        console.log(`  - ${r.section}: ${r.test} - ${r.message}`);
      });
  } else {
    console.log(`❌ Failed: 0/${total}\n`);
  }

  // Save results
  const resultsPath = path.join(__dirname, '../validation-results-phase5.json');
  fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
  console.log(`\n📄 Results saved to: ${resultsPath}`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
