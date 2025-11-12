import { S3Client, PutObjectCommand, DeleteObjectCommand, HeadObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import multer from 'multer';
import multerS3 from 'multer-s3';
import { v4 as uuidv4 } from 'uuid';
import dotenv from 'dotenv';

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
   * Download a file from a URL and upload it to S3
   */
  static async uploadFromUrl(
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

      const buffer = Buffer.from(await response.arrayBuffer());
      const contentType = response.headers.get('content-type') || 'application/octet-stream';
      
      // Determine file extension from content type or URL
      let extension = 'bin';
      if (contentType.includes('image/jpeg') || contentType.includes('image/jpg')) {
        extension = 'jpg';
      } else if (contentType.includes('image/png')) {
        extension = 'png';
      } else if (contentType.includes('image/webp')) {
        extension = 'webp';
      } else if (contentType.includes('image/gif')) {
        extension = 'gif';
      } else if (contentType.includes('video/webm')) {
        extension = 'webm';
      } else if (contentType.includes('video/mp4')) {
        extension = 'mp4';
      } else {
        // Try to extract from URL
        const urlExtension = url.split('.').pop()?.split('?')[0];
        if (urlExtension && urlExtension.length <= 4) {
          extension = urlExtension;
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
   * Generate signed URL for private files
   */
  static async getSignedUrl(
    key: string,
    expiresIn: number = 3600
  ): Promise<string> {
    try {
      const command = new GetObjectCommand({
        Bucket: s3Config.bucketName,
        Key: key,
      });
      
      return await getSignedUrl(s3Client, command, { expiresIn });
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
