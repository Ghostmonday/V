/**
 * Auth Middleware Tests
 * Tests JWT authentication middleware
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Request, Response, NextFunction } from 'express';
import { authMiddleware } from '../auth.js';
import { AuthenticatedRequest } from '../../types/auth.types.js';
import * as apiKeysService from '../../services/api-keys-service.js';
import jwt from 'jsonwebtoken';

// Mock dependencies
vi.mock('../../services/api-keys-service.js');
vi.mock('@sentry/node', () => ({
  default: {
    captureMessage: vi.fn(),
    addBreadcrumb: vi.fn(),
  },
}));

describe('authMiddleware', () => {
  let mockReq: Partial<AuthenticatedRequest>;
  let mockRes: Partial<Response>;
  let mockNext: NextFunction;

  beforeEach(() => {
    vi.clearAllMocks();

    mockReq = {
      headers: {},
    };

    mockRes = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    mockNext = vi.fn();

    // Mock JWT secret
    vi.mocked(apiKeysService.getJwtSecret).mockResolvedValue('test-secret-key');
  });

  it('should return 401 if Authorization header is missing', async () => {
    mockReq.headers = {};

    await authMiddleware(mockReq as AuthenticatedRequest, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith({ error: 'Unauthorized' });
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('should return 401 if token is missing from Authorization header', async () => {
    mockReq.headers = {
      authorization: 'Bearer',
    };

    await authMiddleware(mockReq as AuthenticatedRequest, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith({ error: 'Unauthorized' });
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('should call next() if token is valid', async () => {
    const token = jwt.sign({ userId: 'test-user-id' }, 'test-secret-key', { expiresIn: '1h' });
    mockReq.headers = {
      authorization: `Bearer ${token}`,
    };

    await authMiddleware(mockReq as AuthenticatedRequest, mockRes as Response, mockNext);

    expect(mockNext).toHaveBeenCalled();
    expect(mockReq.user).toBeDefined();
    expect(mockReq.user?.userId).toBe('test-user-id');
  });

  it('should return 401 if token is invalid', async () => {
    mockReq.headers = {
      authorization: 'Bearer invalid-token',
    };

    await authMiddleware(mockReq as AuthenticatedRequest, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith({ error: 'Invalid token' });
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('should return 401 if token is expired', async () => {
    const expiredToken = jwt.sign({ userId: 'test-user-id' }, 'test-secret-key', {
      expiresIn: '-1h',
    });
    mockReq.headers = {
      authorization: `Bearer ${expiredToken}`,
    };

    await authMiddleware(mockReq as AuthenticatedRequest, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith({ error: 'Invalid token' });
    expect(mockNext).not.toHaveBeenCalled();
  });
});
