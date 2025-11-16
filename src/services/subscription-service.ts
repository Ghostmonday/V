/**
 * Module: subscription-service
 * Purpose: Manage user subscription tiers, enforce limits, and sync with iOS StoreKit purchases.
 * Related: [FEATURE: Paywalls] [DB] [API] [GATE] [SEC]
 * Public APIs: getUserSubscription(), getSubscriptionLimits(), updateSubscription()
 * Events: [EVENT] subscription_updated (via updateSubscription)
 * DB/State: table:users, column:subscription (enum: free|pro|team)
 * Gates: [GATE] unit:subscription-service.test.ts; integration:IAP flow; tier enforcement
 * Owner: [OWNER:backend]
 */

import { findOne, updateOne } from '../shared/supabase-helpers.js';
import { logError } from '../shared/logger.js';

export enum SubscriptionTier {
  FREE = 'free',
  PRO = 'pro',
  TEAM = 'team'
}

export interface SubscriptionLimits {
  aiMessages: number; // -1 = unlimited
  maxRooms: number; // -1 = unlimited
  storageMB: number;
  voiceCallMinutes: number; // -1 = unlimited
}

const TIER_LIMITS: Record<SubscriptionTier, SubscriptionLimits> = {
  [SubscriptionTier.FREE]: {
    aiMessages: 10,
    maxRooms: 5,
    storageMB: 100,
    voiceCallMinutes: 30
  },
  [SubscriptionTier.PRO]: {
    aiMessages: -1,
    maxRooms: -1,
    storageMB: 10240, // 10GB
    voiceCallMinutes: -1
  },
  [SubscriptionTier.TEAM]: {
    aiMessages: -1,
    maxRooms: -1,
    storageMB: 102400, // 100GB
    voiceCallMinutes: -1
  }
};

// [FEATURE: Paywalls] [DB] [GATE]
// PURPOSE: Get user's current subscription tier from database
// INPUTS: userId (string)
// OUTPUTS: SubscriptionTier enum (defaults to FREE on error)
// GATES: [GATE] unit:test_get_user_subscription; error handling; default fallback
export async function getUserSubscription(userId: string): Promise<SubscriptionTier> {
  try {
    const user = await findOne<{ subscription: string }>('users', { id: userId });
    if (!user) return SubscriptionTier.FREE;
    
    const tier = user.subscription as SubscriptionTier;
    return Object.values(SubscriptionTier).includes(tier) ? tier : SubscriptionTier.FREE;
  } catch (error) {
    logError('Failed to get user subscription', error instanceof Error ? error : new Error(String(error)));
    return SubscriptionTier.FREE;
  }
}

// [FEATURE: Paywalls] [GATE]
// PURPOSE: Get subscription limits for a user based on their tier
// INPUTS: userId (string)
// OUTPUTS: SubscriptionLimits object with aiMessages, maxRooms, storageMB, voiceCallMinutes
// GATES: [GATE] unit:test_get_subscription_limits; tier mapping validation
export async function getSubscriptionLimits(userId: string): Promise<SubscriptionLimits> {
  const tier = await getUserSubscription(userId);
  return TIER_LIMITS[tier];
}

// [FEATURE: Paywalls] [DB] [EVENT] [SEC] [GATE]
// PURPOSE: Update user subscription tier in database (called after IAP verification)
// INPUTS: userId (string), tier (SubscriptionTier)
// OUTPUTS: void (throws on error)
// EMITS: [EVENT] subscription_updated (implicit via DB update)
// GATES: [GATE] unit:test_update_subscription; integration:IAP verification flow; RBAC check
export async function updateSubscription(userId: string, tier: SubscriptionTier): Promise<void> {
  try {
    await updateOne('users', userId, { subscription: tier });
  } catch (error) {
    logError('Failed to update subscription', error instanceof Error ? error : new Error(String(error)));
    throw error;
  }
}

// === GATE CHECKLIST ===
// - Unit tests: subscription-service.test.ts coverage >= 90% [GATE] [RELIAB]
// - Integration: IAP verification → updateSubscription flow [GATE] [FEATURE: Paywalls]
// - Security: RBAC check before updateSubscription (caller responsibility) [SEC] [GATE]
// - Database: users.subscription column validation [DB] [GATE]
// - Error handling: Default to FREE tier on errors [GATE] [RELIAB]
// - Telemetry: subscription_updated event emission [EVENT] [FEATURE: Telemetry]

