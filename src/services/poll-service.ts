/**
 * Poll Service
 * Handles polls, votes, and analytics
 */

import { supabase } from '../config/db.js';
import { getRedisClient } from '../config/db.js';
import { logError, logInfo } from '../shared/logger.js';

const redis = getRedisClient();

export interface PollOption {
  id: string;
  text: string;
  votes: number;
}

export interface CreatePollData {
  room_id: string;
  question: string;
  options: string[]; // Array of option text
  is_anonymous: boolean;
  is_multiple_choice: boolean;
  expires_at?: string;
}

/**
 * Create a poll
 */
export async function createPoll(data: CreatePollData, createdBy: string) {
  try {
    const options: PollOption[] = data.options.map((text, index) => ({
      id: `opt_${index}`,
      text,
      votes: 0
    }));

    const { data: poll, error } = await supabase
      .from('polls')
      .insert({
        room_id: data.room_id,
        created_by: createdBy,
        question: data.question,
        options: options,
        is_anonymous: data.is_anonymous,
        is_multiple_choice: data.is_multiple_choice,
        expires_at: data.expires_at,
        status: 'active'
      })
      .select()
      .single();

    if (error || !poll) {
      throw error || new Error('Failed to create poll');
    }

    // Broadcast poll creation
    await redis.publish(
      `room:${data.room_id}`,
      JSON.stringify({
        type: 'poll_created',
        poll_id: poll.id,
        question: data.question
      })
    );

    return poll;
  } catch (error: any) {
    logError('Failed to create poll', error);
    throw error;
  }
}

/**
 * Vote on a poll
 */
export async function voteOnPoll(
  pollId: string,
  optionId: string,
  userId: string | null // null if anonymous
) {
  try {
    // Get poll
    const { data: poll } = await supabase
      .from('polls')
      .select('*')
      .eq('id', pollId)
      .single();

    if (!poll) {
      throw new Error('Poll not found');
    }

    if (poll.status !== 'active') {
      throw new Error('Poll is not active');
    }

    if (poll.expires_at && new Date(poll.expires_at) < new Date()) {
      // Update poll status
      await supabase
        .from('polls')
        .update({ status: 'expired' })
        .eq('id', pollId);
      throw new Error('Poll has expired');
    }

    // Check if user already voted (unless multiple choice)
    if (!poll.is_multiple_choice && userId) {
      const { data: existingVote } = await supabase
        .from('poll_votes')
        .select('id')
        .eq('poll_id', pollId)
        .eq('user_id', userId)
        .single();

      if (existingVote) {
        throw new Error('Already voted');
      }
    }

    // Record vote
    await supabase.from('poll_votes').insert({
      poll_id: pollId,
      user_id: userId, // null if anonymous
      option_id: optionId
    });

    // Update option vote count in poll.options JSONB
    const options: PollOption[] = poll.options || [];
    const optionIndex = options.findIndex(opt => opt.id === optionId);
    if (optionIndex >= 0) {
      options[optionIndex].votes = (options[optionIndex].votes || 0) + 1;
      
      await supabase
        .from('polls')
        .update({ options })
        .eq('id', pollId);
    }

    // Broadcast vote
    await redis.publish(
      `room:${poll.room_id}`,
      JSON.stringify({
        type: 'poll_vote',
        poll_id: pollId,
        option_id: optionId,
        user_id: poll.is_anonymous ? null : userId
      })
    );

    logInfo(`Vote recorded for poll ${pollId}, option ${optionId}`);
    return { success: true };
  } catch (error: any) {
    logError('Failed to vote on poll', error);
    throw error;
  }
}

/**
 * Get poll results
 */
export async function getPollResults(pollId: string) {
  try {
    const { data: poll } = await supabase
      .from('polls')
      .select('*')
      .eq('id', pollId)
      .single();

    if (!poll) {
      throw new Error('Poll not found');
    }

    // Get vote counts
    const { data: votes } = await supabase
      .from('poll_votes')
      .select('option_id')
      .eq('poll_id', pollId);

    const voteCounts: Record<string, number> = {};
    if (votes) {
      for (const vote of votes) {
        voteCounts[vote.option_id] = (voteCounts[vote.option_id] || 0) + 1;
      }
    }

    // Merge with poll options
    const options: PollOption[] = (poll.options || []).map(opt => ({
      ...opt,
      votes: voteCounts[opt.id] || opt.votes || 0
    }));

    return {
      ...poll,
      options,
      total_votes: votes?.length || 0
    };
  } catch (error: any) {
    logError('Failed to get poll results', error);
    throw error;
  }
}

/**
 * Get polls for a room
 */
export async function getRoomPolls(roomId: string, includeClosed: boolean = false) {
  try {
    const query = supabase
      .from('polls')
      .select('*')
      .eq('room_id', roomId)
      .order('created_at', { ascending: false });

    if (!includeClosed) {
      query.eq('status', 'active');
    }

    const { data, error } = await query;

    if (error) {
      throw error;
    }

    return data || [];
  } catch (error: any) {
    logError('Failed to get room polls', error);
    return [];
  }
}

