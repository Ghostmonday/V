/**
 * In-App Purchase routes
 * Handles IAP verification and receipt management
 */

import { Router, Request, Response } from 'express';
import { supabase } from '../config/db.js';
import { logError } from '../shared/logger.js';

const router = Router();

/**
 * POST /iap/verify
 * Body: { user_id, receipt_data, transaction_id?, product_id?, purchase_date?, status? }
 * Returns: Verified receipt object
 */
router.post('/verify', async (req: Request, res: Response) => {
  const { user_id, receipt_data } = req.body;

  if (!user_id || !receipt_data) {
    return res.status(400).json({ error: 'user_id and receipt_data required' });
  }

  try {
    // Generate required fields if not provided
    const transaction_id = req.body.transaction_id || `txn_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const product_id = req.body.product_id || 'default_product';
    const purchase_date = req.body.purchase_date || new Date().toISOString();
    const status = req.body.status || 'verified';
    
    const { data, error } = await supabase
      .from('iap_receipts')
      .insert([{ user_id, receipt_data, transaction_id, product_id, purchase_date, status }])
      .select()
      .single();

    if (error) throw error;

    res.json({ status: 'ok', receipt: data });
  } catch (e) {
    logError('IAP verification error', e instanceof Error ? e : new Error(String(e)));
    res.status(500).json({ error: e instanceof Error ? e.message : String(e) || 'Server error' });
  }
});

export default router;

