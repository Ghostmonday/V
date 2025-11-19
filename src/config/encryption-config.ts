/**
 * Encryption Configuration Module
 * Abstracts AES detection and configuration for easier testing and maintenance
 */

import crypto from 'crypto';
import { logInfo, logWarning } from '../shared/logger-shared.js';

/**
 * Encryption configuration interface
 */
export interface EncryptionConfig {
  hardwareAccelerated: boolean;
  preferredAlgorithm: string;
  detected: boolean;
  testDurationMs?: number;
}

/**
 * Encryption configuration singleton
 */
class EncryptionConfigManager {
  private config: EncryptionConfig | null = null;
  private detectionEnabled: boolean = true;

  /**
   * Enable or disable hardware detection (useful for testing)
   */
  setDetectionEnabled(enabled: boolean): void {
    this.detectionEnabled = enabled;
    if (!enabled) {
      // Reset config when detection is disabled
      this.config = null;
    }
  }

  /**
   * Set encryption configuration directly (for testing)
   */
  setConfig(config: EncryptionConfig): void {
    this.config = config;
  }

  /**
   * Get encryption configuration
   */
  getConfig(): EncryptionConfig {
    if (this.config) {
      return this.config;
    }

    if (!this.detectionEnabled) {
      // Return default config when detection is disabled
      return {
        hardwareAccelerated: false,
        preferredAlgorithm: 'aes-256-gcm',
        detected: false,
      };
    }

    // Detect hardware acceleration
    this.config = this.detectHardwareAcceleration();
    return this.config;
  }

  /**
   * Reset configuration (useful for testing)
   */
  reset(): void {
    this.config = null;
  }

  /**
   * Detect hardware acceleration capabilities
   */
  private detectHardwareAcceleration(): EncryptionConfig {
    try {
      // Test encryption speed to detect hardware acceleration
      const testData = Buffer.alloc(1024, 'test');
      const key = crypto.randomBytes(32);
      const iv = crypto.randomBytes(16);

      const startTime = process.hrtime.bigint();

      // Try hardware-accelerated algorithm (GCM mode typically uses AES-NI)
      const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
      cipher.update(testData);
      cipher.final();

      const endTime = process.hrtime.bigint();
      const durationMs = Number(endTime - startTime) / 1_000_000;

      // If encryption is very fast (< 1ms for 1KB), likely hardware-accelerated
      const likelyHardwareAccelerated = durationMs < 1.0;
      const preferredAlgorithm = 'aes-256-gcm';

      const config: EncryptionConfig = {
        hardwareAccelerated: likelyHardwareAccelerated,
        preferredAlgorithm,
        detected: true,
        testDurationMs: durationMs,
      };

      if (likelyHardwareAccelerated) {
        logInfo('Hardware-accelerated encryption detected (AES-NI)', {
          algorithm: preferredAlgorithm,
          testDuration: `${durationMs.toFixed(3)}ms`,
        });
      } else {
        logWarning('Hardware acceleration not detected, using software encryption', {
          algorithm: preferredAlgorithm,
          testDuration: `${durationMs.toFixed(3)}ms`,
        });
      }

      return config;
    } catch (error: any) {
      logWarning('Failed to detect hardware acceleration', error);
      return {
        hardwareAccelerated: false,
        preferredAlgorithm: 'aes-256-gcm',
        detected: false,
      };
    }
  }
}

// Singleton instance
const encryptionConfigManager = new EncryptionConfigManager();

/**
 * Get encryption configuration
 */
export function getEncryptionConfig(): EncryptionConfig {
  return encryptionConfigManager.getConfig();
}

/**
 * Set encryption configuration (for testing)
 */
export function setEncryptionConfig(config: EncryptionConfig): void {
  encryptionConfigManager.setConfig(config);
}

/**
 * Reset encryption configuration (for testing)
 */
export function resetEncryptionConfig(): void {
  encryptionConfigManager.reset();
}

/**
 * Enable/disable hardware detection (for testing)
 */
export function setHardwareDetectionEnabled(enabled: boolean): void {
  encryptionConfigManager.setDetectionEnabled(enabled);
}

/**
 * Get optimal encryption algorithm
 */
export function getOptimalEncryptionAlgorithm(): string {
  return getEncryptionConfig().preferredAlgorithm;
}

/**
 * Check if hardware acceleration is available
 */
export function isHardwareAccelerated(): boolean {
  return getEncryptionConfig().hardwareAccelerated;
}
