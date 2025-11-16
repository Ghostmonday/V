/**
 * Bot Invite Service
 * Handles bot invite tokens and templates
 */

import { supabase } from '../config/db.js';
import { sign } from 'jsonwebtoken';
import { logError, logInfo } from '../shared/logger.js';

const JWT_SECRET = process.env.JWT_SECRET || 'bot-invite-secret';

/**
 * Create bot invite token
 */
export async function createBotInvite(
  roomId: string,
  createdBy: string,
  botName: string,
  botConfig: Record<string, any> = {},
  templateId?: string,
  expiresInHours: number = 24
) {
  try {
    // Generate token
    const token = sign(
      {
        room_id: roomId,
        bot_name: botName,
        created_by: createdBy,
        template_id: templateId
      },
      JWT_SECRET,
      { expiresIn: `${expiresInHours}h` }
    );

    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + expiresInHours);

    // Store invite
    const { data: invite, error } = await supabase
      .from('bot_invites')
      .insert({
        room_id: roomId,
        created_by: createdBy,
        token,
        bot_name: botName,
        bot_config: botConfig,
        template_id: templateId,
        expires_at: expiresAt.toISOString(),
        status: 'pending'
      })
      .select()
      .single();

    if (error || !invite) {
      throw error || new Error('Failed to create bot invite');
    }

    logInfo(`Bot invite created for room ${roomId}, bot ${botName}`);
    return { token, invite_id: invite.id };
  } catch (error: any) {
    logError('Failed to create bot invite', error);
    throw error;
  }
}

/**
 * Use bot invite token
 */
export async function useBotInvite(token: string) {
  try {
    // Verify token
    const { verify } = await import('jsonwebtoken');
    const decoded = verify(token, JWT_SECRET) as any;

    // Get invite record
    const { data: invite } = await supabase
      .from('bot_invites')
      .select('*')
      .eq('token', token)
      .single();

    if (!invite) {
      throw new Error('Invite not found');
    }

    if (invite.status !== 'pending') {
      throw new Error('Invite already used or expired');
    }

    if (invite.expires_at && new Date(invite.expires_at) < new Date()) {
      // Mark as expired
      await supabase
        .from('bot_invites')
        .update({ status: 'expired' })
        .eq('id', invite.id);
      throw new Error('Invite has expired');
    }

    // Mark as used
    await supabase
      .from('bot_invites')
      .update({
        status: 'used',
        used_at: new Date().toISOString()
      })
      .eq('id', invite.id);

    return {
      room_id: invite.room_id,
      bot_name: invite.bot_name,
      bot_config: invite.bot_config,
      template_id: invite.template_id
    };
  } catch (error: any) {
    logError('Failed to use bot invite', error);
    throw error;
  }
}

/**
 * Get bot templates
 */
export async function getBotTemplates() {
  // In production, this would fetch from a templates table
  // For now, return hardcoded templates
  return [
    {
      id: 'welcome-bot',
      name: 'Welcome Bot',
      description: 'Sends welcome messages to new members',
      config: {
        welcome_message: 'Welcome to the room!',
        trigger_on_join: true
      }
    },
    {
      id: 'moderation-bot',
      name: 'Moderation Bot',
      description: 'Automatically moderates messages',
      config: {
        auto_moderate: true,
        action_on_violation: 'warn'
      }
    }
  ];
}

