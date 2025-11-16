/**
 * Message Service Tests
 * Tests message service functionality
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { sendMessageToRoom, getRoomMessages } from '../message-service.js';
import * as moderationService from '../moderation.service.js';
import * as roomService from '../room-service.js';
import * as subscriptionService from '../subscription-service.js';
import * as supabaseHelpers from '../../shared/supabase-helpers.js';
import { getRedisClient } from '../../config/db.js';

// Mock dependencies
vi.mock('../moderation.service.js');
vi.mock('../room-service.js');
vi.mock('../subscription-service.js');
vi.mock('../../shared/supabase-helpers.js');
vi.mock('../../config/db.js');
vi.mock('../../shared/logger.js', () => ({
  logError: vi.fn(),
  logWarning: vi.fn(),
}));

describe('Message Service', () => {
  let mockRedis: any;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockRedis = {
      publish: vi.fn().mockResolvedValue(1),
    };
    
    vi.mocked(getRedisClient).mockReturnValue(mockRedis as any);
    vi.mocked(moderationService.isUserMuted).mockResolvedValue(false);
    vi.mocked(roomService.getRoomConfig).mockResolvedValue(null);
    vi.mocked(supabaseHelpers.create).mockResolvedValue({ id: 'test-message-id' } as any);
  });

  describe('sendMessageToRoom', () => {
    it('should send a message successfully', async () => {
      const messageData = {
        roomId: 'test-room-id',
        senderId: 'test-user-id',
        content: 'Hello, world!',
      };

      await sendMessageToRoom(messageData);

      expect(moderationService.isUserMuted).toHaveBeenCalledWith('test-user-id', 'test-room-id');
      expect(supabaseHelpers.create).toHaveBeenCalled();
      expect(mockRedis.publish).toHaveBeenCalled();
    });

    it('should throw error if user is muted', async () => {
      vi.mocked(moderationService.isUserMuted).mockResolvedValue(true);
      
      const messageData = {
        roomId: 'test-room-id',
        senderId: 'test-user-id',
        content: 'Hello, world!',
      };

      await expect(sendMessageToRoom(messageData)).rejects.toThrow('You are temporarily muted in this room');
      
      expect(supabaseHelpers.create).not.toHaveBeenCalled();
      expect(mockRedis.publish).not.toHaveBeenCalled();
    });

    it('should handle numeric roomId', async () => {
      const messageData = {
        roomId: 123,
        senderId: 'test-user-id',
        content: 'Hello, world!',
      };

      await sendMessageToRoom(messageData);

      expect(moderationService.isUserMuted).toHaveBeenCalledWith('test-user-id', '123');
    });
  });

  describe('getRoomMessages', () => {
    it('should retrieve messages for a single room', async () => {
      const mockMessages = [
        { id: '1', content: 'Message 1' },
        { id: '2', content: 'Message 2' },
      ];
      
      vi.mocked(supabaseHelpers.findMany).mockResolvedValue(mockMessages as any);

      const result = await getRoomMessages('test-room-id');

      expect(result).toEqual(mockMessages);
      expect(supabaseHelpers.findMany).toHaveBeenCalled();
    });

    it('should handle since parameter for lazy loading', async () => {
      const mockMessages = [{ id: '1', content: 'Message 1' }];
      vi.mocked(supabaseHelpers.findMany).mockResolvedValue(mockMessages as any);

      const result = await getRoomMessages('test-room-id', '2025-01-01T00:00:00Z');

      expect(result).toEqual(mockMessages);
      expect(supabaseHelpers.findMany).toHaveBeenCalled();
    });

    it('should handle array of roomIds for batch query', async () => {
      const mockMessages = [{ id: '1', content: 'Message 1' }];
      
      // Mock the supabase RPC call
      const { supabase } = await import('../../config/db.js');
      vi.mocked(supabase.rpc).mockResolvedValue({ data: mockMessages, error: null } as any);

      const result = await getRoomMessages(['room-1', 'room-2']);

      expect(result).toEqual(mockMessages);
    });
  });
});

