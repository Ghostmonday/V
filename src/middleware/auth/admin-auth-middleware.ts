/**
 * Admin Authentication Middleware
 * Role hierarchy: user → moderator → admin → owner
 * Requires user to have appropriate role for protected endpoints
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types/auth.types.js';
import { supabase } from '../../config/db.ts';
import { logError, logAudit } from '../../shared/logger.js';

export type UserRole = 'user' | 'moderator' | 'admin' | 'owner';

/**
 * Permission matrix: defines what each role can do
 */
export const PERMISSIONS = {
  user: ['read_messages', 'send_messages', 'create_rooms'],
  moderator: [
    'read_messages',
    'send_messages',
    'create_rooms',
    'moderate_content',
    'warn_users',
    'mute_users',
  ],
  admin: [
    'read_messages',
    'send_messages',
    'create_rooms',
    'moderate_content',
    'warn_users',
    'mute_users',
    'ban_users',
    'manage_rooms',
    'view_audit_logs',
  ],
  owner: [
    'read_messages',
    'send_messages',
    'create_rooms',
    'moderate_content',
    'warn_users',
    'mute_users',
    'ban_users',
    'manage_rooms',
    'view_audit_logs',
    'manage_users',
    'system_config',
  ],
} as const;

/**
 * Get user's highest role
 */
export async function getUserRole(userId: string, roomId?: string): Promise<UserRole> {
  try {
    // Check for global admin/owner flag first
    const { data: userData } = await supabase
      .from('users')
      .select('metadata')
      .eq('id', userId)
      .single();

    if (userData?.metadata?.is_owner === true) {
      return 'owner';
    }
    if (userData?.metadata?.is_admin === true) {
      return 'admin';
    }

    // Check room-specific roles if roomId provided
    if (roomId) {
      const { data: membership } = await supabase
        .from('room_memberships')
        .select('role')
        .eq('user_id', userId)
        .eq('room_id', roomId)
        .single();

      if (membership?.role === 'owner') return 'owner';
      if (membership?.role === 'admin') return 'admin';
      if (membership?.role === 'mod') return 'moderator';
    }

    // Check if user has admin role in any room
    const { data: adminMembership } = await supabase
      .from('room_memberships')
      .select('role')
      .eq('user_id', userId)
      .eq('role', 'admin')
      .limit(1);

    if (adminMembership && adminMembership.length > 0) {
      return 'admin';
    }

    // Check if user has moderator role in any room
    const { data: modMembership } = await supabase
      .from('room_memberships')
      .select('role')
      .eq('user_id', userId)
      .eq('role', 'mod')
      .limit(1);

    if (modMembership && modMembership.length > 0) {
      return 'moderator';
    }

    return 'user';
  } catch (error: any) {
    logError('Get user role error', error);
    return 'user';
  }
}

/**
 * Check if user has required permission
 */
export async function hasPermission(
  userId: string,
  permission: string,
  roomId?: string
): Promise<boolean> {
  const role = await getUserRole(userId, roomId);
  const rolePermissions = PERMISSIONS[role] || [];
  return rolePermissions.includes(permission as any);
}

/**
 * Check if user is admin or higher
 */
async function isAdmin(userId: string, roomId?: string): Promise<boolean> {
  const role = await getUserRole(userId, roomId);
  return role === 'admin' || role === 'owner';
}

/**
 * Check if user is owner
 */
async function isOwner(userId: string): Promise<boolean> {
  const role = await getUserRole(userId);
  return role === 'owner';
}

/**
 * Middleware to require admin role
 */
export const requireAdmin = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = req.user?.id || req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const admin = await isAdmin(userId);

    if (!admin) {
      await logAudit('admin_access_denied', userId, {
        endpoint: req.path,
        method: req.method,
      });
      res.status(403).json({ error: 'Admin access required' });
      return;
    }

    // User is admin - proceed
    next();
  } catch (error: any) {
    logError('Admin middleware error', error);
    res.status(500).json({ error: 'Authorization check failed' });
  }
};

/**
 * Middleware to require moderator role (admin or mod)
 */
export const requireModerator = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = req.user?.id || req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const role = await getUserRole(userId);

    if (role === 'moderator' || role === 'admin' || role === 'owner') {
      next();
      return;
    }

    await logAudit('moderator_access_denied', userId, {
      endpoint: req.path,
      method: req.method,
      role,
    });
    res.status(403).json({ error: 'Moderator access required' });
  } catch (error: any) {
    logError('Moderator middleware error', error);
    res.status(500).json({ error: 'Authorization check failed' });
  }
};

/**
 * Middleware to require owner role
 */
export const requireOwner = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = req.user?.id || req.user?.userId;

    if (!userId) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    const owner = await isOwner(userId);

    if (!owner) {
      await logAudit('owner_access_denied', userId, {
        endpoint: req.path,
        method: req.method,
      });
      res.status(403).json({ error: 'Owner access required' });
      return;
    }

    next();
  } catch (error: any) {
    logError('Owner middleware error', error);
    res.status(500).json({ error: 'Authorization check failed' });
  }
};

/**
 * Middleware factory to require specific permission
 */
export function requirePermission(permission: string) {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user?.id || req.user?.userId;
      const roomId = req.params?.roomId || req.body?.roomId;

      if (!userId) {
        res.status(401).json({ error: 'Authentication required' });
        return;
      }

      const hasPerm = await hasPermission(userId, permission, roomId);

      if (!hasPerm) {
        await logAudit('permission_denied', userId, {
          endpoint: req.path,
          method: req.method,
          permission,
          roomId,
        });
        res.status(403).json({ error: `Permission required: ${permission}` });
        return;
      }

      next();
    } catch (error: any) {
      logError('Permission check error', error);
      res.status(500).json({ error: 'Authorization check failed' });
    }
  };
}
