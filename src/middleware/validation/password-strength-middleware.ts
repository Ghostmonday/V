/**
 * Password Strength Validation
 * Enforces password strength requirements
 *
 * Requirements:
 * - Minimum 8 characters
 * - Maximum 500 characters (bcrypt limit)
 * - At least one uppercase letter
 * - At least one lowercase letter
 * - At least one number
 * - At least one special character
 */

import { z } from 'zod';
import { validateServiceData } from './incremental-validation.js';
import { logWarning } from '../../shared/logger.js';

// Password strength schema
const passwordStrengthSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(500, 'Password must be at most 500 characters')
  .refine((pwd) => /[A-Z]/.test(pwd), 'Password must contain at least one uppercase letter')
  .refine((pwd) => /[a-z]/.test(pwd), 'Password must contain at least one lowercase letter')
  .refine((pwd) => /[0-9]/.test(pwd), 'Password must contain at least one number')
  .refine(
    (pwd) => /[^A-Za-z0-9]/.test(pwd),
    'Password must contain at least one special character'
  );

export interface PasswordStrengthResult {
  valid: boolean;
  score: number; // 0-4 (number of requirements met)
  requirements: {
    minLength: boolean;
    maxLength: boolean;
    hasUppercase: boolean;
    hasLowercase: boolean;
    hasNumber: boolean;
    hasSpecial: boolean;
  };
  errors: string[];
}

/**
 * Validate password strength
 */
export function validatePasswordStrength(password: string): PasswordStrengthResult {
  // VALIDATION CHECKPOINT: Validate password is string
  if (typeof password !== 'string') {
    return {
      valid: false,
      score: 0,
      requirements: {
        minLength: false,
        maxLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasNumber: false,
        hasSpecial: false,
      },
      errors: ['Password must be a string'],
    };
  }

  const requirements = {
    minLength: password.length >= 8,
    maxLength: password.length <= 500,
    hasUppercase: /[A-Z]/.test(password),
    hasLowercase: /[a-z]/.test(password),
    hasNumber: /[0-9]/.test(password),
    hasSpecial: /[^A-Za-z0-9]/.test(password),
  };

  const score = Object.values(requirements).filter(Boolean).length;
  const valid = score === 6; // All 6 requirements met

  const errors: string[] = [];
  if (!requirements.minLength) errors.push('Password must be at least 8 characters');
  if (!requirements.maxLength) errors.push('Password must be at most 500 characters');
  if (!requirements.hasUppercase)
    errors.push('Password must contain at least one uppercase letter');
  if (!requirements.hasLowercase)
    errors.push('Password must contain at least one lowercase letter');
  if (!requirements.hasNumber) errors.push('Password must contain at least one number');
  if (!requirements.hasSpecial) errors.push('Password must contain at least one special character');

  // VALIDATION CHECKPOINT: Validate password strength result structure
  return {
    valid,
    score,
    requirements,
    errors,
  };
}

/**
 * Validate password with Zod schema (throws on invalid)
 */
export function validatePassword(password: string): string {
  try {
    // VALIDATION CHECKPOINT: Validate password against schema
    return validateServiceData(password, passwordStrengthSchema, 'validatePassword');
  } catch (error: any) {
    // Get detailed errors from strength check
    const strength = validatePasswordStrength(password);
    throw new Error(strength.errors.join(', '));
  }
}

/**
 * Check if password is common/weak (basic check)
 */
export function isCommonPassword(password: string): boolean {
  const commonPasswords = [
    'password',
    '12345678',
    'password123',
    'admin123',
    'letmein',
    'welcome',
    'monkey',
    '1234567890',
    'qwerty',
    'abc123',
  ];

  const lowerPassword = password.toLowerCase();
  return commonPasswords.some((common) => lowerPassword.includes(common));
}

/**
 * Calculate password entropy (bits)
 */
export function calculatePasswordEntropy(password: string): number {
  let charsetSize = 0;

  if (/[a-z]/.test(password)) charsetSize += 26;
  if (/[A-Z]/.test(password)) charsetSize += 26;
  if (/[0-9]/.test(password)) charsetSize += 10;
  if (/[^A-Za-z0-9]/.test(password)) charsetSize += 32; // Common special chars

  if (charsetSize === 0) return 0;

  return Math.log2(Math.pow(charsetSize, password.length));
}

/**
 * Get password strength rating
 */
export function getPasswordStrength(
  password: string
): 'weak' | 'medium' | 'strong' | 'very-strong' {
  const strength = validatePasswordStrength(password);
  const entropy = calculatePasswordEntropy(password);

  if (!strength.valid || entropy < 40) return 'weak';
  if (entropy < 60) return 'medium';
  if (entropy < 80) return 'strong';
  return 'very-strong';
}
