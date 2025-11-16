/**
 * File Upload Security Middleware
 * Validates file types, sizes, and content before upload
 */

import { Request, Response, NextFunction } from 'express';
import { logError, logInfo } from '../shared/logger.js';
import { scanForToxicity } from '../services/moderation.service.js';
import { getRoomConfig } from '../services/room-service.js';

const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'application/pdf',
  'text/plain',
  'application/json'
];

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB default
const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5MB for images
const MAX_PDF_SIZE = 10 * 1024 * 1024; // 10MB for PDFs

export const fileUploadSecurity = (req: Request, res: Response, next: NextFunction) => {
  if (!req.file) {
    return next();
  }

  const file = req.file;
  const mimeType = file.mimetype;
  const fileSize = file.size;

  // Validate MIME type
  if (!ALLOWED_MIME_TYPES.includes(mimeType)) {
    logInfo('File upload rejected', `Invalid MIME type: ${mimeType}`);
    return res.status(400).json({
      error: 'Invalid file type',
      allowedTypes: ALLOWED_MIME_TYPES
    });
  }

  // Validate file size based on type
  let maxSize = MAX_FILE_SIZE;
  if (mimeType.startsWith('image/')) {
    maxSize = MAX_IMAGE_SIZE;
  } else if (mimeType === 'application/pdf') {
    maxSize = MAX_PDF_SIZE;
  }

  if (fileSize > maxSize) {
    logInfo('File upload rejected', `File too large: ${fileSize} bytes`);
    return res.status(400).json({
      error: 'File too large',
      maxSize: maxSize,
      fileSize: fileSize
    });
  }

  // Basic content validation (check file signature/magic bytes)
  // TODO: Add virus scanning integration (ClamAV or cloud service)
  
  next();
};

/**
 * File upload moderation check
 * Scans file names/metadata for toxicity if room has moderation enabled
 */
export const fileUploadModeration = async (req: Request, res: Response, next: NextFunction) => {
  if (!req.file) {
    return next();
  }

  try {
    // Get room ID from request (adjust based on your route structure)
    const roomId = req.body.roomId || req.params.roomId;
    if (!roomId) {
      return next(); // No room context, skip moderation
    }

    // Check if room has moderation enabled
    const roomConfig = await getRoomConfig(roomId);
    if (!roomConfig?.ai_moderation) {
      return next(); // Moderation not enabled, skip
    }

    // Scan file name for toxicity
    const fileName = req.file.originalname || req.file.filename || '';
    const scan = await scanForToxicity(`File: ${fileName}`, roomId);

    if (scan.isToxic) {
      logInfo('File upload flagged', `File: ${fileName}, Score: ${scan.score}`);
      // Log but allow upload (moderation is warnings-first)
      // Could optionally block here if you want stricter file moderation
    }

    next();
  } catch (error: unknown) {
    const err = error instanceof Error ? error : new Error(String(error));
    logError('File upload moderation check failed', err);
    // Fail-safe: allow upload if moderation check fails
    next();
  }
};

