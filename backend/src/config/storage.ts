import AWS from 'aws-sdk';
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

// Initialize S3 client
export const s3 = new AWS.S3({
  endpoint: s3Config.endpoint,
  accessKeyId: s3Config.accessKeyId,
  secretAccessKey: s3Config.secretAccessKey,
  region: s3Config.region,
  s3ForcePathStyle: true, // For S3-compatible services
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
    s3: s3,
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

      const uploadParams = {
        Bucket: s3Config.bucketName,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
        Metadata: {
          originalName: file.originalname,
          uploadedAt: new Date().toISOString(),
        },
      };

      const result = await s3.upload(uploadParams).promise();
      
      return {
        url: s3Config.cdnUrl ? `${s3Config.cdnUrl}/${key}` : result.Location,
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
      await s3.deleteObject({
        Bucket: s3Config.bucketName,
        Key: key,
      }).promise();
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
      const params = {
        Bucket: s3Config.bucketName,
        Key: key,
        Expires: expiresIn,
      };
      
      return await s3.getSignedUrlPromise('getObject', params);
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
      await s3.headObject({
        Bucket: s3Config.bucketName,
        Key: key,
      }).promise();
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
      const result = await s3.headObject({
        Bucket: s3Config.bucketName,
        Key: key,
      }).promise();
      
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
