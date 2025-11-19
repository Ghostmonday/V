/**
 * Input Sanitization Utilities
 * Prevents injection attacks and validates input for ZKP endpoints
 */

import { z } from 'zod/v3';

/**
 * Sanitize string input - removes potentially dangerous characters
 */
export function sanitizeString(input: string, maxLength: number = 255): string {
  if (typeof input !== 'string') {
    return '';
  }

  // Remove null bytes, control characters, and trim whitespace
  let sanitized = input
    .replace(/\0/g, '') // Remove null bytes
    .replace(/[\x00-\x1F\x7F]/g, '') // Remove control characters
    .trim();

  // Limit length
  if (sanitized.length > maxLength) {
    sanitized = sanitized.substring(0, maxLength);
  }

  return sanitized;
}

/**
 * Sanitize UUID - validates and sanitizes UUID format
 */
export function sanitizeUUID(input: string): string | null {
  if (typeof input !== 'string') {
    return null;
  }

  // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const sanitized = input.trim().toLowerCase();

  if (!uuidRegex.test(sanitized)) {
    return null;
  }

  return sanitized;
}

/**
 * Sanitize attribute type - validates against allowed values
 */
export function sanitizeAttributeType(input: string): string | null {
  const allowedTypes = ['age', 'verified', 'subscription_tier', 'location_country', 'custom'];
  const sanitized = sanitizeString(input, 50).toLowerCase();

  if (!allowedTypes.includes(sanitized)) {
    return null;
  }

  return sanitized;
}

/**
 * Sanitize commitment hash - validates hex format
 */
export function sanitizeCommitmentHash(input: string): string | null {
  if (typeof input !== 'string') {
    return null;
  }

  // SHA-256 produces 64 hex characters, SHA-3-256 produces 64 hex characters
  const hexRegex = /^[0-9a-f]{64}$/i;
  const sanitized = input.trim().toLowerCase();

  if (!hexRegex.test(sanitized)) {
    return null;
  }

  return sanitized;
}

/**
 * Sanitize purpose string - removes potentially dangerous content
 */
export function sanitizePurpose(input: string): string {
  if (typeof input !== 'string') {
    return '';
  }

  // Remove script tags, SQL injection patterns, and other dangerous content
  let sanitized = input
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '') // Remove script tags
    .replace(/['";\\]/g, '') // Remove SQL injection characters
    .replace(/javascript:/gi, '') // Remove javascript: protocol
    .replace(/on\w+\s*=/gi, '') // Remove event handlers
    .trim();

  // Limit length
  if (sanitized.length > 500) {
    sanitized = sanitized.substring(0, 500);
  }

  return sanitized;
}

/**
 * Schema for selective disclosure request with sanitization
 */
export const sanitizedDisclosureRequestSchema = z
  .object({
    attributeTypes: z
      .array(z.enum(['age', 'verified', 'subscription_tier', 'location_country', 'custom']))
      .min(1)
      .max(10), // Limit number of attributes
    purpose: z
      .string()
      .max(500)
      .optional()
      .transform((val) => (val ? sanitizePurpose(val) : undefined)),
    verifierId: z.string().uuid().optional(),
  })
  .strict(); // Reject unknown fields

/**
 * Schema for verify disclosure request with sanitization
 */
export const sanitizedVerifyDisclosureSchema = z
  .object({
    disclosureProof: z.object({
      proofs: z.array(
        z.object({
          attributeType: z.enum([
            'age',
            'verified',
            'subscription_tier',
            'location_country',
            'custom',
          ]),
          proof: z.string().max(10000), // Base64 encoded proof
          commitment: z.string().regex(/^[0-9a-f]{64}$/i), // SHA-3-256 hash
          timestamp: z.number().int().positive(),
          nonce: z.string().max(100),
        })
      ),
      metadata: z.object({
        userId: z.string().uuid(),
        issuedAt: z.number().int().positive(),
        expiresAt: z.number().int().positive().optional(),
        purpose: z.string().max(500).optional(),
      }),
    }),
    expectedCommitments: z.record(
      z.enum(['age', 'verified', 'subscription_tier', 'location_country', 'custom']),
      z.string().regex(/^[0-9a-f]{64}$/i) // SHA-3-256 hash
    ),
  })
  .strict();

/**
 * Schema for batched verify disclosure request
 */
export const sanitizedBatchedVerifyDisclosureSchema = z
  .object({
    disclosureProofs: z
      .array(
        z.object({
          proofs: z.array(
            z.object({
              attributeType: z.enum([
                'age',
                'verified',
                'subscription_tier',
                'location_country',
                'custom',
              ]),
              proof: z.string().max(10000),
              commitment: z.string().regex(/^[0-9a-f]{64}$/i),
              timestamp: z.number().int().positive(),
              nonce: z.string().max(100),
            })
          ),
          metadata: z.object({
            userId: z.string().uuid(),
            issuedAt: z.number().int().positive(),
            expiresAt: z.number().int().positive().optional(),
            purpose: z.string().max(500).optional(),
          }),
        })
      )
      .min(1)
      .max(100), // Limit batch size to 100
    expectedCommitmentsMap: z.record(
      z.string().regex(/^\d+$/), // Index as string
      z.record(
        z.enum(['age', 'verified', 'subscription_tier', 'location_country', 'custom']),
        z.string().regex(/^[0-9a-f]{64}$/i)
      )
    ),
  })
  .strict();
