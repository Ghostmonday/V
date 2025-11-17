#!/usr/bin/env tsx
/**
 * Phase 7: Testing & Quality Assurance - Validation Script
 *
 * Usage:
 *   tsx scripts/validate-phase7.ts              # Code-level validation (runs now)
 *   tsx scripts/validate-phase7.ts --full       # Full validation (requires running system)
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
// 7.1: Unit Tests
// ===============================================
async function validatePhase7_1() {
  console.log('\n🧪 Phase 7.1: Unit Tests\n');

  // Check test infrastructure
  const testSetupPath = path.join(__dirname, '../src/tests/__helpers__/test-setup.ts');
  const testSetupExists = fs.existsSync(testSetupPath);
  recordResult(
    'Phase 7',
    '7.1',
    'test-setup.ts exists',
    testSetupExists,
    testSetupExists ? 'Test infrastructure found' : 'Test infrastructure missing'
  );

  // Check unit test files
  const unitTests = [
    {
      name: 'user-authentication-service.test.ts',
      path: 'src/services/__tests__/user-authentication-service.test.ts',
    },
    {
      name: 'refresh-token-service.test.ts',
      path: 'src/services/__tests__/refresh-token-service.test.ts',
    },
    { name: 'rate-limiter.test.ts', path: 'src/middleware/__tests__/rate-limiter.test.ts' },
    {
      name: 'sentiment-analysis-service.test.ts',
      path: 'src/services/__tests__/sentiment-analysis-service.test.ts',
    },
    {
      name: 'moderation-service.test.ts',
      path: 'src/services/__tests__/moderation-service.test.ts',
    },
    { name: 'message-service.test.ts', path: 'src/services/__tests__/message-service.test.ts' },
  ];

  let unitTestCount = 0;
  for (const test of unitTests) {
    const testPath = path.join(__dirname, '..', test.path);
    const exists = fs.existsSync(testPath);
    if (exists) {
      unitTestCount++;
      const content = fs.readFileSync(testPath, 'utf-8');
      const hasTests =
        content.includes('describe') || content.includes('it(') || content.includes('test(');
      recordResult(
        'Phase 7',
        '7.1',
        `${test.name} exists`,
        true,
        hasTests ? 'Test file found with tests' : 'Test file exists but no tests found'
      );
    } else {
      recordResult('Phase 7', '7.1', `${test.name} exists`, false, 'Test file missing');
    }
  }

  recordResult(
    'Phase 7',
    '7.1',
    'Unit test files count',
    unitTestCount >= 5,
    `${unitTestCount}/6 unit test files found`
  );

  // Check vitest config
  const vitestConfigPath = path.join(__dirname, '../vitest.config.ts');
  const vitestConfigExists = fs.existsSync(vitestConfigPath);
  recordResult(
    'Phase 7',
    '7.1',
    'vitest.config.ts exists',
    vitestConfigExists,
    vitestConfigExists ? 'Vitest config found' : 'Vitest config missing'
  );

  if (vitestConfigExists) {
    const content = fs.readFileSync(vitestConfigPath, 'utf-8');
    const hasCoverage = content.includes('coverage') && content.includes('80');
    recordResult(
      'Phase 7',
      '7.1',
      'Coverage threshold (80%)',
      hasCoverage,
      hasCoverage ? 'Coverage threshold configured' : 'Coverage threshold missing'
    );
  }
}

// ===============================================
// 7.2: Integration Tests
// ===============================================
async function validatePhase7_2() {
  console.log('\n🔗 Phase 7.2: Integration Tests\n');

  // Check integration test files
  const integrationTests = [
    { name: 'websocket.test.ts', path: 'src/tests/integration/websocket.test.ts' },
    { name: 'api-endpoints.test.ts', path: 'src/tests/integration/api-endpoints.test.ts' },
  ];

  let integrationTestCount = 0;
  for (const test of integrationTests) {
    const testPath = path.join(__dirname, '..', test.path);
    const exists = fs.existsSync(testPath);
    if (exists) {
      integrationTestCount++;
      const content = fs.readFileSync(testPath, 'utf-8');
      const hasTests =
        content.includes('describe') || content.includes('it(') || content.includes('test(');
      recordResult(
        'Phase 7',
        '7.2',
        `${test.name} exists`,
        true,
        hasTests ? 'Integration test found' : 'Test file exists but no tests found'
      );

      // Check for specific test scenarios
      if (test.name === 'websocket.test.ts') {
        const hasConnectionTests = content.includes('connection') || content.includes('WebSocket');
        const hasMessageTests = content.includes('message') || content.includes('send');
        recordResult(
          'Phase 7',
          '7.2',
          'WebSocket connection tests',
          hasConnectionTests,
          hasConnectionTests ? 'Connection tests found' : 'Connection tests missing'
        );
        recordResult(
          'Phase 7',
          '7.2',
          'WebSocket message tests',
          hasMessageTests,
          hasMessageTests ? 'Message tests found' : 'Message tests missing'
        );
      }

      if (test.name === 'api-endpoints.test.ts') {
        const hasAuthTests =
          content.includes('auth') || content.includes('login') || content.includes('token');
        const hasErrorTests =
          content.includes('error') || content.includes('400') || content.includes('500');
        recordResult(
          'Phase 7',
          '7.2',
          'API auth tests',
          hasAuthTests,
          hasAuthTests ? 'Auth tests found' : 'Auth tests missing'
        );
        recordResult(
          'Phase 7',
          '7.2',
          'API error handling tests',
          hasErrorTests,
          hasErrorTests ? 'Error handling tests found' : 'Error handling tests missing'
        );
      }
    } else {
      recordResult('Phase 7', '7.2', `${test.name} exists`, false, 'Integration test file missing');
    }
  }

  recordResult(
    'Phase 7',
    '7.2',
    'Integration test files count',
    integrationTestCount >= 2,
    `${integrationTestCount}/2 integration test files found`
  );
}

// ===============================================
// 7.3: Load Testing
// ===============================================
async function validatePhase7_3() {
  console.log('\n⚡ Phase 7.3: Load Testing\n');

  // Check load test directory
  const loadTestDir = path.join(__dirname, '../scripts/load-test');
  const loadTestDirExists = fs.existsSync(loadTestDir);
  recordResult(
    'Phase 7',
    '7.3',
    'load-test directory exists',
    loadTestDirExists,
    loadTestDirExists ? 'Load test directory found' : 'Load test directory missing'
  );

  if (loadTestDirExists) {
    // Check k6 script
    const k6ScriptPath = path.join(loadTestDir, 'k6-load-test.js');
    const k6Exists = fs.existsSync(k6ScriptPath);
    recordResult(
      'Phase 7',
      '7.3',
      'k6-load-test.js exists',
      k6Exists,
      k6Exists ? 'k6 script found' : 'k6 script missing'
    );

    if (k6Exists) {
      const content = fs.readFileSync(k6ScriptPath, 'utf-8');
      const has10kUsers = content.includes('10000') || content.includes('10k');
      const hasMessageThroughput = content.includes('message') || content.includes('throughput');
      recordResult(
        'Phase 7',
        '7.3',
        '10k concurrent users scenario',
        has10kUsers,
        has10kUsers ? '10k users scenario found' : '10k users scenario missing'
      );
      recordResult(
        'Phase 7',
        '7.3',
        'Message throughput testing',
        hasMessageThroughput,
        hasMessageThroughput ? 'Message throughput tests found' : 'Message throughput tests missing'
      );
    }

    // Check Artillery config
    const artilleryPath = path.join(loadTestDir, 'artillery-config.yml');
    const artilleryExists = fs.existsSync(artilleryPath);
    recordResult(
      'Phase 7',
      '7.3',
      'artillery-config.yml exists',
      artilleryExists,
      artilleryExists ? 'Artillery config found' : 'Artillery config missing'
    );

    // Check README
    const readmePath = path.join(loadTestDir, 'README.md');
    const readmeExists = fs.existsSync(readmePath);
    recordResult(
      'Phase 7',
      '7.3',
      'Load test README exists',
      readmeExists,
      readmeExists ? 'Documentation found' : 'Documentation missing'
    );
  }
}

// ===============================================
// Test Infrastructure Checks
// ===============================================
async function validateTestInfrastructure() {
  console.log('\n🛠️  Test Infrastructure\n');

  // Check package.json for test scripts
  const packageJsonPath = path.join(__dirname, '../package.json');
  if (fs.existsSync(packageJsonPath)) {
    const content = fs.readFileSync(packageJsonPath, 'utf-8');
    const hasTestScript = content.includes('"test"') || content.includes('"test:');
    const hasCoverageScript = content.includes('coverage') || content.includes('test:coverage');
    const hasWatchScript = content.includes('watch') || content.includes('test:watch');

    recordResult(
      'Phase 7',
      'Infrastructure',
      'Test script in package.json',
      hasTestScript,
      hasTestScript ? 'Test script found' : 'Test script missing'
    );
    recordResult(
      'Phase 7',
      'Infrastructure',
      'Coverage script',
      hasCoverageScript,
      hasCoverageScript ? 'Coverage script found' : 'Coverage script missing'
    );
    recordResult(
      'Phase 7',
      'Infrastructure',
      'Watch script',
      hasWatchScript,
      hasWatchScript ? 'Watch script found' : 'Watch script missing'
    );
  }

  // Check CI/CD integration
  const ciPath = path.join(__dirname, '../.github/workflows/ci.yml');
  const ciExists = fs.existsSync(ciPath);
  if (ciExists) {
    const content = fs.readFileSync(ciPath, 'utf-8');
    const hasTestJob = content.includes('test') || content.includes('Test');
    recordResult(
      'Phase 7',
      'Infrastructure',
      'CI/CD test job',
      hasTestJob,
      hasTestJob ? 'CI/CD test job found' : 'CI/CD test job missing'
    );
  } else {
    recordResult(
      'Phase 7',
      'Infrastructure',
      'CI/CD test job',
      false,
      'CI/CD workflow file missing'
    );
  }
}

// ===============================================
// Full Validation (requires running system)
// ===============================================
async function validateFull() {
  console.log('\n🔬 Full Validation (requires running system)\n');
  console.log('⚠️  This requires:');
  console.log('   - Dependencies installed (npm install)');
  console.log('   - Test database configured');
  console.log('   - Load testing tools installed (k6, Artillery)\n');

  recordResult('Phase 7', 'Full', 'Unit tests pass', false, '⚠️  Run: npm test');
  recordResult(
    'Phase 7',
    'Full',
    'Integration tests pass',
    false,
    '⚠️  Run: npm test -- src/tests/integration/'
  );
  recordResult('Phase 7', 'Full', 'Coverage > 80%', false, '⚠️  Run: npm run test:coverage');
  recordResult(
    'Phase 7',
    'Full',
    'Load tests runnable',
    false,
    '⚠️  Run: k6 run scripts/load-test/k6-load-test.js'
  );
}

// ===============================================
// Main
// ===============================================
async function main() {
  const args = process.argv.slice(2);
  const fullValidation = args.includes('--full');

  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Phase 7: Testing & Quality Assurance - Validation');
  console.log('═══════════════════════════════════════════════════════════');

  await validatePhase7_1();
  await validatePhase7_2();
  await validatePhase7_3();
  await validateTestInfrastructure();

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
  const resultsPath = path.join(__dirname, '../validation-results-phase7.json');
  fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
  console.log(`\n📄 Results saved to: ${resultsPath}`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
