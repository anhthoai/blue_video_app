import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import multer from 'multer';
import { v4 as uuidv4 } from 'uuid';

// Validate S3 credentials
const S3_ACCESS_KEY_ID = process.env['S3_ACCESS_KEY_ID'];
const S3_SECRET_ACCESS_KEY = process.env['S3_SECRET_ACCESS_KEY'];
const BUCKET_NAME = process.env['S3_BUCKET_NAME'] || 'blue-video-storage';

console.log('🔧 S3 Configuration:');
console.log('   - Endpoint:', process.env['S3_ENDPOINT'] || 'default AWS');
console.log('   - Region:', process.env['S3_REGION'] || 'us-east-1');
console.log('   - Bucket:', BUCKET_NAME);
console.log('   - Access Key:', S3_ACCESS_KEY_ID ? `${S3_ACCESS_KEY_ID.substring(0, 8)}...` : 'NOT SET');
console.log('   - Secret Key:', S3_SECRET_ACCESS_KEY ? '***configured***' : 'NOT SET');

if (!S3_ACCESS_KEY_ID || !S3_SECRET_ACCESS_KEY || 
    S3_ACCESS_KEY_ID === 'dummy' || S3_ACCESS_KEY_ID === 'YOUR_AWS_ACCESS_KEY_ID_HERE') {
  console.warn('⚠️  WARNING: S3 credentials not configured properly!');
  console.warn('📝 Please update the following in your .env file:');
  console.warn('   - S3_ACCESS_KEY_ID (your AWS access key)');
  console.warn('   - S3_SECRET_ACCESS_KEY (your AWS secret key)');
  console.warn('   - S3_BUCKET_NAME (your S3 bucket name)');
  console.warn('   - S3_REGION (AWS region, e.g., us-east-1)');
  console.warn('   - S3_ENDPOINT (optional, only for S3-compatible services)');
  console.warn('⚠️  File uploads will NOT work until this is fixed!');
} else {
  console.log('✅ S3 credentials configured successfully!');
}

// Configure AWS S3 v3
const s3Config: any = {
  region: process.env['S3_REGION'] || 'auto',
  credentials: {
    accessKeyId: S3_ACCESS_KEY_ID || '',
    secretAccessKey: S3_SECRET_ACCESS_KEY || '',
  },
};

// Add custom endpoint if provided (for S3-compatible services like Cloudflare R2)
if (process.env['S3_ENDPOINT']) {
  s3Config.endpoint = process.env['S3_ENDPOINT'];
  s3Config.forcePathStyle = true; // Required for custom endpoints
  console.log('🌐 Using custom S3 endpoint (R2/compatible service)');
}

const s3Client = new S3Client(s3Config);

// Custom multer storage for AWS SDK v3
const s3Storage = {
  _handleFile: async (req: any, file: any, cb: any) => {
    try {
      // Get user info from request (should be set by auth middleware)
      const userId = req.userId;
      const userCreatedAt = req.userCreatedAt ? new Date(req.userCreatedAt) : new Date();
      
      // Generate file directory based on user's creation date (yyyy/mm/dd)
      const year = userCreatedAt.getFullYear();
      const month = String(userCreatedAt.getMonth() + 1).padStart(2, '0');
      const day = String(userCreatedAt.getDate()).padStart(2, '0');
      const fileDirectory = `${year}/${month}/${day}`;
      
      const folder = file.fieldname === 'avatar' ? 'avatars' : 'banners';
      const extension = file.originalname.split('.').pop();
      const filename = `${uuidv4()}.${extension}`;
      const key = `${folder}/${fileDirectory}/${filename}`;
      
      // Convert stream to buffer
      const chunks: Buffer[] = [];
      file.stream.on('data', (chunk: Buffer) => chunks.push(chunk));
      file.stream.on('end', async () => {
        try {
          const buffer = Buffer.concat(chunks);
          
          const command = new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: key,
            Body: buffer,
            ContentType: file.mimetype,
          });
          
          await s3Client.send(command);
          
          console.log(`📤 File uploaded to R2: ${key}`);
          console.log(`   User: ${userId}`);
          console.log(`   Directory: ${fileDirectory}`);
          console.log(`   Filename: ${filename}`);
          
          cb(null, {
            key,
            filename, // Just the filename
            fileDirectory, // The directory path
            folder, // avatars or banners
            bucket: BUCKET_NAME,
            size: buffer.length,
            mimetype: file.mimetype,
          });
        } catch (error) {
          cb(error);
        }
      });
    } catch (error) {
      cb(error);
    }
  },
  _removeFile: (_req: any, _file: any, cb: any) => {
    // No cleanup needed for S3
    cb(null);
  },
};

// Configure multer for S3 uploads
export const upload = multer({
  storage: s3Storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (_req, file, cb) => {
    console.log('📎 File upload attempt:', {
      originalname: file.originalname,
      mimetype: file.mimetype,
      fieldname: file.fieldname,
    });
    
    // Check if file is an image by mimetype or extension
    const isImageMimeType = file.mimetype.startsWith('image/');
    const imageExtensions = /\.(jpg|jpeg|png|gif|webp|bmp)$/i;
    const isImageExtension = imageExtensions.test(file.originalname);
    
    if (isImageMimeType || isImageExtension) {
      console.log('✅ Image file accepted');
      cb(null, true);
    } else {
      console.log('❌ File rejected - not an image');
      cb(new Error('Only image files are allowed') as any, false);
    }
  },
});

// Helper function to delete file from S3
export const deleteFromS3 = async (fileInfo: string | { folder: string; fileDirectory: string; filename: string }): Promise<boolean> => {
  try {
    let key: string;
    
    if (typeof fileInfo === 'string') {
      // Old format: full URL or key
      if (fileInfo.startsWith('http')) {
        const url = new URL(fileInfo);
        key = url.pathname.substring(1); // Remove leading slash
      } else {
        key = fileInfo;
      }
    } else {
      // New format: { folder, fileDirectory, filename }
      key = `${fileInfo.folder}/${fileInfo.fileDirectory}/${fileInfo.filename}`;
    }
    
    const command = new DeleteObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
    });
    
    await s3Client.send(command);
    
    console.log(`✅ File deleted from S3: ${key}`);
    return true;
  } catch (error) {
    console.error('❌ Error deleting file from S3:', error);
    return false;
  }
};

// Helper function to generate presigned URL for direct upload
export const generatePresignedUrl = async (fileName: string, fileType: string, folder: string): Promise<string> => {
  try {
    const key = `${folder}/${uuidv4()}-${Date.now()}-${fileName}`;
    
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      ContentType: fileType,
      ACL: 'public-read',
    });
    
    const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 300 }); // 5 minutes
    
    return presignedUrl;
  } catch (error) {
    console.error('❌ Error generating presigned URL:', error);
    throw error;
  }
};

// Custom multer storage for chat attachments
export const chatFileStorage = {
  _handleFile: async (req: any, file: any, cb: any) => {
    try {
      const userCreatedAt = req.userCreatedAt ? new Date(req.userCreatedAt) : new Date();
      
      // Generate file directory based on user's creation date (yyyy/mm/dd)
      const year = userCreatedAt.getFullYear();
      const month = String(userCreatedAt.getMonth() + 1).padStart(2, '0');
      const day = String(userCreatedAt.getDate()).padStart(2, '0');
      const fileDirectory = `${year}/${month}/${day}`;
      
      // Determine file type folder based on MIME type
      let typeFolder = 'doc';
      if (file.mimetype.startsWith('image/')) {
        typeFolder = 'photo';
      } else if (file.mimetype.startsWith('video/')) {
        typeFolder = 'video';
      } else if (file.mimetype.startsWith('audio/')) {
        typeFolder = 'audio';
      }
      
      const extension = file.originalname.split('.').pop();
      const filename = `${uuidv4()}.${extension}`;
      const key = `chat/${typeFolder}/${fileDirectory}/${filename}`;
      
      // Convert stream to buffer
      const chunks: Buffer[] = [];
      file.stream.on('data', (chunk: Buffer) => chunks.push(chunk));
      file.stream.on('end', async () => {
        try {
          const buffer = Buffer.concat(chunks);
          
          const command = new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: key,
            Body: buffer,
            ContentType: file.mimetype,
          });
          
          await s3Client.send(command);
          
          // Generate file URL
          const cdnUrl = process.env['CDN_URL'] || process.env['S3_ENDPOINT'];
          const location = cdnUrl 
            ? `${cdnUrl}/${key}`
            : `https://${BUCKET_NAME}.s3.${process.env['S3_REGION'] || 'us-east-1'}.amazonaws.com/${key}`;
          
          cb(null, {
            bucket: BUCKET_NAME,
            key: key,
            location: location,
            folder: `chat/${typeFolder}`,
            fileDirectory: fileDirectory,
            filename: filename,
            size: buffer.length,
            mimetype: file.mimetype,
            originalname: file.originalname,
          });
        } catch (error) {
          cb(error);
        }
      });
      
      file.stream.on('error', (error: any) => {
        cb(error);
      });
    } catch (error) {
      cb(error);
    }
  },
  _removeFile: async (_req: any, file: any, cb: any) => {
    try {
      const command = new DeleteObjectCommand({
        Bucket: BUCKET_NAME,
        Key: file.key,
      });
      await s3Client.send(command);
      cb(null);
    } catch (error) {
      cb(error);
    }
  },
};

// File filter for chat attachments
export const chatFileFilter = (_req: any, file: any, cb: any) => {
  // Allow images, videos, audio, and documents
  const allowedMimes = [
    // Images
    'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp',
    // Videos
    'video/mp4', 'video/mpeg', 'video/webm', 'video/quicktime',
    // Audio
    'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/aac',
    // Documents
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
  ];
  
  if (allowedMimes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`File type not supported: ${file.mimetype}`), false);
  }
};

export default s3Client;
