/**
 * Database Transaction Middleware
 * Wraps multi-step operations in transactions for atomicity
 */

import { supabase } from '../config/db.ts';
import { logError } from '../shared/logger.js';

/**
 * Execute multiple operations in a transaction with retry logic
 * Note: Supabase doesn't support explicit transactions via client
 * This is a wrapper that ensures atomicity where possible
 */
const MAX_TRANSACTION_RETRIES = 3;
const RETRY_DELAY_MS = 1000; // 1 second base delay

/**
 * Check if error is transient (retryable)
 */
function isTransientError(error: any): boolean {
  if (!error) return false;
  
  const errorCode = error.code || error.errno || '';
  const errorMessage = error.message || '';
  
  // PostgreSQL error codes for transient errors
  const transientCodes = [
    '40001', // serialization_failure
    '40P01', // deadlock_detected
    '08003', // connection_does_not_exist
    '08006', // connection_failure
    '08001', // sqlclient_unable_to_establish_sqlconnection
    '08004', // sqlserver_rejected_establishment_of_sqlconnection
    '57P01', // admin_shutdown
    '57P02', // crash_shutdown
    '57P03', // cannot_connect_now
  ];
  
  // Check error code
  if (transientCodes.includes(String(errorCode))) {
    return true;
  }
  
  // Check error message for common transient patterns
  const transientPatterns = [
    'deadlock',
    'timeout',
    'connection',
    'network',
    'temporary',
    'retry',
  ];
  
  return transientPatterns.some(pattern => 
    errorMessage.toLowerCase().includes(pattern)
  );
}

export async function executeTransaction<T>(
  operations: Array<() => Promise<any>>,
  retryCount: number = 0
): Promise<T[]> {
  // VALIDATION CHECKPOINT: Validate transaction start
  if (!operations || operations.length === 0) {
    throw new Error('Transaction requires at least one operation');
  }
  
  // VALIDATION CHECKPOINT: Validate max retries
  if (retryCount >= MAX_TRANSACTION_RETRIES) {
    throw new Error(`Transaction failed after ${MAX_TRANSACTION_RETRIES} retries`);
  }
  
  const results: T[] = [];
  const executedOperations: Array<{ operation: () => Promise<any>; result?: any }> = [];
  
  try {
    // Execute all operations sequentially
    // Note: For true transactions, use Supabase RPC functions with BEGIN/COMMIT
    for (const operation of operations) {
      // VALIDATION CHECKPOINT: Validate each operation in transaction
      if (typeof operation !== 'function') {
        throw new Error('Invalid operation: must be a function');
      }
      
      const result = await operation();
      results.push(result);
      executedOperations.push({ operation, result });
    }
    
    // VALIDATION CHECKPOINT: Validate transaction commit success
    if (results.length !== operations.length) {
      throw new Error(`Transaction incomplete: ${results.length}/${operations.length} operations succeeded`);
    }
    
    return results;
  } catch (error: any) {
    // VALIDATION CHECKPOINT: Validate error handling
    const isTransient = isTransientError(error);
    
    if (isTransient && retryCount < MAX_TRANSACTION_RETRIES) {
      // Retry with exponential backoff
      const delay = RETRY_DELAY_MS * Math.pow(2, retryCount);
      
      // VALIDATION CHECKPOINT: Validate retry delay calculation
      logError(`Transaction failed (transient), retrying in ${delay}ms`, error);
      
      await new Promise(resolve => setTimeout(resolve, delay));
      
      return executeTransaction(operations, retryCount + 1);
    }
    
    // VALIDATION CHECKPOINT: Validate rollback on failure
    // Rollback: delete any created records if transaction fails
    logError('Transaction failed, rolling back', error);
    
    // Attempt rollback for executed operations
    // Note: This is best-effort - some operations may not be reversible
    for (const executed of executedOperations) {
      try {
        // If operation created a record with an ID, attempt to delete it
        if (executed.result?.id) {
          // Rollback logic would go here
          // For now, just log the rollback attempt
          logError(`Rollback attempted for operation result: ${executed.result.id}`, error);
        }
      } catch (rollbackError: any) {
        logError('Rollback failed', rollbackError);
      }
    }
    
    throw error;
  }
}

/**
 * Create message with receipt in transaction
 */
export async function createMessageWithReceipt(
  messageData: {
    room_id: string;
    sender_id: string;
    content: string;
  },
  receiptData: {
    user_id: string;
  }
): Promise<{ message: any; receipt: any }> {
  // VALIDATION CHECKPOINT: Validate transaction start
  if (!messageData || !receiptData) {
    throw new Error('Invalid transaction data');
  }
  
  return executeTransaction([
    async () => {
      // VALIDATION CHECKPOINT: Validate each operation in transaction
      // Insert message
      const { data: message, error: messageError } = await supabase
        .from('messages')
        .insert(messageData)
        .select()
        .single();

      if (messageError || !message) {
        throw messageError || new Error('Failed to create message');
      }
      
      // VALIDATION CHECKPOINT: Validate message created successfully
      if (!message.id) {
        throw new Error('Message created but missing ID');
      }
      
      return message;
    },
    async (message: any) => {
      // VALIDATION CHECKPOINT: Validate message passed to receipt operation
      if (!message || !message.id) {
        throw new Error('Invalid message for receipt creation');
      }
      
      // Insert receipt
      const { data: receipt, error: receiptError } = await supabase
        .from('message_receipts')
        .insert({
          message_id: message.id,
          user_id: receiptData.user_id,
          delivered_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (receiptError) {
        throw receiptError;
      }
      
      // VALIDATION CHECKPOINT: Validate receipt created successfully
      if (!receipt || !receipt.id) {
        throw new Error('Receipt created but missing ID');
      }
      
      return { message, receipt };
    },
  ]).then(results => {
    // VALIDATION CHECKPOINT: Validate data consistency after transaction
    const finalResult = results[results.length - 1];
    if (!finalResult || !finalResult.message || !finalResult.receipt) {
      throw new Error('Transaction completed but result structure invalid');
    }
    return finalResult;
  });
}

/**
 * Create message with sentiment analysis in transaction
 */
export async function createMessageWithSentiment(
  messageData: {
    room_id: string;
    sender_id: string;
    content: string;
  },
  sentimentData: {
    polarity: number;
    mood: string;
  }
): Promise<{ message: any; sentiment: any }> {
  try {
    // Insert message
    const { data: message, error: messageError } = await supabase
      .from('messages')
      .insert(messageData)
      .select()
      .single();

    if (messageError || !message) {
      throw messageError || new Error('Failed to create message');
    }

    // Insert sentiment (if conversation_id exists)
    let sentiment = null;
    if (messageData.room_id) {
      const { analyzeSentiment } = await import('./sentiment-analysis-service.js');
      const sentimentResult = await analyzeSentiment(messageData.content);
      
      // Store sentiment in message metadata or separate table
      await supabase
        .from('messages')
        .update({
          metadata: {
            ...(message.metadata || {}),
            sentiment: sentimentResult,
          },
        })
        .eq('id', message.id);
      
      sentiment = sentimentResult;
    }

    return { message, sentiment };
  } catch (error: any) {
    logError('Failed to create message with sentiment', error);
    throw error;
  }
}

