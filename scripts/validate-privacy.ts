#!/usr/bin/env tsx
/**
 * Privacy Features Validation Script
 * Validates zero-knowledge proofs, hardware-accelerated encryption, and PFS
 */

import { existsSync } from 'fs';
import { readFileSync } from 'fs';

interface ValidationResult {
  feature: string;
  status: 'pass' | 'fail' | 'warning';
  message: string;
  details?: string[];
}

const results: ValidationResult[] = [];

function validateFile(filePath: string, requiredExports: string[]): ValidationResult {
  const exists = existsSync(filePath);
  if (!exists) {
    return {
      feature: `File: ${filePath}`,
      status: 'fail',
      message: `File does not exist`,
    };
  }

  try {
    const content = readFileSync(filePath, 'utf-8');
    const missingExports: string[] = [];

    for (const exportName of requiredExports) {
      // Check for export (function, const, class, interface, type)
      const patterns = [
        new RegExp(`export\\s+(async\\s+)?function\\s+${exportName}`),
        new RegExp(`export\\s+const\\s+${exportName}`),
        new RegExp(`export\\s+class\\s+${exportName}`),
        new RegExp(`export\\s+interface\\s+${exportName}`),
        new RegExp(`export\\s+type\\s+${exportName}`),
        new RegExp(`export\\s+\\{[^}]*${exportName}[^}]*\\}`),
      ];

      const found = patterns.some((pattern) => pattern.test(content));
      if (!found) {
        missingExports.push(exportName);
      }
    }

    if (missingExports.length > 0) {
      return {
        feature: `File: ${filePath}`,
        status: 'fail',
        message: `Missing exports: ${missingExports.join(', ')}`,
        details: missingExports,
      };
    }

    return {
      feature: `File: ${filePath}`,
      status: 'pass',
      message: `All required exports found`,
    };
  } catch (error: any) {
    return {
      feature: `File: ${filePath}`,
      status: 'fail',
      message: `Error reading file: ${error.message}`,
    };
  }
}

function validateRoute(routePath: string, requiredRoutes: string[]): ValidationResult {
  const exists = existsSync(routePath);
  if (!exists) {
    return {
      feature: `Route file: ${routePath}`,
      status: 'fail',
      message: `Route file does not exist`,
    };
  }

  try {
    const content = readFileSync(routePath, 'utf-8');
    const missingRoutes: string[] = [];

    for (const route of requiredRoutes) {
      // Check for route definition (router.get, router.post, etc.)
      const pattern = new RegExp(
        `router\\.(get|post|put|delete)\\s*\\(\\s*['"]${route.replace(/\//g, '\\/')}['"]`,
        'i'
      );
      if (!pattern.test(content)) {
        missingRoutes.push(route);
      }
    }

    if (missingRoutes.length > 0) {
      return {
        feature: `Route file: ${routePath}`,
        status: 'fail',
        message: `Missing routes: ${missingRoutes.join(', ')}`,
        details: missingRoutes,
      };
    }

    return {
      feature: `Route file: ${routePath}`,
      status: 'pass',
      message: `All required routes found`,
    };
  } catch (error: any) {
    return {
      feature: `Route file: ${routePath}`,
      status: 'fail',
      message: `Error reading file: ${error.message}`,
    };
  }
}

function validateMigration(migrationPath: string): ValidationResult {
  const exists = existsSync(migrationPath);
  if (!exists) {
    return {
      feature: `Migration: ${migrationPath}`,
      status: 'fail',
      message: `Migration file does not exist`,
    };
  }

  try {
    const content = readFileSync(migrationPath, 'utf-8');

    // Check for required table
    const hasTable = /CREATE TABLE.*user_zkp_commitments/i.test(content);
    const hasRLS = /ENABLE ROW LEVEL SECURITY/i.test(content);
    const hasPolicies = /CREATE POLICY/i.test(content);

    if (!hasTable) {
      return {
        feature: `Migration: ${migrationPath}`,
        status: 'fail',
        message: `Missing user_zkp_commitments table`,
      };
    }

    if (!hasRLS) {
      return {
        feature: `Migration: ${migrationPath}`,
        status: 'warning',
        message: `Missing RLS policies`,
      };
    }

    return {
      feature: `Migration: ${migrationPath}`,
      status: 'pass',
      message: `Migration file valid`,
    };
  } catch (error: any) {
    return {
      feature: `Migration: ${migrationPath}`,
      status: 'fail',
      message: `Error reading file: ${error.message}`,
    };
  }
}

// Validate Zero-Knowledge Proof Service
console.log('🔍 Validating Zero-Knowledge Proof Service...');
results.push(
  validateFile('src/services/zkp-service.ts', [
    'generateAttributeProof',
    'verifyAttributeProof',
    'generateSelectiveDisclosure',
    'verifySelectiveDisclosure',
    'storeProofCommitments',
    'AttributeType',
    'AttributeProof',
    'DisclosureRequest',
    'DisclosureProof',
  ])
);

// Validate Hardware-Accelerated Encryption Service
console.log('🔍 Validating Hardware-Accelerated Encryption Service...');
results.push(
  validateFile('src/services/hardware-accelerated-encryption.ts', [
    'detectHardwareAcceleration',
    'getOptimalEncryptionAlgorithm',
    'encryptWithHardwareAcceleration',
    'decryptWithHardwareAcceleration',
    'benchmarkEncryption',
  ])
);

// Validate PFS Media Service
console.log('🔍 Validating Perfect Forward Secrecy Media Service...');
results.push(
  validateFile('src/services/pfs-media-service.ts', [
    'generateEphemeralKeyPair',
    'deriveSharedSecret',
    'createPFSCallSession',
    'deriveMediaEncryptionKey',
    'encryptMediaStream',
    'decryptMediaStream',
    'endPFSCallSession',
    'cleanupExpiredPFSSessions',
    'EphemeralKeyPair',
    'PFSCallSession',
  ])
);

// Validate Privacy Routes
console.log('🔍 Validating Privacy Routes...');
results.push(
  validateRoute('src/routes/privacy-routes.ts', [
    '/selective-disclosure',
    '/verify-disclosure',
    '/encryption-status',
    '/zkp/commitments/:userId',
  ])
);

// Validate Migration
console.log('🔍 Validating Database Migration...');
results.push(validateMigration('sql/migrations/2025-01-XX-privacy-zkp-commitments.sql'));

// Validate Integration
console.log('🔍 Validating Integration...');

// Check encryption-service integration
const encryptionServiceExists = existsSync('src/services/encryption-service.ts');
if (encryptionServiceExists) {
  const content = readFileSync('src/services/encryption-service.ts', 'utf-8');
  const hasHardwareAccel = /hardware-accelerated-encryption/i.test(content);
  results.push({
    feature: 'Encryption Service Integration',
    status: hasHardwareAccel ? 'pass' : 'fail',
    message: hasHardwareAccel
      ? 'Hardware acceleration integrated'
      : 'Hardware acceleration not integrated',
  });
}

// Check voice routes integration
const voiceRoutesExists = existsSync('src/routes/voice-routes.ts');
if (voiceRoutesExists) {
  const content = readFileSync('src/routes/voice-routes.ts', 'utf-8');
  const hasPFS = /pfs-media-service|Perfect Forward Secrecy|PFS/i.test(content);
  results.push({
    feature: 'Voice Routes PFS Integration',
    status: hasPFS ? 'pass' : 'fail',
    message: hasPFS ? 'PFS integrated in voice routes' : 'PFS not integrated in voice routes',
  });
}

// Check server integration
const serverExists = existsSync('src/server/index.ts');
if (serverExists) {
  const content = readFileSync('src/server/index.ts', 'utf-8');
  const hasPrivacyRoutes = /privacy-routes|privacyRoutes/i.test(content);
  results.push({
    feature: 'Server Integration',
    status: hasPrivacyRoutes ? 'pass' : 'fail',
    message: hasPrivacyRoutes
      ? 'Privacy routes registered in server'
      : 'Privacy routes not registered in server',
  });
}

// Print Results
console.log('\n' + '='.repeat(60));
console.log('VALIDATION RESULTS');
console.log('='.repeat(60) + '\n');

const passed = results.filter((r) => r.status === 'pass').length;
const failed = results.filter((r) => r.status === 'fail').length;
const warnings = results.filter((r) => r.status === 'warning').length;

results.forEach((result) => {
  const icon = result.status === 'pass' ? '✅' : result.status === 'fail' ? '❌' : '⚠️';
  console.log(`${icon} ${result.feature}`);
  console.log(`   ${result.message}`);
  if (result.details && result.details.length > 0) {
    result.details.forEach((detail) => {
      console.log(`   - ${detail}`);
    });
  }
  console.log('');
});

console.log('='.repeat(60));
console.log(`Summary: ${passed} passed, ${failed} failed, ${warnings} warnings`);
console.log('='.repeat(60));

if (failed > 0) {
  console.log('\n❌ Validation failed. Please fix the issues above.');
  process.exit(1);
} else {
  console.log('\n✅ All validations passed!');
  process.exit(0);
}
