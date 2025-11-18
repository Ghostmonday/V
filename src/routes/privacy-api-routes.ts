/**
 * Privacy Routes
 * Zero-knowledge proofs and selective disclosure endpoints
 */

import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth/supabase-auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { supabase } from '../config/db.ts';
import { logError, logInfo } from '../shared/logger.js';
import {
  generateSelectiveDisclosure,
  verifySelectiveDisclosure,
  storeProofCommitments,
  AttributeType,
} from '../services/zkp-service.js';
import {
  sanitizedDisclosureRequestSchema,
  sanitizedVerifyDisclosureSchema,
  sanitizedBatchedVerifyDisclosureSchema,
  sanitizeUUID,
} from '../utils/input-sanitizer.js';
import { verifyBatchedSelectiveDisclosure } from '../services/zkp-service.js';
import { rateLimit } from '../middleware/rate-limiting/rate-limiter.js';

const router = Router();

// Rate limiting for disclosure APIs (prevent abuse)
const disclosureRateLimit = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // 10 requests per minute
  message: 'Too many disclosure requests, please try again later',
});

/**
 * POST /api/privacy/selective-disclosure
 * Generate zero-knowledge proofs for selective disclosure
 * Protected by rate limiting and input sanitization
 */
router.post(
  '/selective-disclosure',
  authMiddleware,
  disclosureRateLimit,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const userId = req.user?.userId;
      if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      // Sanitize and validate input (prevents injection attacks)
      const validated = sanitizedDisclosureRequestSchema.safeParse(req.body);
      if (!validated.success) {
        return res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: validated.error.errors,
        });
      }

      // Sanitize verifierId if provided
      const verifierId = req.body.verifierId ? sanitizeUUID(req.body.verifierId) : undefined;
      if (req.body.verifierId && !verifierId) {
        return res.status(400).json({
          success: false,
          error: 'Invalid verifierId format',
        });
      }

      const { attributeTypes, purpose } = validated.data;

      // Get user attributes from database
      const { data: user, error: userError } = await supabase
        .from('users')
        .select('id, is_verified, metadata')
        .eq('id', userId)
        .single();

      if (userError || !user) {
        return res.status(404).json({ error: 'User not found' });
      }

      // Extract attributes
      const attributes: Record<AttributeType, string | number | boolean> = {
        verified: user.is_verified || false,
        subscription_tier: user.metadata?.subscription_tier || 'free',
        age: user.metadata?.age || 0,
        location_country: user.metadata?.location_country || '',
        custom: user.metadata?.custom_attributes || '',
      };

      // Generate selective disclosure proofs
      const disclosureProof = await generateSelectiveDisclosure(userId, attributes, {
        attributeTypes,
        purpose,
        verifierId,
      });

      // Store proof commitments for later verification
      await storeProofCommitments(userId, disclosureProof.proofs);

      res.json({
        success: true,
        disclosureProof,
      });
    } catch (error: any) {
      logError('Failed to generate selective disclosure', error);
      res.status(500).json({
        success: false,
        error: 'Failed to generate selective disclosure proofs',
      });
    }
  }
);

/**
 * POST /api/privacy/verify-disclosure
 * Verify a selective disclosure proof (single or batched)
 * Protected by rate limiting and input sanitization
 *
 * Supports both single proof and batched verification for efficiency
 */
router.post(
  '/verify-disclosure',
  authMiddleware,
  disclosureRateLimit,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      // Check if this is a batched request
      if (req.body.disclosureProofs && Array.isArray(req.body.disclosureProofs)) {
        // Batched verification
        const validated = sanitizedBatchedVerifyDisclosureSchema.safeParse(req.body);
        if (!validated.success) {
          return res.status(400).json({
            success: false,
            error: 'Invalid batched request body',
            details: validated.error.errors,
          });
        }

        const { disclosureProofs, expectedCommitmentsMap } = validated.data;

        // Convert string keys to numbers for expectedCommitmentsMap
        const commitmentsMap: Record<number, Record<string, string>> = {};
        for (const [key, value] of Object.entries(expectedCommitmentsMap)) {
          const index = parseInt(key, 10);
          if (!isNaN(index)) {
            commitmentsMap[index] = value;
          }
        }

        // Verify batched proofs
        const results = await verifyBatchedSelectiveDisclosure(disclosureProofs, commitmentsMap);

        const allValid = results.every((r) => r.valid);
        const validCount = results.filter((r) => r.valid).length;

        res.json({
          success: true,
          batched: true,
          allValid,
          validCount,
          totalCount: results.length,
          results,
          verifiedAt: new Date().toISOString(),
        });
      } else {
        // Single proof verification
        const validated = sanitizedVerifyDisclosureSchema.safeParse(req.body);
        if (!validated.success) {
          return res.status(400).json({
            success: false,
            error: 'Invalid request body',
            details: validated.error.errors,
          });
        }

        const { disclosureProof, expectedCommitments } = validated.data;

        // Verify the disclosure proof
        const isValid = await verifySelectiveDisclosure(disclosureProof, expectedCommitments);

        res.json({
          success: true,
          batched: false,
          valid: isValid,
          verifiedAt: new Date().toISOString(),
        });
      }
    } catch (error: any) {
      logError('Failed to verify selective disclosure', error);
      res.status(500).json({
        success: false,
        error: 'Failed to verify selective disclosure proof',
      });
    }
  }
);

/**
 * GET /api/privacy/encryption-status
 * Get encryption capabilities (hardware acceleration status)
 */
router.get(
  '/encryption-status',
  authMiddleware,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { getOptimalEncryptionAlgorithm, detectHardwareAcceleration, benchmarkEncryption } =
        await import('../services/hardware-accelerated-encryption.js');

      const capabilities = detectHardwareAcceleration();
      const algorithm = getOptimalEncryptionAlgorithm();

      // Run quick benchmark
      const benchmark = await benchmarkEncryption(1024 * 1024); // 1MB test

      res.json({
        success: true,
        hardwareAccelerated: capabilities.hardwareAccelerated,
        algorithm,
        pfsEnabled: true, // Perfect Forward Secrecy is enabled
        mediaStreamEncryption: {
          algorithm: 'aes-256-gcm',
          hardwareAccelerated: capabilities.hardwareAccelerated,
        },
        benchmark: {
          throughputMBps: benchmark.throughputMBps,
          durationMs: benchmark.durationMs,
          fallbackAvailable: benchmark.fallbackAvailable,
        },
        // Include fallback alert flag for UI
        fallbackAlert: !capabilities.hardwareAccelerated
          ? {
              message: 'Hardware acceleration unavailable - using software encryption',
              severity: 'warning',
            }
          : undefined,
      });
    } catch (error: any) {
      logError('Failed to get encryption status', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get encryption status',
      });
    }
  }
);

/**
 * GET /api/privacy/zkp/commitments/:userId
 * Get stored proof commitments for a user (for verification)
 */
router.get(
  '/zkp/commitments/:userId',
  authMiddleware,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      // Sanitize userId from params (prevents injection)
      const userId = sanitizeUUID(req.params.userId);
      if (!userId) {
        return res.status(400).json({ error: 'Invalid userId format' });
      }

      const requestingUserId = req.user?.userId;

      // Users can only view their own commitments
      if (requestingUserId !== userId) {
        return res.status(403).json({ error: "Forbidden: Cannot view other users' commitments" });
      }

      // Optimized query with proper indexing (user_id + revoked_at + created_at)
      const { data: commitments, error } = await supabase
        .from('user_zkp_commitments')
        .select('id, attribute_type, commitment, created_at, expires_at, revoked_at')
        .eq('user_id', userId)
        .is('revoked_at', null) // Only active commitments (uses index)
        .order('created_at', { ascending: false })
        .limit(100); // Limit results for performance

      if (error) {
        logError('Failed to fetch ZKP commitments', error);
        return res.status(500).json({ error: 'Failed to fetch commitments' });
      }

      res.json({
        success: true,
        commitments: commitments || [],
        count: commitments?.length || 0,
      });
    } catch (error: any) {
      logError('Failed to get ZKP commitments', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get ZKP commitments',
      });
    }
  }
);

export default router;
