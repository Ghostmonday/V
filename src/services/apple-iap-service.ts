/**
 * Apple IAP Verification Service
 * Verifies Apple App Store receipts and updates subscriptions
 */

import https from 'https';
import crypto from 'crypto';
import { updateSubscription, SubscriptionTier } from './subscription-service.js';
import { create, findOne } from '../shared/supabase-helpers.js';
import { logError, logInfo } from '../shared/logger.js';
import { getAppleSharedSecret } from './api-keys-service.js';
import { supabase } from '../config/db.ts';

interface AppleReceiptResponse {
  status: number;
  receipt: {
    in_app: Array<{
      product_id: string;
      transaction_id: string;
      purchase_date_ms: string;
    }>;
  };
}

export async function verifyAppleReceipt(
  receiptData: string,
  userId: string
): Promise<{ verified: boolean; tier?: SubscriptionTier }> {
  // Compute receipt hash for deduplication
  const receiptHash = crypto.createHash('sha256').update(receiptData).digest('hex');

  // Check if receipt was already processed (deduplication)
  try {
    const existing = await findOne('iap_receipts', { receipt_hash: receiptHash });
    if (existing && existing.verified) {
      logInfo(
        'Apple IAP',
        `Duplicate receipt detected for user ${userId}, returning cached result`
      );
      return {
        verified: true,
        tier: existing.product_id === 'com.vibez.pro.monthly' ? SubscriptionTier.PRO : undefined,
      };
    }
  } catch (dedupeError) {
    // If receipt_hash column doesn't exist yet, continue processing
    logInfo(
      'Apple IAP',
      'Receipt hash check failed (column may not exist), proceeding with verification'
    );
  }

  const isProduction = process.env.NODE_ENV === 'production';
  const verifyURL = isProduction
    ? 'https://buy.itunes.apple.com/verifyReceipt'
    : 'https://sandbox.itunes.apple.com/verifyReceipt';

  // Get Apple Shared Secret from vault
  const appleSharedSecret = await getAppleSharedSecret();

  const payload = JSON.stringify({
    'receipt-data': receiptData,
    password: appleSharedSecret,
    'exclude-old-transactions': true,
  });

  return new Promise((resolve) => {
    const req = https.request(
      verifyURL,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', async () => {
          try {
            const result: AppleReceiptResponse = JSON.parse(data);

            if (result.status === 0) {
              // Valid receipt
              const productId = result.receipt.in_app[0]?.product_id;

              if (productId === 'com.vibez.pro.monthly') {
                // Update subscription
                await updateSubscription(userId, SubscriptionTier.PRO);

                // Store receipt with hash for deduplication
                await create('iap_receipts', {
                  user_id: userId,
                  receipt_data: receiptData,
                  receipt_hash: receiptHash, // Store hash for duplicate detection
                  verified: true,
                  transaction_id: result.receipt.in_app[0].transaction_id,
                  product_id: productId,
                });

                logInfo('Apple IAP', `Subscription verified for user ${userId}`);
                resolve({ verified: true, tier: SubscriptionTier.PRO });
              } else {
                resolve({ verified: false });
              }
            } else if (result.status === 21007) {
              // Sandbox receipt sent to production - retry with sandbox
              logInfo('Apple IAP', 'Retrying with sandbox URL');
              const sandboxResult = await verifyAppleReceipt(receiptData, userId);
              resolve(sandboxResult);
            } else {
              logError('Apple IAP', `Verification failed with status ${result.status}`);
              resolve({ verified: false });
            }
          } catch (error) {
            logError(
              'Apple IAP',
              `Parse error: ${error instanceof Error ? error.message : String(error)}`
            );
            resolve({ verified: false });
          }
        });
      }
    );

    req.on('error', (error) => {
      logError('Apple IAP', `Request error: ${error.message}`);
      resolve({ verified: false });
    });

    req.write(payload);
    req.end();
  });
}
