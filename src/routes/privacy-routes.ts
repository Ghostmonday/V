/**
 * Privacy Routes
 * Zero-knowledge proofs and selective disclosure endpoints
 */

import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';
import { supabase } from '../config/db.ts';
import { logError, logInfo } from '../shared/logger.js';
import {
  generateSelectiveDisclosure,
  verifySelectiveDisclosure,
  storeProofCommitments,
  AttributeType,
} from '../services/zkp-service.js';
import { z } from 'zod';

const router = Router();

// Schema for selective disclosure request
const disclosureRequestSchema = z.object({
  attributeTypes: z.array(z.enum(['age', 'verified', 'subscription_tier', 'location_country', 'custom'])),
  purpose: z.string().optional(),
});

/**
 * POST /api/privacy/selective-disclosure
 * Generate zero-knowledge proofs for selective disclosure
 */
router.post('/selective-disclosure', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const validated = disclosureRequestSchema.safeParse(req.body);
    if (!validated.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validated.error.errors,
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
    const disclosureProof = await generateSelectiveDisclosure(
      userId,
      attributes,
      {
        attributeTypes,
        purpose,
        verifierId: req.body.verifierId,
      }
    );

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
});

/**
 * POST /api/privacy/verify-disclosure
 * Verify a selective disclosure proof
 */
router.post('/verify-disclosure', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { disclosureProof, expectedCommitments } = req.body;

    if (!disclosureProof || !expectedCommitments) {
      return res.status(400).json({
        success: false,
        error: 'Missing disclosureProof or expectedCommitments',
      });
    }

    // Verify the disclosure proof
    const isValid = await verifySelectiveDisclosure(disclosureProof, expectedCommitments);

    res.json({
      success: true,
      valid: isValid,
      verifiedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    logError('Failed to verify selective disclosure', error);
    res.status(500).json({
      success: false,
      error: 'Failed to verify selective disclosure proof',
    });
  }
});

/**
 * GET /api/privacy/encryption-status
 * Get encryption capabilities (hardware acceleration status)
 */
router.get('/encryption-status', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { getOptimalEncryptionAlgorithm, detectHardwareAcceleration, benchmarkEncryption } = await import('../services/hardware-accelerated-encryption.js');
    
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
      },
    });
  } catch (error: any) {
    logError('Failed to get encryption status', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get encryption status',
    });
  }
});

/**
 * GET /api/privacy/zkp/commitments/:userId
 * Get stored proof commitments for a user (for verification)
 */
router.get('/zkp/commitments/:userId', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { userId } = req.params;
    const requestingUserId = req.user?.userId;
    
    // Users can only view their own commitments
    if (requestingUserId !== userId) {
      return res.status(403).json({ error: 'Forbidden: Cannot view other users\' commitments' });
    }
    
    const { data: commitments, error } = await supabase
      .from('user_zkp_commitments')
      .select('id, attribute_type, commitment, created_at, expires_at, revoked_at')
      .eq('user_id', userId)
      .is('revoked_at', null) // Only active commitments
      .order('created_at', { ascending: false });
    
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
});

export default router;

