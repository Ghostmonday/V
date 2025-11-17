/**
 * Password Migration Script
 * Migrates plaintext passwords to argon2 hashes
 *
 * Usage: npx ts-node scripts/migrate-passwords.ts
 */

import argon2 from 'argon2';
import { supabase } from '../src/shared/supabase-client.js';
import { logInfo, logError } from '../src/shared/logger.js';

async function migratePasswords() {
  try {
    logInfo('Starting password migration...');

    // Find all users with plaintext passwords
    const { data: users, error: fetchError } = await supabase
      .from('users')
      .select('id, password, password_hash')
      .not('password', 'is', null)
      .is('password_hash', null);

    if (fetchError) {
      throw fetchError;
    }

    if (!users || users.length === 0) {
      logInfo('No plaintext passwords found to migrate');
      return;
    }

    logInfo(`Found ${users.length} users with plaintext passwords`);

    let migrated = 0;
    let failed = 0;

    for (const user of users) {
      try {
        if (!user.password || typeof user.password !== 'string') {
          logError('Invalid password format', { userId: user.id });
          failed++;
          continue;
        }

        // Hash password with argon2
        const password_hash = await argon2.hash(user.password, {
          type: argon2.argon2id,
          memoryCost: 65536, // 64 MB
          timeCost: 3,
          parallelism: 4,
        });

        // Update user with hash and remove plaintext password
        const { error: updateError } = await supabase
          .from('users')
          .update({
            password_hash,
            password: null, // Remove plaintext password
          })
          .eq('id', user.id);

        if (updateError) {
          throw updateError;
        }

        migrated++;
        logInfo(`Migrated password for user ${user.id}`);

        // Small delay to avoid overwhelming the database
        await new Promise((resolve) => setTimeout(resolve, 100));
      } catch (error: any) {
        logError(`Failed to migrate password for user ${user.id}`, error);
        failed++;
      }
    }

    logInfo(`Password migration complete: ${migrated} migrated, ${failed} failed`);
  } catch (error: any) {
    logError('Password migration failed', error);
    process.exit(1);
  }
}

// Run migration
migratePasswords()
  .then(() => {
    logInfo('Migration script completed');
    process.exit(0);
  })
  .catch((error) => {
    logError('Migration script failed', error);
    process.exit(1);
  });
