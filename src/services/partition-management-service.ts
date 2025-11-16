/**
 * Partition Management Service
 * Handles partition rotation, cleanup, and metadata loading
 * 
 * Integrates with SQL partition management functions:
 * - create_partition_if_needed()
 * - list_partitions()
 * - drop_partition()
 * - get_table_size()
 */

import { supabase } from '../config/db.js';
import { logInfo, logError, logWarning } from '../shared/logger.js';

/**
 * Rotate partition: Create new partition for current month
 * Returns the created partition name
 */
export async function rotatePartition(): Promise<{ success: boolean; partitionName?: string; error?: string }> {
  try {
    // Get current month in YYYY_MM format
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const partitionMonth = `${year}_${month}`;
    
    logInfo('Rotating partition', { partitionMonth });
    
    // Call SQL function to create partition if needed
    const { data, error } = await supabase.rpc('create_partition_if_needed', {
      partition_month: partitionMonth
    });
    
    if (error) {
      logError('Partition rotation failed', error);
      return { success: false, error: error.message };
    }
    
    const partitionName = data as string;
    logInfo('Partition rotated successfully', { partitionName });
    
    return { success: true, partitionName };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('Partition rotation error', error instanceof Error ? error : new Error(errorMessage));
    return { success: false, error: errorMessage };
  }
}

/**
 * Run cleanup: Drop old partitions older than retention period
 * 
 * @param oldestPartitionMonth - Partition month to keep (format: YYYY_MM)
 *                                Partitions older than this will be dropped
 */
export async function runAllCleanup(
  oldestPartitionMonth: string
): Promise<{ success: boolean; dropped: number; errors: string[] }> {
  try {
    logInfo('Starting partition cleanup', { oldestPartitionMonth });
    
    // List all partitions
    const { data: partitions, error: listError } = await supabase.rpc('list_partitions');
    
    if (listError) {
      logError('Failed to list partitions', listError);
      return { success: false, dropped: 0, errors: [listError.message] };
    }
    
    if (!partitions || partitions.length === 0) {
      logInfo('No partitions to clean up');
      return { success: true, dropped: 0, errors: [] };
    }
    
    const errors: string[] = [];
    let dropped = 0;
    
    // Parse oldest partition month for comparison
    const [oldestYear, oldestMonth] = oldestPartitionMonth.split('_').map(Number);
    const oldestDate = new Date(oldestYear, oldestMonth - 1, 1);
    
    // Drop partitions older than retention period
    for (const partition of partitions) {
      try {
        const partitionMonth = partition.partition_month as string;
        const [year, month] = partitionMonth.split('_').map(Number);
        const partitionDate = new Date(year, month - 1, 1);
        
        // Drop if partition is older than retention period
        if (partitionDate < oldestDate) {
          logInfo('Dropping old partition', { partitionMonth });
          
          const { error: dropError } = await supabase.rpc('drop_partition', {
            partition_month: partitionMonth
          });
          
          if (dropError) {
            const errorMsg = `Failed to drop partition ${partitionMonth}: ${dropError.message}`;
            logError(errorMsg, dropError);
            errors.push(errorMsg);
          } else {
            dropped++;
            logInfo('Partition dropped successfully', { partitionMonth });
          }
        }
      } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        const errorMsg = `Error processing partition ${partition.partition_month}: ${errorMessage}`;
        logError(errorMsg, error instanceof Error ? error : new Error(errorMessage));
        errors.push(errorMsg);
      }
    }
    
    logInfo('Partition cleanup completed', { dropped, errors: errors.length });
    
    return {
      success: errors.length === 0,
      dropped,
      errors
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('Partition cleanup error', error instanceof Error ? error : new Error(errorMessage));
    return { success: false, dropped: 0, errors: [errorMessage] };
  }
}

/**
 * Load partition metadata with size information
 * Uses RPC call to get_table_size for accurate size data
 * 
 * @returns Array of partition metadata with sizes
 */
export async function loadPartitionMetadata(): Promise<Array<{
  partition_name: string;
  partition_month: string;
  row_count: number;
  total_size: string;
  size_bytes: number;
}>> {
  try {
    // List all partitions
    const { data: partitions, error: listError } = await supabase.rpc('list_partitions');
    
    if (listError) {
      logError('Failed to list partitions', listError);
      return [];
    }
    
    if (!partitions || partitions.length === 0) {
      return [];
    }
    
    // Enrich with size data using RPC call
    const enrichedPartitions = await Promise.all(
      partitions.map(async (partition: any) => {
        try {
          // Get table size using RPC call
          const { data: sizeBytes, error: sizeError } = await supabase.rpc('get_table_size', {
            table_name: partition.partition_name
          });
          
          return {
            partition_name: partition.partition_name,
            partition_month: partition.partition_month,
            row_count: partition.row_count || 0,
            total_size: partition.total_size || '0 bytes',
            size_bytes: sizeError ? 0 : (sizeBytes as number || 0)
          };
        } catch (error: unknown) {
          const errorMessage = error instanceof Error ? error.message : 'Unknown error';
          logWarning('Failed to get partition size', { 
            partition: partition.partition_name, 
            error: errorMessage 
          });
          
          return {
            partition_name: partition.partition_name,
            partition_month: partition.partition_month,
            row_count: partition.row_count || 0,
            total_size: partition.total_size || '0 bytes',
            size_bytes: 0
          };
        }
      })
    );
    
    return enrichedPartitions;
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('Failed to load partition metadata', error instanceof Error ? error : new Error(errorMessage));
    return [];
  }
}

