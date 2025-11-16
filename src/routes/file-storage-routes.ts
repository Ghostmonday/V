/**
 * File Storage Routes
 * Handles file upload, retrieval, and deletion endpoints
 */

import { Router, Response } from 'express';
import multer from 'multer';
import * as fileStorageService from '../services/file-storage-service.js';
import { telemetryHook } from '../telemetry/index.js';
import { fileUploadSecurity } from '../middleware/file-upload-security.js';
import { authMiddleware } from '../middleware/auth.js';
import { AuthenticatedRequest } from '../types/auth.types.js';

const upload = multer({ limits: { fileSize: 10 * 1024 * 1024 } }); // 10MB max (enforced by middleware)
const router = Router();

/**
 * POST /files/upload
 * Upload a file to S3 and store metadata
 * Supports voice hash encoding for audio files
 */
router.post('/upload', authMiddleware, fileUploadSecurity, upload.single('file'), async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    telemetryHook('files_upload_start');
    
    // Extract user ID from authenticated request
    const userId = req.user?.userId;
    
    // Check if voice hash should be enabled (default: true for audio files)
    const enableVoiceHash = req.body.enableVoiceHash !== 'false';
    
    const result = await fileStorageService.uploadFileToStorage(req.file, {
      userId: userId,
      mimeType: req.body.mimeType || req.file?.mimetype,
      enableVoiceHash: enableVoiceHash
    }); // Error branch: S3 upload can hang, no timeout
    
    telemetryHook('files_upload_end');
    res.json(result);
  } catch (error) {
    next(error); // Error branch: partial failure (S3 succeeded but DB failed) not distinguished
  }
});

/**
 * GET /files/:id
 * Get file URL by database ID
 */
router.get('/:id', async (req, res, next) => {
  try {
    telemetryHook('files_get_start');
    const url = await fileStorageService.getFileUrlById(req.params.id);
    telemetryHook('files_get_end');
    res.json({ url });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /files/:id
 * Delete a file from S3 and database
 */
router.delete('/:id', async (req, res, next) => {
  try {
    telemetryHook('files_delete_start');
    await fileStorageService.deleteFileById(req.params.id);
    telemetryHook('files_delete_end');
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

export default router;

