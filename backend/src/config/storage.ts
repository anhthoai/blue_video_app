import { S3Client, PutObjectCommand, DeleteObjectCommand, HeadObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import multer from 'multer';
import multerS3 from 'multer-s3';
import { v4 as uuidv4 } from 'uuid';
import sharp from 'sharp';
import dotenv from 'dotenv';
import { redisClient } from './database';

dotenv.config();

// S3 Configuration for S3-compatible storage
export const s3Config = {
  endpoint: process.env['S3_ENDPOINT'] || 'https://s3.amazonaws.com',
  accessKeyId: process.env['S3_ACCESS_KEY_ID'] || '',
  secretAccessKey: process.env['S3_SECRET_ACCESS_KEY'] || '',
  region: process.env['S3_REGION'] || 'us-east-1',
  bucketName: process.env['S3_BUCKET_NAME'] || 'blue-video-storage',
  cdnUrl: process.env['CDN_URL'] || '',
};

// Initialize S3 client (AWS SDK v3)
export const s3Client = new S3Client({
  endpoint: s3Config.endpoint,
  credentials: {
    accessKeyId: s3Config.accessKeyId,
    secretAccessKey: s3Config.secretAccessKey,
  },
  region: s3Config.region,
  forcePathStyle: true, // For S3-compatible services
});

// File upload configuration
export const uploadConfig = {
  maxFileSize: parseInt(process.env['MAX_FILE_SIZE'] || '104857600'), // 100MB
  allowedImageTypes: (process.env['ALLOWED_IMAGE_TYPES'] || 'image/jpeg,image/png,image/webp,image/gif').split(','),
  allowedVideoTypes: (process.env['ALLOWED_VIDEO_TYPES'] || 'video/mp4,video/webm,video/quicktime').split(','),
  maxVideoDuration: parseInt(process.env['MAX_VIDEO_DURATION'] || '300'), // 5 minutes
};

// Multer configuration for S3 uploads
export const upload = multer({
  storage: multerS3({
    s3: s3Client,
    bucket: s3Config.bucketName,
    key: (_req, file, cb) => {
      const fileExtension = file.originalname.split('.').pop();
      const fileName = `${uuidv4()}.${fileExtension}`;
      
      // Organize files by type and date
      const date = new Date();
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      
      let folder = 'uploads';
      if (file.mimetype.startsWith('image/')) {
        folder = `images/${year}/${month}/${day}`;
      } else if (file.mimetype.startsWith('video/')) {
        folder = `videos/${year}/${month}/${day}`;
      } else if (file.mimetype.startsWith('audio/')) {
        folder = `audio/${year}/${month}/${day}`;
      }
      
      cb(null, `${folder}/${fileName}`);
    },
    contentType: multerS3.AUTO_CONTENT_TYPE,
    metadata: (_req, file, cb) => {
      cb(null, {
        fieldName: file.fieldname,
        originalName: file.originalname,
        uploadedAt: new Date().toISOString(),
      });
    },
  }),
  limits: {
    fileSize: uploadConfig.maxFileSize,
  },
  fileFilter: (_req, file, cb) => {
    const isImage = uploadConfig.allowedImageTypes.includes(file.mimetype);
    const isVideo = uploadConfig.allowedVideoTypes.includes(file.mimetype);
    
    if (isImage || isVideo) {
      cb(null, true);
    } else {
      cb(new Error(`File type ${file.mimetype} is not allowed`));
    }
  },
});

// Storage utility functions
export class StorageService {
  /**
   * Download a file from a URL and upload it to S3 with retry mechanism
   */
  static async uploadFromUrl(
    url: string,
    folder: string = 'uploads',
    filename?: string,
    maxRetries: number = 3
  ): Promise<{ url: string; key: string; size: number } | null> {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await this._uploadFromUrlAttempt(url, folder, filename);
      } catch (error: any) {
        console.error(`❌ Upload attempt ${attempt}/${maxRetries} failed:`, error.message);
        
        if (attempt === maxRetries) {
          console.error(`❌ All ${maxRetries} attempts failed for: ${url}`);
          return null;
        }
        
        // Exponential backoff: 1s, 2s, 4s
        const delay = Math.pow(2, attempt - 1) * 1000;
        console.log(`⏳ Retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
    return null;
  }

  /**
   * Internal method for single upload attempt
   */
  private static async _uploadFromUrlAttempt(
    url: string,
    folder: string = 'uploads',
    filename?: string
  ): Promise<{ url: string; key: string; size: number } | null> {
    try {
      console.log(`📥 Downloading from URL: ${url}`);
      
      // Download the file
      const response = await fetch(url);
      if (!response.ok) {
        console.error(`❌ Failed to download: ${response.status} ${response.statusText}`);
        return null;
      }

      let buffer: any = Buffer.from(await response.arrayBuffer());
      let contentType = response.headers.get('content-type') || 'application/octet-stream';
      
      // Determine file extension from content type or URL
      let extension = 'bin';
      let isImage = false;
      
      if (contentType.includes('image/jpeg') || contentType.includes('image/jpg')) {
        extension = 'jpg';
        isImage = true;
      } else if (contentType.includes('image/png')) {
        extension = 'png';
        isImage = true;
      } else if (contentType.includes('image/webp')) {
        extension = 'webp';
        isImage = true;
      } else if (contentType.includes('image/gif')) {
        extension = 'gif';
        isImage = true;
      } else if (contentType.includes('video/webm')) {
        extension = 'webm';
      } else if (contentType.includes('video/mp4')) {
        extension = 'mp4';
      } else {
        // Try to extract from URL
        const urlExtension = url.split('.').pop()?.split('?')[0];
        if (urlExtension && urlExtension.length <= 4) {
          extension = urlExtension;
          isImage = ['jpg', 'jpeg', 'png', 'webp'].includes(urlExtension.toLowerCase());
        }
      }

      // Compress images to reduce storage cost and improve loading speed
      if (isImage && extension !== 'gif') {
        try {
          console.log(`🗜️  Compressing image (${(buffer.length / 1024).toFixed(1)}KB)...`);
          const compressed = await sharp(buffer)
            .resize(1280, 720, { // Max dimensions while maintaining aspect ratio
              fit: 'inside',
              withoutEnlargement: true,
            })
            .webp({ quality: 85 }) // Convert to WebP for better compression
            .toBuffer();
          
          const originalSize = buffer.length;
          const compressedSize = compressed.length;
          const savings = ((1 - compressedSize / originalSize) * 100).toFixed(1);
          
          console.log(`✅ Compressed: ${(compressedSize / 1024).toFixed(1)}KB (${savings}% smaller)`);
          
          buffer = compressed;
          contentType = 'image/webp';
          extension = 'webp';
        } catch (error: any) {
          console.warn(`⚠️  Compression failed, using original: ${error.message}`);
          // Continue with original buffer
        }
      }

      const key = `${folder}/${filename || uuidv4()}.${extension}`;

      console.log(`📤 Uploading to S3: ${key}`);
      
      const uploadCommand = new PutObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
        Body: buffer,
        ContentType: contentType,
        // Don't set ACL for private buckets - presigned URLs will be used
        // ACL: 'public-read',
      });

      await s3Client.send(uploadCommand);

      const fileUrl = s3Config.cdnUrl
        ? `${s3Config.cdnUrl}/${key}`
        : `${s3Config.endpoint}/${s3Config.bucketName}/${key}`;

      console.log(`✅ Upload successful: ${fileUrl}`);

      return {
        url: fileUrl,
        key: key,
        size: buffer.length,
      };
    } catch (error: any) {
      console.error(`❌ Error uploading from URL:`, error.message);
      return null;
    }
  }

  /**
   * Batch upload multiple URLs in parallel
   */
  static async uploadFromUrlBatch(
    urls: Array<{ url: string; folder: string; filename?: string }>,
    concurrency: number = 3
  ): Promise<Array<{ url: string; key: string; size: number } | null>> {
    const results: Array<{ url: string; key: string; size: number } | null> = [];
    
    // Process in batches of `concurrency` at a time
    for (let i = 0; i < urls.length; i += concurrency) {
      const batch = urls.slice(i, i + concurrency);
      console.log(`📦 Processing batch ${Math.floor(i / concurrency) + 1}/${Math.ceil(urls.length / concurrency)}`);
      
      const batchResults = await Promise.all(
        batch.map(({ url, folder, filename }) =>
          this.uploadFromUrl(url, folder, filename)
        )
      );
      
      results.push(...batchResults);
    }
    
    return results;
  }

  /**
   * Upload file to S3-compatible storage
   */
  static async uploadFile(
    file: Express.Multer.File,
    folder: string = 'uploads'
  ): Promise<{ url: string; key: string; size: number }> {
    try {
      const fileExtension = file.originalname.split('.').pop();
      const fileName = `${uuidv4()}.${fileExtension}`;
      const key = `${folder}/${fileName}`;

      const uploadCommand = new PutObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
        Metadata: {
          originalName: file.originalname,
          uploadedAt: new Date().toISOString(),
        },
      });

      await s3Client.send(uploadCommand);
      
      const fileUrl = s3Config.cdnUrl 
        ? `${s3Config.cdnUrl}/${key}` 
        : `${s3Config.endpoint}/${s3Config.bucketName}/${key}`;
      
      return {
        url: fileUrl,
        key: key,
        size: file.size,
      };
    } catch (error) {
      console.error('Upload error:', error);
      throw new Error('Failed to upload file');
    }
  }

  /**
   * Delete file from S3-compatible storage
   */
  static async deleteFile(key: string): Promise<void> {
    try {
      const deleteCommand = new DeleteObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
      });
      await s3Client.send(deleteCommand);
    } catch (error) {
      console.error('Delete error:', error);
      throw new Error('Failed to delete file');
    }
  }

  /**
   * Get file URL with CDN
   */
  static getFileUrl(key: string): string {
    if (s3Config.cdnUrl) {
      return `${s3Config.cdnUrl}/${key}`;
    }
    return `https://${s3Config.bucketName}.s3.${s3Config.region}.amazonaws.com/${key}`;
  }

  /**
   * Generate signed URL for private files with caching
   */
  static async getSignedUrl(
    key: string,
    expiresIn: number = 3600
  ): Promise<string> {
    try {
      // Try to get from cache first (if Redis is enabled)
      const cacheKey = `presigned:${key}`;
      
      if (redisClient && redisClient.get) {
        try {
          const cached = await redisClient.get(cacheKey);
          if (cached) {
            console.log(`🎯 Cache hit for presigned URL: ${key}`);
            return cached;
          }
        } catch (error) {
          console.warn('⚠️  Redis cache read failed:', error);
          // Continue to generate new URL
        }
      }
      
      // Generate new presigned URL
      const command = new GetObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
      });
      
      const url = await getSignedUrl(s3Client, command, { expiresIn });
      
      // Cache the URL (cache for 30 minutes, less than actual expiry for safety)
      if (redisClient && redisClient.set) {
        const cacheExpiry = Math.min(1800, expiresIn - 60); // 30 min or expiry - 1 min
        try {
          await redisClient.set(cacheKey, url, { EX: cacheExpiry });
          console.log(`💾 Cached presigned URL for ${cacheExpiry}s: ${key}`);
        } catch (error) {
          console.warn('⚠️  Redis cache write failed:', error);
          // URL is still valid, just not cached
        }
      }
      
      return url;
    } catch (error) {
      console.error('Signed URL error:', error);
      throw new Error('Failed to generate signed URL');
    }
  }

  /**
   * Check if file exists
   */
  static async fileExists(key: string): Promise<boolean> {
    try {
      const command = new HeadObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
      });
      await s3Client.send(command);
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Get file metadata
   */
  static async getFileMetadata(key: string): Promise<any> {
    try {
      const command = new HeadObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
      });
      const result = await s3Client.send(command);
      
      return {
        size: result.ContentLength,
        lastModified: result.LastModified,
        contentType: result.ContentType,
        metadata: result.Metadata,
      };
    } catch (error) {
      console.error('Metadata error:', error);
      throw new Error('Failed to get file metadata');
    }
  }
}

// Middleware for file uploads
export const uploadMiddleware = {
  // Single file upload
  single: (fieldName: string) => upload.single(fieldName),
  
  // Multiple files upload
  array: (fieldName: string, maxCount: number = 10) => upload.array(fieldName, maxCount),
  
  // Multiple fields upload
  fields: (fields: Array<{ name: string; maxCount: number }>) => upload.fields(fields),
};

// File validation middleware
export const validateFile = (req: any, res: any, next: any) => {
  if (!req.file && !req.files) {
    return res.status(400).json({
      success: false,
      message: 'No file uploaded',
    });
  }
  
  next();
};

// Error handling for multer
export const handleUploadError = (error: any, _req: any, res: any, next: any) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        message: 'File too large. Maximum size is 100MB.',
      });
    }
    if (error.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        success: false,
        message: 'Too many files. Maximum is 10 files.',
      });
    }
  }
  
  if (error.message.includes('File type')) {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }
  
  next(error);
};
