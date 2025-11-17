#!/usr/bin/env tsx
/**
 * Phase 8: Privacy & Compliance - Validation Script
 *
 * Usage:
 *   tsx scripts/validate-phase8.ts              # Code-level validation (runs now)
 *   tsx scripts/validate-phase8.ts --full       # Full validation (requires running system)
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
// 8.1: GDPR/CCPA Compliance
// ===============================================
async function validatePhase8_1() {
  console.log('\n🔒 Phase 8.1: GDPR/CCPA Compliance\n');

  // Check user-data-routes.ts exists
  const routesPath = path.join(__dirname, '../src/routes/user-data-routes.ts');
  const routesExists = fs.existsSync(routesPath);
  recordResult(
    'Phase 8',
    '8.1',
    'user-data-routes.ts exists',
    routesExists,
    routesExists ? 'File found' : 'File not found'
  );

  if (routesExists) {
    const content = fs.readFileSync(routesPath, 'utf-8');

    // Check for data export endpoint
    const hasExportEndpoint =
      content.includes('GET') && content.includes('/:id/data') && content.includes('export');
    recordResult(
      'Phase 8',
      '8.1',
      'Data export endpoint',
      hasExportEndpoint,
      hasExportEndpoint ? 'Export endpoint found' : 'Export endpoint missing'
    );

    // Check for data deletion endpoint
    const hasDeletionEndpoint = content.includes('DELETE') && content.includes('/:id/data');
    recordResult(
      'Phase 8',
      '8.1',
      'Data deletion endpoint',
      hasDeletionEndpoint,
      hasDeletionEndpoint ? 'Deletion endpoint found' : 'Deletion endpoint missing'
    );

    // Check for consent endpoints
    const hasConsentPost = content.includes('POST') && content.includes('/:id/consent');
    const hasConsentGet = content.includes('GET') && content.includes('/:id/consent');
    const hasConsentDelete = content.includes('DELETE') && content.includes('/:id/consent');

    recordResult(
      'Phase 8',
      '8.1',
      'Consent POST endpoint',
      hasConsentPost,
      hasConsentPost ? 'Consent POST found' : 'Consent POST missing'
    );
    recordResult(
      'Phase 8',
      '8.1',
      'Consent GET endpoint',
      hasConsentGet,
      hasConsentGet ? 'Consent GET found' : 'Consent GET missing'
    );
    recordResult(
      'Phase 8',
      '8.1',
      'Consent DELETE endpoint',
      hasConsentDelete,
      hasConsentDelete ? 'Consent DELETE found' : 'Consent DELETE missing'
    );

    // Check for consent_records table usage
    const usesConsentRecords = content.includes('consent_records');
    recordResult(
      'Phase 8',
      '8.1',
      'Uses consent_records table',
      usesConsentRecords,
      usesConsentRecords ? 'Consent records table used' : 'Consent records table not used'
    );
  }

  // Check data-deletion-service.ts
  const deletionServicePath = path.join(__dirname, '../src/services/data-deletion-service.ts');
  const deletionServiceExists = fs.existsSync(deletionServicePath);
  recordResult(
    'Phase 8',
    '8.1',
    'data-deletion-service.ts exists',
    deletionServiceExists,
    deletionServiceExists ? 'File found' : 'File not found'
  );

  if (deletionServiceExists) {
    const content = fs.readFileSync(deletionServicePath, 'utf-8');
    const hasSoftDelete = content.includes('softDeleteUserData');
    const hasAnonymize = content.includes('anonymizeUserPII');
    const hasRetention = content.includes('retention') || content.includes('RETENTION');

    recordResult(
      'Phase 8',
      '8.1',
      'Soft delete function',
      hasSoftDelete,
      hasSoftDelete ? 'Soft delete found' : 'Soft delete missing'
    );
    recordResult(
      'Phase 8',
      '8.1',
      'Anonymization function',
      hasAnonymize,
      hasAnonymize ? 'Anonymization found' : 'Anonymization missing'
    );
    recordResult(
      'Phase 8',
      '8.1',
      'Retention period support',
      hasRetention,
      hasRetention ? 'Retention periods configured' : 'Retention periods missing'
    );
  }

  // Check migrations
  const consentMigrationPath = path.join(
    __dirname,
    '../sql/migrations/2025-01-XX-phase8-consent-records.sql'
  );
  const consentMigrationExists = fs.existsSync(consentMigrationPath);
  recordResult(
    'Phase 8',
    '8.1',
    'Consent records migration',
    consentMigrationExists,
    consentMigrationExists ? 'Migration found' : 'Migration missing'
  );

  const deletedUsersMigrationPath = path.join(
    __dirname,
    '../sql/migrations/2025-01-XX-phase8-deleted-users.sql'
  );
  const deletedUsersMigrationExists = fs.existsSync(deletedUsersMigrationPath);
  recordResult(
    'Phase 8',
    '8.1',
    'Deleted users migration',
    deletedUsersMigrationExists,
    deletedUsersMigrationExists ? 'Migration found' : 'Migration missing'
  );
}

// ===============================================
// 8.2: Data Retention Policies
// ===============================================
async function validatePhase8_2() {
  console.log('\n⏰ Phase 8.2: Data Retention Policies\n');

  // Check data-retention-cron.ts exists
  const cronPath = path.join(__dirname, '../src/jobs/data-retention-cron.ts');
  const cronExists = fs.existsSync(cronPath);
  recordResult(
    'Phase 8',
    '8.2',
    'data-retention-cron.ts exists',
    cronExists,
    cronExists ? 'File found' : 'File not found'
  );

  if (cronExists) {
    const content = fs.readFileSync(cronPath, 'utf-8');

    const hasRetentionCleanup =
      content.includes('runDataRetentionCleanup') ||
      content.includes('scheduleDataRetentionCleanup');
    const hasMessageDeletion =
      content.includes('deleteExpiredMessages') || content.includes('expired');
    const hasAnonymization =
      content.includes('anonymizeExpiredUsers') || content.includes('anonymize');
    const hasConfigurablePeriods = content.includes('RETENTION') || content.includes('retention');

    recordResult(
      'Phase 8',
      '8.2',
      'Retention cleanup function',
      hasRetentionCleanup,
      hasRetentionCleanup ? 'Cleanup function found' : 'Cleanup function missing'
    );
    recordResult(
      'Phase 8',
      '8.2',
      'Message deletion',
      hasMessageDeletion,
      hasMessageDeletion ? 'Message deletion found' : 'Message deletion missing'
    );
    recordResult(
      'Phase 8',
      '8.2',
      'User anonymization',
      hasAnonymization,
      hasAnonymization ? 'Anonymization found' : 'Anonymization missing'
    );
    recordResult(
      'Phase 8',
      '8.2',
      'Configurable retention periods',
      hasConfigurablePeriods,
      hasConfigurablePeriods ? 'Configurable periods found' : 'Configurable periods missing'
    );
  }

  // Check if cron is scheduled in server
  const serverPath = path.join(__dirname, '../src/server/index.ts');
  if (fs.existsSync(serverPath)) {
    const content = fs.readFileSync(serverPath, 'utf-8');
    const hasDataRetentionImport =
      content.includes('data-retention-cron') || content.includes('dataRetention');
    recordResult(
      'Phase 8',
      '8.2',
      'Data retention scheduled in server',
      hasDataRetentionImport,
      hasDataRetentionImport ? 'Scheduled in server' : 'Not scheduled in server'
    );
  }
}

// ===============================================
// 8.3: Column Encryption (PII Encryption)
// ===============================================
async function validatePhase8_3() {
  console.log('\n🔐 Phase 8.3: PII Encryption at Rest\n');

  // Check encryption-service.ts exists
  const encryptionServicePath = path.join(__dirname, '../src/services/encryption-service.ts');
  const encryptionServiceExists = fs.existsSync(encryptionServicePath);
  recordResult(
    'Phase 8',
    '8.3',
    'encryption-service.ts exists',
    encryptionServiceExists,
    encryptionServiceExists ? 'File found' : 'File not found'
  );

  if (encryptionServiceExists) {
    const content = fs.readFileSync(encryptionServicePath, 'utf-8');
    const hasEncrypt = content.includes('encryptField') || content.includes('encrypt');
    const hasDecrypt = content.includes('decryptField') || content.includes('decrypt');

    recordResult(
      'Phase 8',
      '8.3',
      'Encrypt function',
      hasEncrypt,
      hasEncrypt ? 'Encrypt function found' : 'Encrypt function missing'
    );
    recordResult(
      'Phase 8',
      '8.3',
      'Decrypt function',
      hasDecrypt,
      hasDecrypt ? 'Decrypt function found' : 'Decrypt function missing'
    );
  }

  // Check PII encryption integration
  const piiIntegrationPath = path.join(__dirname, '../src/services/pii-encryption-integration.ts');
  const piiIntegrationExists = fs.existsSync(piiIntegrationPath);
  recordResult(
    'Phase 8',
    '8.3',
    'pii-encryption-integration.ts exists',
    piiIntegrationExists,
    piiIntegrationExists ? 'File found' : 'File not found'
  );

  if (piiIntegrationExists) {
    const content = fs.readFileSync(piiIntegrationPath, 'utf-8');
    const hasBeforeSave =
      content.includes('encryptPIIBeforeSave') || content.includes('beforeSave');
    const hasAfterRead = content.includes('decryptPIIAfterRead') || content.includes('afterRead');
    const hasMigration = content.includes('migratePIIToEncrypted') || content.includes('migrate');

    recordResult(
      'Phase 8',
      '8.3',
      'Encrypt before save hook',
      hasBeforeSave,
      hasBeforeSave ? 'Before save hook found' : 'Before save hook missing'
    );
    recordResult(
      'Phase 8',
      '8.3',
      'Decrypt after read hook',
      hasAfterRead,
      hasAfterRead ? 'After read hook found' : 'After read hook missing'
    );
    recordResult(
      'Phase 8',
      '8.3',
      'PII migration function',
      hasMigration,
      hasMigration ? 'Migration function found' : 'Migration function missing'
    );
  }

  // Check migration for PII encryption
  const piiMigrationPath = path.join(
    __dirname,
    '../sql/migrations/2025-01-XX-phase8-encrypt-existing-pii.sql'
  );
  const piiMigrationExists = fs.existsSync(piiMigrationPath);
  recordResult(
    'Phase 8',
    '8.3',
    'PII encryption migration',
    piiMigrationExists,
    piiMigrationExists ? 'Migration found' : 'Migration missing'
  );
}

// ===============================================
// Integration Checks
// ===============================================
async function validateIntegration() {
  console.log('\n🔗 Integration Checks\n');

  // Check if routes are registered
  const serverPath = path.join(__dirname, '../src/server/index.ts');
  if (fs.existsSync(serverPath)) {
    const content = fs.readFileSync(serverPath, 'utf-8');
    const hasUserDataRoutes =
      content.includes('user-data-routes') || content.includes('userDataRoutes');
    recordResult(
      'Phase 8',
      'Integration',
      'User data routes registered',
      hasUserDataRoutes,
      hasUserDataRoutes ? 'Routes registered' : 'Routes not registered'
    );
  }

  // Check if encryption is used in data export
  const routesPath = path.join(__dirname, '../src/routes/user-data-routes.ts');
  if (fs.existsSync(routesPath)) {
    const content = fs.readFileSync(routesPath, 'utf-8');
    const usesDecryption = content.includes('decrypt') || content.includes('decryptField');
    recordResult(
      'Phase 8',
      'Integration',
      'Decryption in data export',
      usesDecryption,
      usesDecryption ? 'Decryption integrated' : 'Decryption not integrated'
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
  console.log('   - Test user created\n');

  recordResult(
    'Phase 8',
    'Full',
    'Database migrations run',
    false,
    '⚠️  Run: psql $DATABASE_URL -f sql/migrations/2025-01-XX-phase8-*.sql'
  );
  recordResult(
    'Phase 8',
    'Full',
    'Data export endpoint testable',
    false,
    '⚠️  Test: GET /api/users/:id/data'
  );
  recordResult(
    'Phase 8',
    'Full',
    'Data deletion endpoint testable',
    false,
    '⚠️  Test: DELETE /api/users/:id/data'
  );
  recordResult(
    'Phase 8',
    'Full',
    'Consent endpoints testable',
    false,
    '⚠️  Test: POST/GET/DELETE /api/users/:id/consent'
  );
  recordResult(
    'Phase 8',
    'Full',
    'PII encryption working',
    false,
    '⚠️  Verify emails are encrypted in database'
  );
  recordResult(
    'Phase 8',
    'Full',
    'Data retention cron running',
    false,
    '⚠️  Verify cron job runs daily at 2 AM UTC'
  );
}

// ===============================================
// Main
// ===============================================
async function main() {
  const args = process.argv.slice(2);
  const fullValidation = args.includes('--full');

  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Phase 8: Privacy & Compliance - Validation');
  console.log('═══════════════════════════════════════════════════════════');

  await validatePhase8_1();
  await validatePhase8_2();
  await validatePhase8_3();
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
  const resultsPath = path.join(__dirname, '../validation-results-phase8.json');
  fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
  console.log(`\n📄 Results saved to: ${resultsPath}`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
