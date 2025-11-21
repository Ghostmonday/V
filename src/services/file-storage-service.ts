/**
 * File Storage Service
 * Handles file uploads to AWS S3 and metadata storage in Supabase
 */

import AWS from 'aws-sdk';
import { create, findOne, deleteOne } from '../shared/supabase-helpers-shared.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { encodeVoiceHash, verifyVoiceHash, extractAudioBuffer } from './voice-security-service.js';
import { getAwsKeys } from './api-keys-service.js';

// S3 client initialized lazily
let s3Client: AWS.S3 | null = null;

async function getS3Client(): Promise<AWS.S3> {
  if (s3Client) return s3Client;

  const awsKeys = await getAwsKeys();
  if (!awsKeys.accessKeyId || !awsKeys.secretAccessKey) {
    throw new Error('AWS credentials not found in vault');
  }

  s3Client = new AWS.S3({
    accessKeyId: awsKeys.accessKeyId,
    secretAccessKey: awsKeys.secretAccessKey,
    region: awsKeys.region || 'us-east-1',
  });

  return s3Client;
}

/**
 * Upload a file to S3 and store metadata in database
 * Returns the file URL and database ID
 *
 * @param file - File to upload
 * @param options - Optional configuration (userId for voice hash, mimeType)
 */
export async function uploadFileToStorage(
  file: Express.Multer.File | undefined,
  options?: {
    userId?: string;
    mimeType?: string;
    enableVoiceHash?: boolean;
  }
): Promise<{ url: string; id: string | number }> {
  const s3 = await getS3Client();
  try {
    if (!file) {
      throw new Error('No file provided');
    }

    let fileBuffer = file.buffer;

    // Apply voice hash encoding if this is a voice message
    const isVoiceMessage =
      options?.mimeType?.startsWith('audio/') || file.mimetype?.startsWith('audio/');

    if (isVoiceMessage && options?.enableVoiceHash && options?.userId) {
      logInfo('Encoding voice hash for voice message', { userId: options.userId });
      fileBuffer = await encodeVoiceHash(file.buffer, options.userId);
    }

    // Generate unique S3 key
    const s3Key = `${Date.now()}_${file.originalname}`;

    // Get AWS bucket from vault
    const awsKeys = await getAwsKeys();
    const bucket = awsKeys.bucket || 'vibez-files';

    // Upload to S3
    const uploadParams = {
      Bucket: bucket,
      Key: s3Key,
      Body: fileBuffer,
    };

    const uploadResult = await s3.upload(uploadParams).promise(); // No timeout - can hang indefinitely
    const fileUrl = (uploadResult as any).Location;

    // Store file metadata in database
    const fileRecord = await create('files', {
      url: fileUrl,
      mime_type: options?.mimeType || file.mimetype,
      has_voice_hash: (isVoiceMessage && options?.enableVoiceHash) || false,
    }); // Race: S3 upload succeeds but DB insert fails = orphaned file

    return {
      url: fileUrl,
      id: fileRecord.id,
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('File upload failed', error instanceof Error ? error : new Error(errorMessage));
    throw new Error(errorMessage || 'Failed to upload file');
  }
}

/**
 * Verify voice hash for downloaded file
 *
 * @param fileBuffer - File buffer from S3
 * @param expectedUserId - Expected user ID
 * @returns true if hash is valid, false otherwise
 */
export async function verifyFileVoiceHash(
  fileBuffer: Buffer,
  expectedUserId: string
): Promise<boolean> {
  try {
    return await verifyVoiceHash(fileBuffer, expectedUserId);
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError(
      'Voice hash verification failed',
      error instanceof Error ? error : new Error(errorMessage)
    );
    return false;
  }
}

/**
 * Get the URL of a file by its database ID
 */
export async function getFileUrlById(fileId: string): Promise<string> {
  try {
    const fileRecord = await findOne<{ url: string }>('files', { id: fileId });

    if (!fileRecord) {
      return '';
    }

    return fileRecord.url;
  } catch (error: any) {
    logError('Failed to retrieve file URL', error);
    throw new Error(error.message || 'Failed to get file URL');
  }
}

/**
 * Delete a file from S3 and remove metadata from database
 */
export async function deleteFileById(fileId: string): Promise<void> {
  try {
    // Retrieve file URL from database
    const fileRecord = await findOne<{ url: string }>('files', { id: fileId });

    if (!fileRecord) {
      logInfo('File not found for deletion:', fileId);
      return;
    }

    // Extract S3 key from URL
    const s3Key = fileRecord.url.split('/').pop();

    if (s3Key) {
      // Get AWS bucket from vault
      const s3 = await getS3Client();
      const awsKeys = await getAwsKeys();
      const bucket = awsKeys.bucket || 'vibez-files';

      // Delete from S3
      await s3
        .deleteObject({
          Bucket: bucket,
          Key: s3Key,
        })
        .promise(); // Silent fail: S3 delete fails but DB delete proceeds = inconsistent state
    }

    // Delete metadata from database
    await deleteOne('files', fileId); // Race: DB delete succeeds but S3 delete fails = metadata lost, file remains
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logError('File deletion failed', error instanceof Error ? error : new Error(errorMessage));
    throw new Error(errorMessage || 'Failed to delete file');
  }
}
