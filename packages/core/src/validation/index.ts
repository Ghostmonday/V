/**
 * Shared Zod validation schemas
 * Single source of truth for all API input validation
 */

import { z } from 'zod';

// Common schemas
export const uuidSchema = z.string().uuid();
export const nonEmptyStringSchema = z.string().min(1);
export const emailSchema = z.string().email();
export const urlSchema = z.string().url();

// Room schemas
export const createRoomSchema = z.object({
  name: z.string().min(1).max(100),
  is_private: z.boolean().optional().default(false),
});

export const joinRoomSchema = z.object({
  roomId: uuidSchema,
});

// Message schemas
export const createMessageSchema = z.object({
  room_id: uuidSchema,
  content: z.string().min(1).max(10000),
  thread_id: uuidSchema.optional(),
  reply_to_id: uuidSchema.optional(),
});

export const updateMessageSchema = z.object({
  message_id: uuidSchema,
  content: z.string().min(1).max(10000),
});

export const deleteMessageSchema = z.object({
  message_id: uuidSchema,
});

// Search schemas
export const searchSchema = z.object({
  query: z.string().min(1),
  type: z.enum(['all', 'messages', 'rooms', 'users']).optional().default('all'),
  room_id: uuidSchema.optional(),
  user_id: uuidSchema.optional(),
  limit: z.number().int().positive().max(100).optional().default(50),
  offset: z.number().int().nonnegative().optional().default(0),
});

// File upload schemas
export const fileUploadSchema = z.object({
  mimeType: z.string().optional(),
  enableVoiceHash: z.boolean().optional().default(true),
});

// Authentication schemas
export const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

// WebSocket message schemas
export const wsMessageSchema = z.object({
  type: z.string(),
  data: z.record(z.unknown()),
  roomId: uuidSchema.optional(),
});

// Helper function to validate request body
export function validateBody<T>(schema: z.ZodSchema<T>) {
  return (data: unknown): T => {
    return schema.parse(data);
  };
}

// Helper function to validate query params
export function validateQuery<T>(schema: z.ZodSchema<T>) {
  return (query: unknown): T => {
    return schema.parse(query);
  };
}

