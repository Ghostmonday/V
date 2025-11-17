#!/usr/bin/env tsx
/**
 * Phase 6: Observability & Operations - Validation Script
 *
 * Usage:
 *   tsx scripts/validate-phase6.ts              # Code-level validation (runs now)
 *   tsx scripts/validate-phase6.ts --full      # Full validation (requires running system)
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
// 6.1: Structured Logging
// ===============================================
async function validatePhase6_1() {
  console.log('\n📝 Phase 6.1: Structured Logging\n');

  // Check structured-logging.ts exists
  const loggingPath = path.join(__dirname, '../src/middleware/structured-logging.ts');
  const loggingExists = fs.existsSync(loggingPath);
  recordResult(
    'Phase 6',
    '6.1',
    'structured-logging.ts exists',
    loggingExists,
    loggingExists ? 'File found' : 'File not found'
  );

  if (loggingExists) {
    const content = fs.readFileSync(loggingPath, 'utf-8');

    // Check for request ID generation
    const hasRequestId = content.includes('requestId') && content.includes('randomUUID');
    recordResult(
      'Phase 6',
      '6.1',
      'Request ID generation',
      hasRequestId,
      hasRequestId ? 'Request IDs generated' : 'Request ID generation missing'
    );

    // Check for correlation ID
    const hasCorrelationId =
      content.includes('correlationId') || content.includes('correlation-id');
    recordResult(
      'Phase 6',
      '6.1',
      'Correlation ID support',
      hasCorrelationId,
      hasCorrelationId ? 'Correlation IDs supported' : 'Correlation IDs missing'
    );

    // Check for JSON log format
    const hasJsonLog = content.includes('JSON.stringify') && content.includes('console.log');
    recordResult(
      'Phase 6',
      '6.1',
      'JSON log format',
      hasJsonLog,
      hasJsonLog ? 'JSON logging found' : 'JSON logging missing'
    );

    // Check for log levels
    const hasLogLevels = content.includes("level: 'info'") || content.includes("level: 'error'");
    recordResult(
      'Phase 6',
      '6.1',
      'Log levels',
      hasLogLevels,
      hasLogLevels ? 'Log levels found' : 'Log levels missing'
    );

    // Check for service name
    const hasServiceName = content.includes('service') || content.includes('SERVICE_NAME');
    recordResult(
      'Phase 6',
      '6.1',
      'Service identification',
      hasServiceName,
      hasServiceName ? 'Service name in logs' : 'Service name missing'
    );

    // Check for helper functions
    const hasHelpers = content.includes('getCorrelationId') || content.includes('getRequestId');
    recordResult(
      'Phase 6',
      '6.1',
      'Helper functions',
      hasHelpers,
      hasHelpers ? 'Helper functions found' : 'Helper functions missing'
    );
  }
}

// ===============================================
// 6.2: Metrics Collection Enhancement
// ===============================================
async function validatePhase6_2() {
  console.log('\n📊 Phase 6.2: Metrics Collection Enhancement\n');

  // Check monitoring-service.ts exists
  const monitoringPath = path.join(__dirname, '../src/services/monitoring-service.ts');
  const monitoringExists = fs.existsSync(monitoringPath);
  recordResult(
    'Phase 6',
    '6.2',
    'monitoring-service.ts exists',
    monitoringExists,
    monitoringExists ? 'File found' : 'File not found'
  );

  if (monitoringExists) {
    const content = fs.readFileSync(monitoringPath, 'utf-8');

    // Check for custom business metrics
    const hasRateLimitMetrics = content.includes('rate_limit') || content.includes('rateLimit');
    const hasSentimentMetrics = content.includes('sentiment');
    const hasModerationMetrics = content.includes('moderation') || content.includes('toxicity');
    const hasCardMetrics =
      content.includes('card_generation') || content.includes('cardGeneration');

    recordResult(
      'Phase 6',
      '6.2',
      'Rate limit metrics',
      hasRateLimitMetrics,
      hasRateLimitMetrics ? 'Rate limit metrics found' : 'Rate limit metrics missing'
    );
    recordResult(
      'Phase 6',
      '6.2',
      'Sentiment metrics',
      hasSentimentMetrics,
      hasSentimentMetrics ? 'Sentiment metrics found' : 'Sentiment metrics missing'
    );
    recordResult(
      'Phase 6',
      '6.2',
      'Moderation metrics',
      hasModerationMetrics,
      hasModerationMetrics ? 'Moderation metrics found' : 'Moderation metrics missing'
    );
    recordResult(
      'Phase 6',
      '6.2',
      'Card generation metrics',
      hasCardMetrics,
      hasCardMetrics ? 'Card generation metrics found' : 'Card generation metrics missing'
    );
  }

  // Check slow query tracker
  const slowQueryPath = path.join(__dirname, '../src/services/slow-query-tracker.ts');
  const slowQueryExists = fs.existsSync(slowQueryPath);
  recordResult(
    'Phase 6',
    '6.2',
    'slow-query-tracker.ts exists',
    slowQueryExists,
    slowQueryExists ? 'File found' : 'File not found'
  );

  if (slowQueryExists) {
    const content = fs.readFileSync(slowQueryPath, 'utf-8');
    const hasSlowQueryTracking =
      content.includes('100') &&
      (content.includes('startQueryTracking') || content.includes('endQueryTracking'));
    recordResult(
      'Phase 6',
      '6.2',
      'Slow query tracking (>100ms)',
      hasSlowQueryTracking,
      hasSlowQueryTracking ? 'Slow query tracking found' : 'Slow query tracking missing'
    );
  }

  // Check connection pool monitor
  const poolMonitorPath = path.join(__dirname, '../src/services/connection-pool-monitor.ts');
  const poolMonitorExists = fs.existsSync(poolMonitorPath);
  recordResult(
    'Phase 6',
    '6.2',
    'connection-pool-monitor.ts exists',
    poolMonitorExists,
    poolMonitorExists ? 'File found' : 'File not found'
  );

  if (poolMonitorExists) {
    const content = fs.readFileSync(poolMonitorPath, 'utf-8');
    const hasPoolMonitoring = content.includes('connection_pool') || content.includes('pool');
    recordResult(
      'Phase 6',
      '6.2',
      'Connection pool monitoring',
      hasPoolMonitoring,
      hasPoolMonitoring ? 'Pool monitoring found' : 'Pool monitoring missing'
    );
  }
}

// ===============================================
// 6.3: Error Alerting
// ===============================================
async function validatePhase6_3() {
  console.log('\n🚨 Phase 6.3: Error Alerting\n');

  // Check error-alerting.ts exists
  const alertingPath = path.join(__dirname, '../src/middleware/error-alerting.ts');
  const alertingExists = fs.existsSync(alertingPath);
  recordResult(
    'Phase 6',
    '6.3',
    'error-alerting.ts exists',
    alertingExists,
    alertingExists ? 'File found' : 'File not found'
  );

  if (alertingExists) {
    const content = fs.readFileSync(alertingPath, 'utf-8');

    // Check for Slack integration
    const hasSlack =
      content.includes('slack') || content.includes('Slack') || content.includes('SLACK_WEBHOOK');
    recordResult(
      'Phase 6',
      '6.3',
      'Slack webhook integration',
      hasSlack,
      hasSlack ? 'Slack integration found' : 'Slack integration missing'
    );

    // Check for SendGrid/Email
    const hasEmail =
      content.includes('sendgrid') ||
      content.includes('SendGrid') ||
      content.includes('SENDGRID') ||
      content.includes('email');
    recordResult(
      'Phase 6',
      '6.3',
      'Email alerts (SendGrid)',
      hasEmail,
      hasEmail ? 'Email alerts found' : 'Email alerts missing'
    );

    // Check for PagerDuty
    const hasPagerDuty =
      content.includes('pagerduty') ||
      content.includes('PagerDuty') ||
      content.includes('PAGERDUTY');
    recordResult(
      'Phase 6',
      '6.3',
      'PagerDuty integration',
      hasPagerDuty,
      hasPagerDuty ? 'PagerDuty integration found' : 'PagerDuty integration missing'
    );

    // Check for error rate tracking
    const hasErrorTracking = content.includes('errorCounts') || content.includes('alertThreshold');
    recordResult(
      'Phase 6',
      '6.3',
      'Error rate tracking',
      hasErrorTracking,
      hasErrorTracking ? 'Error rate tracking found' : 'Error rate tracking missing'
    );

    // Check for severity levels
    const hasSeverity = content.includes('severity') || content.includes('critical');
    recordResult(
      'Phase 6',
      '6.3',
      'Severity levels',
      hasSeverity,
      hasSeverity ? 'Severity levels found' : 'Severity levels missing'
    );
  }
}

// ===============================================
// 6.4: Telemetry Optimization
// ===============================================
async function validatePhase6_4() {
  console.log('\n📈 Phase 6.4: Telemetry Optimization\n');

  // Check telemetry-service.ts exists
  const telemetryPath = path.join(__dirname, '../src/services/telemetry-service.ts');
  const telemetryExists = fs.existsSync(telemetryPath);
  recordResult(
    'Phase 6',
    '6.4',
    'telemetry-service.ts exists',
    telemetryExists,
    telemetryExists ? 'File found' : 'File not found'
  );

  if (telemetryExists) {
    const content = fs.readFileSync(telemetryPath, 'utf-8');

    // Check for event sampling
    const hasSampling =
      content.includes('sampling') ||
      content.includes('SAMPLING_RATE') ||
      content.includes('Math.random');
    recordResult(
      'Phase 6',
      '6.4',
      'Event sampling',
      hasSampling,
      hasSampling ? 'Event sampling found' : 'Event sampling missing'
    );

    // Check for compression
    const hasCompression =
      content.includes('compress') || content.includes('compressed') || content.includes('gzip');
    recordResult(
      'Phase 6',
      '6.4',
      'Telemetry compression',
      hasCompression,
      hasCompression ? 'Compression found' : 'Compression missing'
    );

    // Check for critical event preservation
    const hasCriticalPreservation =
      content.includes('critical') || content.includes('isCriticalEvent');
    recordResult(
      'Phase 6',
      '6.4',
      'Critical event preservation',
      hasCriticalPreservation,
      hasCriticalPreservation ? 'Critical events preserved' : 'Critical event preservation missing'
    );
  }

  // Check OpenTelemetry integration
  const otelPath = path.join(__dirname, '../src/services/opentelemetry-integration.ts');
  const otelExists = fs.existsSync(otelPath);
  recordResult(
    'Phase 6',
    '6.4',
    'opentelemetry-integration.ts exists',
    otelExists,
    otelExists ? 'File found' : 'File not found'
  );

  if (otelExists) {
    const content = fs.readFileSync(otelPath, 'utf-8');
    const hasOtelIntegration =
      content.includes('OpenTelemetry') ||
      content.includes('sendTrace') ||
      content.includes('sendMetrics');
    recordResult(
      'Phase 6',
      '6.4',
      'OpenTelemetry integration',
      hasOtelIntegration,
      hasOtelIntegration ? 'OpenTelemetry integration found' : 'OpenTelemetry integration missing'
    );
  }
}

// ===============================================
// Integration Checks
// ===============================================
async function validateIntegration() {
  console.log('\n🔗 Integration Checks\n');

  // Check if structured logging is used in server
  const serverPath = path.join(__dirname, '../src/server/index.ts');
  if (fs.existsSync(serverPath)) {
    const content = fs.readFileSync(serverPath, 'utf-8');
    const usesStructuredLogging =
      content.includes('structured-logging') || content.includes('structuredLogging');
    recordResult(
      'Phase 6',
      'Integration',
      'Structured logging middleware',
      usesStructuredLogging,
      usesStructuredLogging ? 'Middleware registered' : 'Middleware not registered'
    );
  }

  // Check if error alerting is used
  const errorPath = path.join(__dirname, '../src/middleware/error.ts');
  if (fs.existsSync(errorPath)) {
    const content = fs.readFileSync(errorPath, 'utf-8');
    const usesErrorAlerting =
      content.includes('error-alerting') || content.includes('alertOnError');
    recordResult(
      'Phase 6',
      'Integration',
      'Error alerting integration',
      usesErrorAlerting,
      usesErrorAlerting ? 'Error alerting integrated' : 'Error alerting not integrated'
    );
  }

  // Check if metrics are exposed
  const serverIndexPath = path.join(__dirname, '../src/server/index.ts');
  if (fs.existsSync(serverIndexPath)) {
    const content = fs.readFileSync(serverIndexPath, 'utf-8');
    const hasMetricsEndpoint = content.includes('/metrics') || content.includes('metrics');
    recordResult(
      'Phase 6',
      'Integration',
      'Prometheus metrics endpoint',
      hasMetricsEndpoint,
      hasMetricsEndpoint ? 'Metrics endpoint found' : 'Metrics endpoint missing'
    );
  }
}

// ===============================================
// Full Validation (requires running system)
// ===============================================
async function validateFull() {
  console.log('\n🔬 Full Validation (requires running system)\n');
  console.log('⚠️  This requires:');
  console.log('   - Server running');
  console.log('   - Environment variables configured');
  console.log('   - External services (Slack, SendGrid, PagerDuty) configured\n');

  recordResult(
    'Phase 6',
    'Full',
    'Structured logs in production',
    false,
    '⚠️  Check logs are in JSON format with correlation IDs'
  );
  recordResult(
    'Phase 6',
    'Full',
    'Metrics endpoint accessible',
    false,
    '⚠️  Test: curl http://localhost:3000/metrics'
  );
  recordResult(
    'Phase 6',
    'Full',
    'Error alerting configured',
    false,
    '⚠️  Set SLACK_WEBHOOK_URL, SENDGRID_API_KEY, PAGERDUTY_INTEGRATION_KEY'
  );
  recordResult(
    'Phase 6',
    'Full',
    'Telemetry sampling working',
    false,
    '⚠️  Verify only 10% of events are persisted (check telemetry table)'
  );
}

// ===============================================
// Main
// ===============================================
async function main() {
  const args = process.argv.slice(2);
  const fullValidation = args.includes('--full');

  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Phase 6: Observability & Operations - Validation');
  console.log('═══════════════════════════════════════════════════════════');

  await validatePhase6_1();
  await validatePhase6_2();
  await validatePhase6_3();
  await validatePhase6_4();
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
  const resultsPath = path.join(__dirname, '../validation-results-phase6.json');
  fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
  console.log(`\n📄 Results saved to: ${resultsPath}`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
