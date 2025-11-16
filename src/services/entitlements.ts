/**
 * Entitlements Service
 * Manages user subscription entitlements and syncs with Supabase
 */

import { supabase } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';
import { logTelemetryEvent } from './telemetry-service.js';
import type { AuthenticatedRequest } from '../types/auth.types.js';

/**
 * Get user entitlements from monetization_subscriptions table
 */
export async function getEntitlements(userId: string): Promise<Record<string, any>> {
  try {
    const { data, error } = await supabase
      .from('monetization_subscriptions')
      .select('entitlements, plan, status')
      .eq('user_id', userId)
      .eq('status', 'active')
      .single();

    if (error) {
      // No subscription found is not an error
      if (error.code === 'PGRST116') {
        return {};
      }
      throw error;
    }

    return data?.entitlements || {};
  } catch (error) {
    logError('Failed to get entitlements', error instanceof Error ? error : new Error(String(error)));
    return {};
  }
}

/**
 * Update subscription in monetization_subscriptions table
 */
export async function updateSubscription(
  userId: string,
  plan: string,
  status: string,
  renewalDate?: Date,
  entitlements?: Record<string, any>,
  transactionId?: string,
  productId?: string
): Promise<void> {
  try {
    const updateData: any = {
      user_id: userId,
      plan,
      status,
      updated_at: new Date().toISOString(),
    };

    if (renewalDate) {
      updateData.renewal_date = renewalDate.toISOString();
    }

    if (entitlements) {
      updateData.entitlements = entitlements;
    }

    if (transactionId) {
      updateData.transaction_id = transactionId;
    }

    if (productId) {
      updateData.product_id = productId;
    }

    const { error } = await supabase
      .from('monetization_subscriptions')
      .upsert(updateData, {
        onConflict: 'user_id',
      });

    if (error) {
      throw error;
    }

    logInfo(`Updated subscription for user ${userId}: ${plan} - ${status}`);
    
    // Log telemetry event
    await logTelemetryEvent('subscription_updated', {
      userId,
      plan,
      status,
      transactionId,
      productId,
    }).catch(() => {
      // Don't fail if telemetry fails
    });
  } catch (error) {
    logError('Failed to update subscription', error instanceof Error ? error : new Error(String(error)));
    throw error;
  }
}

/**
 * Check if user has specific entitlement
 */
export async function hasEntitlement(userId: string, productId: string): Promise<boolean> {
  try {
    const entitlements = await getEntitlements(userId);
    
    // Check if productId is in entitlements JSONB
    if (entitlements && typeof entitlements === 'object') {
      return productId in entitlements || entitlements[productId] === true;
    }

    // Also check plan-based entitlement
    const { data } = await supabase
      .from('monetization_subscriptions')
      .select('plan, product_id')
      .eq('user_id', userId)
      .eq('status', 'active')
      .single();

    if (data) {
      // Check if productId matches
      if (data.product_id === productId) {
        return true;
      }
      
      // Check plan-based mapping
      if (productId === 'pro_monthly' || productId === 'pro_annual') {
        return data.plan === 'pro_monthly' || data.plan === 'pro_annual' || data.plan === 'professional';
      }
    }

    return false;
  } catch (error) {
    logError('Failed to check entitlement', error instanceof Error ? error : new Error(String(error)));
    return false;
  }
}

