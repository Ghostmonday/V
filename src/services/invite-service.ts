import { supabase } from '../config/database-config.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { Invite } from '../types/feature-types.js';

/**
 * Create a new invite
 */
export async function createInvite(
    userId: string,
    roomId: string,
    options?: { maxUses?: number; expiresAt?: string; customCode?: string }
): Promise<Invite> {
    try {
        const code = options?.customCode || Math.random().toString(36).substring(2, 10).toUpperCase();

        const { data, error } = await supabase
            .from('invites')
            .insert({
                code,
                created_by: userId,
                room_id: roomId,
                max_uses: options?.maxUses,
                expires_at: options?.expiresAt,
            })
            .select()
            .single();

        if (error) throw error;

        logInfo(`Invite created by ${userId}: ${code}`);
        return data as Invite;
    } catch (error: any) {
        logError('Failed to create invite', error);
        throw error;
    }
}

/**
 * Validate and use an invite
 */
export async function useInvite(code: string): Promise<boolean> {
    try {
        // 1. Get invite
        const { data: invite, error } = await supabase
            .from('invites')
            .select('*')
            .eq('code', code)
            .single();

        if (error || !invite) return false;

        // 2. Check expiration
        if (invite.expires_at && new Date(invite.expires_at) < new Date()) {
            return false;
        }

        // 3. Check usage limit
        if (invite.max_uses && invite.uses >= invite.max_uses) {
            return false;
        }

        // 4. Increment usage
        const { error: updateError } = await supabase
            .from('invites')
            .update({ uses: invite.uses + 1 })
            .eq('id', invite.id);

        if (updateError) throw updateError;

        logInfo(`Invite used: ${code}`);
        return true;
    } catch (error: any) {
        logError('Failed to use invite', error);
        return false;
    }
}
