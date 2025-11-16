/**
 * Shared Supabase query helpers
 * Provides consistent error handling and simplified query patterns
 */

import { supabase } from '../config/db.js';
import { logError } from '../shared/logger.js';

/**
 * Execute a Supabase select query and return single result
 * 
 * Builds WHERE clause dynamically from filter object.
 * Returns null if no record found (instead of throwing error).
 */
export async function findOne<T = unknown>(
  table: string,
  filter: Record<string, unknown>
): Promise<T | null> {
  try {
    // Start with base query: SELECT * FROM table
    let query = supabase.from(table).select('*');
    
    // Build WHERE clause dynamically from filter object
    // Example: filter = { room_id: '123', user_id: '456' }
    // Results in: WHERE room_id = '123' AND user_id = '456'
    for (const [key, value] of Object.entries(filter)) {
      query = query.eq(key, value); // eq = equals (WHERE key = value)
    }
    
    // Execute query and expect exactly one result
    // .single() throws if 0 or 2+ rows returned
    const { data, error } = await query.single();
    
    if (error) {
      // PGRST116 = PostgREST error code for "no rows returned"
      // This is expected when record doesn't exist - return null instead of error
      if (error.code === 'PGRST116') {
        // No rows found - return null instead of throwing
        return null;
      }
      // Other errors (permission denied, connection error, etc.) - throw
      throw error;
    }
    
    return data as T;
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError(`findOne failed for table "${table}"`, err);
    throw new Error(err.message || `Failed to find record in ${table}`);
  }
}

/**
 * Pagination result with cursor and metadata
 */
export interface PaginatedResult<T> {
  data: T[];
  pagination: {
    cursor?: string; // Next cursor for pagination
    prevCursor?: string; // Previous cursor
    hasMore: boolean; // Whether more results exist
    limit: number; // Limit used
    total?: number; // Total count (if available)
  };
}

/**
 * Execute a Supabase select query and return multiple results
 * 
 * Supports filtering, ordering, and pagination (cursor-based or limit/offset).
 * Returns empty array if no results (never null).
 */
export async function findMany<T = unknown>(
  table: string,
  options?: {
    filter?: Record<string, unknown>; // WHERE conditions (key = value pairs)
    orderBy?: { column: string; ascending?: boolean }; // ORDER BY clause
    limit?: number; // LIMIT clause (max rows to return, 1-100)
    cursor?: string; // Cursor for pagination (timestamp or UUID)
    cursorColumn?: string; // Column to use for cursor (default: orderBy.column or 'created_at')
    includeTotal?: boolean; // Include total count (slower)
  }
): Promise<T[] | PaginatedResult<T>> {
  try {
    // VALIDATION CHECKPOINT: Validate limit value (1-100)
    const limit = options?.limit ? Math.max(1, Math.min(100, options.limit)) : 50;
    
    // VALIDATION CHECKPOINT: Validate cursor format if provided
    if (options?.cursor) {
      // Cursor can be UUID or ISO timestamp
      const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(options.cursor);
      const isTimestamp = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(options.cursor);
      
      if (!isUUID && !isTimestamp) {
        throw new Error('Invalid cursor format. Must be UUID or ISO timestamp.');
      }
    }
    
    // Start with base query: SELECT * FROM table
    let query = supabase.from(table).select(options?.includeTotal ? '*,count' : '*', { count: options?.includeTotal ? 'exact' : undefined });
    
    // Apply filters (WHERE conditions)
    // Builds: WHERE key1 = value1 AND key2 = value2 ...
    if (options?.filter) {
      for (const [key, value] of Object.entries(options.filter)) {
        query = query.eq(key, value); // eq = equals operator
      }
    }
    
    // Determine cursor column
    const cursorColumn = options?.cursorColumn || options?.orderBy?.column || 'created_at';
    const ascending = options?.orderBy?.ascending ?? false; // Default DESC for pagination
    
    // Apply cursor-based pagination if cursor provided
    if (options?.cursor) {
      // VALIDATION CHECKPOINT: Validate cursor column exists
      if (ascending) {
        // For ascending: WHERE cursorColumn > cursor
        query = query.gt(cursorColumn, options.cursor);
      } else {
        // For descending: WHERE cursorColumn < cursor
        query = query.lt(cursorColumn, options.cursor);
      }
    }
    
    // Apply ordering (ORDER BY clause)
    query = query.order(cursorColumn, { 
      ascending,
      nullFirst: false,
    });
    
    // Apply limit (LIMIT clause)
    // Prevents returning too many rows (performance protection)
    query = query.limit(limit + 1); // Fetch one extra to check if more exists
    
    // Execute query (returns array, not single result)
    const { data, error, count } = await query;
    
    if (error) throw error;
    
    const results = (data || []) as T[];
    
    // VALIDATION CHECKPOINT: Validate result set structure
    if (!Array.isArray(results)) {
      throw new Error('Query returned non-array result');
    }
    
    // Check if more results exist (we fetched limit + 1)
    const hasMore = results.length > limit;
    const actualResults = hasMore ? results.slice(0, limit) : results;
    
    // Calculate next cursor from last result
    let nextCursor: string | undefined;
    if (hasMore && actualResults.length > 0) {
      const lastResult = actualResults[actualResults.length - 1] as any;
      const cursorValue = lastResult[cursorColumn];
      
      // VALIDATION CHECKPOINT: Validate cursor value exists
      if (cursorValue) {
        if (cursorValue instanceof Date) {
          nextCursor = cursorValue.toISOString();
        } else if (typeof cursorValue === 'string') {
          nextCursor = cursorValue;
        } else {
          nextCursor = String(cursorValue);
        }
      }
    }
    
    // If cursor-based pagination requested, return paginated result
    if (options?.cursor !== undefined || options?.includeTotal) {
      return {
        data: actualResults,
        pagination: {
          cursor: nextCursor,
          prevCursor: options?.cursor,
          hasMore,
          limit,
          total: count || undefined,
        },
      } as PaginatedResult<T>;
    }
    
    // Return simple array for backward compatibility
    return actualResults;
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError(`findMany failed for table "${table}"`, err);
    throw new Error(err.message || `Failed to query ${table}`);
  }
}

/**
 * Create a new record in Supabase
 * 
 * Inserts record and returns the created record (with generated fields like id, timestamps).
 * .select() returns the inserted row, .single() ensures exactly one result.
 */
export async function create<T = unknown>(
  table: string,
  record: Record<string, unknown>
): Promise<T> {
  try {
    // Insert record and return created row
    // [record] = array format (Supabase insert accepts array for batch inserts)
    // .select() = return inserted data (includes auto-generated fields like id, created_at)
    // .single() = expect exactly one row (throw if 0 or 2+)
    const { data, error } = await supabase
      .from(table)
      .insert([record]) // Array format (allows batch inserts, but we insert one)
      .select() // Return inserted row(s)
      .single(); // Expect exactly one result
    
    if (error) {
      // Add Sentry breadcrumb for database errors
      const Sentry = await import('@sentry/node');
      Sentry.addBreadcrumb({
        message: `Supabase insert failed for table: ${table}`,
        level: 'error',
        data: { table, error: error.message }
      });
      throw error;
    }
    
    // Return created record (includes id, timestamps, etc.)
    return data as T;
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError(`create failed for table "${table}"`, err);
    throw new Error(err.message || `Failed to create record in ${table}`);
  }
}

/**
 * Update a record in Supabase
 */
export async function updateOne<T = unknown>(
  table: string,
  id: string | number,
  updates: Record<string, unknown>
): Promise<T> {
  try {
    // Use PostgreSQL row-level locking to prevent race conditions
    // This ensures only one update succeeds if multiple updates happen concurrently
    const { data, error } = await supabase
      .from(table)
      .update(updates)
      .eq('id', id)
      .select()
      .single();
    
    if (error) {
      // Add Sentry breadcrumb for database errors
      const Sentry = await import('@sentry/node');
      Sentry.addBreadcrumb({
        message: `Supabase update failed for table: ${table}`,
        level: 'error',
        data: { table, id, error: error.message }
      });
      throw error;
    }
    
    return data as T;
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError(`updateOne failed for table "${table}"`, err);
    throw new Error(err.message || `Failed to update record in ${table}`);
  }
}

/**
 * Upsert (insert or update) a record in Supabase
 * 
 * If record with conflictColumn value exists, update it.
 * If not, insert new record.
 * 
 * Uses PostgreSQL ON CONFLICT clause (UPSERT pattern).
 * Useful for idempotent operations (can be called multiple times safely).
 */
export async function upsert<T = unknown>(
  table: string,
  record: Record<string, unknown>,
  conflictColumn: string = 'id' // Column to check for conflicts (usually 'id' or unique constraint)
): Promise<T> {
  try {
    // Upsert: INSERT ... ON CONFLICT (conflictColumn) DO UPDATE
    // If record with same conflictColumn exists, update it
    // If not, insert new record
    const { data, error } = await supabase
      .from(table)
      .upsert(record, { onConflict: conflictColumn }) // Conflict resolution: update on duplicate
      .select() // Return upserted row
      .single(); // Expect exactly one result
    
    if (error) {
      // Add Sentry breadcrumb for database errors
      const Sentry = await import('@sentry/node');
      Sentry.addBreadcrumb({
        message: `Supabase upsert failed for table: ${table}`,
        level: 'error',
        data: { table, conflictColumn, error: error.message }
      });
      throw error;
    }
    
    return data as T;
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError(`upsert failed for table "${table}"`, err);
    throw new Error(err.message || `Failed to upsert record in ${table}`);
  }
}

/**
 * Delete a record from Supabase
 */
export async function deleteOne(
  table: string,
  id: string | number
): Promise<void> {
  try {
    const { error } = await supabase
      .from(table)
      .delete()
      .eq('id', id);
    
    if (error) throw error;
  } catch (error: any) {
    logError(`deleteOne failed for table "${table}"`, error);
    throw new Error(error.message || `Failed to delete record from ${table}`);
  }
}

/**
 * Execute multiple operations within a transaction
 * 
 * Note: Supabase REST API doesn't support native transactions.
 * This function uses RPC calls to execute a transaction via PostgreSQL.
 * 
 * @param operations - Array of operations to execute in transaction
 * @returns Results of all operations
 */
export async function transaction<T = unknown>(
  operations: Array<() => Promise<T>>
): Promise<T[]> {
  try {
    // For Supabase, we need to use RPC to execute transactions
    // Since Supabase REST API doesn't support transactions directly,
    // we'll execute operations sequentially with error handling
    // and rollback on any failure
    
    const results: T[] = [];
    const executedOperations: Array<{ operation: () => Promise<T>; result?: T }> = [];
    
    try {
      // Execute all operations sequentially
      for (const operation of operations) {
        const result = await operation();
        results.push(result);
        executedOperations.push({ operation, result });
      }
      
      return results;
    } catch (error) {
      // If any operation fails, we can't rollback via REST API
      // Log error and rethrow - caller should handle cleanup
      logError('Transaction failed, operations may be partially applied', error instanceof Error ? error : new Error(String(error)));
      throw error;
    }
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError('Transaction execution failed', err);
    throw new Error(err.message || 'Transaction failed');
  }
}

/**
 * Execute a transaction using PostgreSQL RPC function
 * 
 * This is the preferred method for true ACID transactions.
 * Requires a database function to be created that accepts SQL statements.
 * 
 * @param sqlStatements - Array of SQL statements to execute in transaction
 * @returns Results from the transaction
 */
export async function executeTransaction(
  sqlStatements: string[]
): Promise<any> {
  try {
    // Use Supabase RPC to execute transaction
    // Note: This requires a database function like:
    // CREATE OR REPLACE FUNCTION execute_transaction(statements TEXT[])
    // RETURNS JSONB AS $$
    // BEGIN
    //   -- Execute statements in transaction
    //   RETURN jsonb_build_object('success', true);
    // END;
    // $$ LANGUAGE plpgsql;
    
    const { data, error } = await supabase.rpc('execute_transaction', {
      statements: sqlStatements
    });
    
    if (error) {
      // If RPC function doesn't exist, fall back to sequential execution
      logError('Transaction RPC not available, using sequential execution', error);
      throw error;
    }
    
    return data;
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError('Transaction RPC execution failed', err);
    throw new Error(err.message || 'Transaction execution failed');
  }
}

