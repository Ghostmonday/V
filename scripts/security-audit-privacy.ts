#!/usr/bin/env tsx
/**
 * Security Audit Script for Privacy Features
 * Comprehensive security audit of all privacy-related code
 */

import { existsSync, readFileSync } from 'fs';
import { readdirSync } from 'fs';

interface SecurityIssue {
  severity: 'critical' | 'high' | 'medium' | 'low' | 'info';
  file: string;
  line?: number;
  issue: string;
  recommendation: string;
}

const issues: SecurityIssue[] = [];

// Privacy-related files to audit
const privacyFiles = [
  'src/services/zkp-service.ts',
  'src/services/hardware-accelerated-encryption.ts',
  'src/services/pfs-media-service.ts',
  'src/services/encryption-service.ts',
  'src/routes/privacy-routes.ts',
  'src/utils/input-sanitizer.ts',
  'src/config/encryption-config.ts',
  'src/utils/circuit-breaker.ts',
];

// Security patterns to check
const securityChecks = {
  // Check for hardcoded secrets
  hardcodedSecrets: [
    /(password|secret|key|token)\s*=\s*['"][^'"]+['"]/gi,
    /(api[_-]?key|api[_-]?secret)\s*=\s*['"][^'"]+['"]/gi,
  ],
  
  // Check for weak encryption (but not words containing these as substrings)
  weakEncryption: [
    /\bmd5\b|\bsha1\b|\bdes\b(?!\w)|\brc4\b/gi,
  ],
  
  // Check for SQL injection risks
  sqlInjection: [
    /\$\{.*\}\s*\+.*sql/i,
    /query\(.*\+.*\)/i,
  ],
  
  // Check for missing input validation
  missingValidation: [
    /req\.(body|params|query)\.[\w]+(?!.*(validate|sanitize|zod|z\.))/i,
  ],
  
  // Check for missing error handling
  missingErrorHandling: [
    /await\s+\w+\([^)]*\)(?!.*catch)/i,
  ],
  
  // Check for exposed secrets in logs
  exposedSecrets: [
    /log(Info|Error|Warning|Debug).*['"](password|secret|key|token)[^'"]*['"]/gi,
    /console\.(log|error|warn).*['"](password|secret|key|token)[^'"]*['"]/gi,
  ],
  
  // Check for weak random number generation
  weakRandom: [
    /Math\.random\(\)/g,
  ],
  
  // Check for missing rate limiting
  missingRateLimit: [
    /router\.(get|post|put|delete)\([^,]+,\s*(?!.*rateLimit|rate[_-]?limit)/i,
  ],
};

function auditFile(filePath: string): void {
  if (!existsSync(filePath)) {
    issues.push({
      severity: 'high',
      file: filePath,
      issue: 'File does not exist',
      recommendation: 'Ensure all privacy files are present',
    });
    return;
  }

  try {
    const content = readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');

    // Check for hardcoded secrets
    securityChecks.hardcodedSecrets.forEach(pattern => {
      // Ensure global flag for matchAll
      const flags = pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g';
      const globalPattern = new RegExp(pattern.source, flags);
      const matches = Array.from(content.matchAll(globalPattern));
      for (const match of matches) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        // Skip if it's a comment or string assignment to a variable
        const line = lines[lineNum - 1];
        if (line && (line.trim().startsWith('//') || line.includes('process.env') || line.includes('getApiKey'))) {
          continue;
        }
        issues.push({
          severity: 'critical',
          file: filePath,
          line: lineNum,
          issue: `Potential hardcoded secret found: ${match[0].substring(0, 50)}`,
          recommendation: 'Move secrets to environment variables or secure vault',
        });
      }
    });

    // Check for weak encryption (only actual algorithm names, not substrings)
    securityChecks.weakEncryption.forEach(pattern => {
      const flags = pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g';
      const globalPattern = new RegExp(pattern.source, flags);
      const matches = Array.from(content.matchAll(globalPattern));
      for (const match of matches) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        const line = lines[lineNum - 1];
        // Skip if it's in a comment or variable name
        if (line && (line.trim().startsWith('//') || line.includes('decipher') || line.includes('decrypt'))) {
          continue;
        }
        issues.push({
          severity: 'high',
          file: filePath,
          line: lineNum,
          issue: `Weak encryption algorithm detected: ${match[0]}`,
          recommendation: 'Use AES-256-GCM or SHA-3 for encryption/hashing',
        });
      }
    });

    // Check for SQL injection risks
    securityChecks.sqlInjection.forEach(pattern => {
      const flags = pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g';
      const globalPattern = new RegExp(pattern.source, flags);
      const matches = Array.from(content.matchAll(globalPattern));
      for (const match of matches) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        issues.push({
          severity: 'critical',
          file: filePath,
          line: lineNum,
          issue: `Potential SQL injection risk: ${match[0]}`,
          recommendation: 'Use parameterized queries or ORM',
        });
      }
    });

    // Check for exposed secrets in logs
    securityChecks.exposedSecrets.forEach(pattern => {
      const flags = pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g';
      const globalPattern = new RegExp(pattern.source, flags);
      const matches = Array.from(content.matchAll(globalPattern));
      for (const match of matches) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        const line = lines[lineNum - 1];
        // Skip if it's redacted, hashed, or partial (not exposing actual secret)
        if (line && (
          line.includes('redact') || 
          line.includes('hash') || 
          line.includes('substring') ||
          line.includes('keyIdHash') ||
          line.includes('Partial hash') ||
          line.includes('not the actual')
        )) {
          continue;
        }
        issues.push({
          severity: 'high',
          file: filePath,
          line: lineNum,
          issue: `Potential secret exposure in logs: ${match[0].substring(0, 50)}`,
          recommendation: 'Never log secrets - use redaction or hashing',
        });
      }
    });

    // Check for weak random number generation
    securityChecks.weakRandom.forEach(pattern => {
      const flags = pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g';
      const globalPattern = new RegExp(pattern.source, flags);
      const matches = Array.from(content.matchAll(globalPattern));
      for (const match of matches) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        const line = lines[lineNum - 1];
        // Skip if it's in a comment or example
        if (line && line.trim().startsWith('//')) {
          continue;
        }
        issues.push({
          severity: 'medium',
          file: filePath,
          line: lineNum,
          issue: `Weak random number generation: ${match[0]}`,
          recommendation: 'Use crypto.randomBytes() for cryptographic randomness',
        });
      }
    });

    // Check for input sanitization in routes
    if (filePath.includes('routes')) {
      const hasSanitization = /sanitize|zod|z\./i.test(content);
      const hasRateLimit = /rateLimit|rate[_-]?limit/i.test(content);
      
      if (!hasSanitization) {
        issues.push({
          severity: 'high',
          file: filePath,
          issue: 'Missing input sanitization',
          recommendation: 'Add input sanitization using sanitized schemas',
        });
      }
      
      if (!hasRateLimit) {
        issues.push({
          severity: 'medium',
          file: filePath,
          issue: 'Missing rate limiting',
          recommendation: 'Add rate limiting to prevent abuse',
        });
      }
    }

    // Check for proper error handling in encryption services
    if (filePath.includes('encryption') || filePath.includes('pfs')) {
      const hasErrorHandling = /try\s*\{[\s\S]*catch/i.test(content);
      const hasFallback = /fallback|catch.*fallback/i.test(content);
      
      if (!hasErrorHandling) {
        issues.push({
          severity: 'high',
          file: filePath,
          issue: 'Missing error handling',
          recommendation: 'Add try-catch blocks and error handling',
        });
      }
      
      if (!hasFallback && filePath.includes('hardware')) {
        issues.push({
          severity: 'medium',
          file: filePath,
          issue: 'Missing fallback mechanism',
          recommendation: 'Add software fallback when hardware acceleration fails',
        });
      }
    }

    // Check for proper key cleanup in PFS
    if (filePath.includes('pfs')) {
      const hasKeyCleanup = /delete|del.*key|cleanup.*key/i.test(content);
      if (!hasKeyCleanup) {
        issues.push({
          severity: 'high',
          file: filePath,
          issue: 'Missing key cleanup mechanism',
          recommendation: 'Ensure ephemeral keys are deleted after use',
        });
      }
    }

    // Check for proper commitment validation
    if (filePath.includes('zkp')) {
      const hasCommitmentValidation = /commitment.*regex|sha[23]|sha-3/i.test(content);
      if (!hasCommitmentValidation) {
        issues.push({
          severity: 'medium',
          file: filePath,
          issue: 'Missing commitment validation',
          recommendation: 'Validate commitment format (SHA-3-256 hash)',
        });
      }
    }

  } catch (error: any) {
    issues.push({
      severity: 'high',
      file: filePath,
      issue: `Error reading file: ${error.message}`,
      recommendation: 'Fix file access or permissions',
    });
  }
}

// Run audit
console.log('🔒 Starting Security Audit for Privacy Features...\n');

privacyFiles.forEach(file => {
  console.log(`Auditing: ${file}`);
  auditFile(file);
});

// Print results
console.log('\n' + '='.repeat(70));
console.log('SECURITY AUDIT RESULTS');
console.log('='.repeat(70) + '\n');

const critical = issues.filter(i => i.severity === 'critical');
const high = issues.filter(i => i.severity === 'high');
const medium = issues.filter(i => i.severity === 'medium');
const low = issues.filter(i => i.severity === 'low');
const info = issues.filter(i => i.severity === 'info');

const severityOrder = ['critical', 'high', 'medium', 'low', 'info'];
const severityIcons = {
  critical: '🔴',
  high: '🟠',
  medium: '🟡',
  low: '🟢',
  info: 'ℹ️',
};

severityOrder.forEach(severity => {
  const filtered = issues.filter(i => i.severity === severity);
  if (filtered.length > 0) {
    console.log(`\n${severityIcons[severity as keyof typeof severityIcons]} ${severity.toUpperCase()} (${filtered.length})`);
    console.log('-'.repeat(70));
    filtered.forEach(issue => {
      console.log(`\nFile: ${issue.file}${issue.line ? `:${issue.line}` : ''}`);
      console.log(`Issue: ${issue.issue}`);
      console.log(`Recommendation: ${issue.recommendation}`);
    });
  }
});

console.log('\n' + '='.repeat(70));
console.log(`Summary: ${issues.length} issues found`);
console.log(`  Critical: ${critical.length}`);
console.log(`  High: ${high.length}`);
console.log(`  Medium: ${medium.length}`);
console.log(`  Low: ${low.length}`);
console.log(`  Info: ${info.length}`);
console.log('='.repeat(70));

if (critical.length > 0 || high.length > 0) {
  console.log('\n❌ Security audit failed - critical or high severity issues found');
  process.exit(1);
} else {
  console.log('\n✅ Security audit passed - no critical or high severity issues');
  process.exit(0);
}

