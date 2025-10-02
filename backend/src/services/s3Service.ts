import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import multer from 'multer';
import { v4 as uuidv4 } from 'uuid';

// Configure AWS S3 v3
const s3Client = new S3Client({
  region: process.env['AWS_REGION'] || 'us-east-1',
  credentials: {
    accessKeyId: process.env['AWS_ACCESS_KEY_ID'] || '',
    secretAccessKey: process.env['AWS_SECRET_ACCESS_KEY'] || '',
  },
});

// S3 bucket configuration
const BUCKET_NAME = process.env['AWS_S3_BUCKET_NAME'] || 'blue-video-storage';

// Custom multer storage for AWS SDK v3
const s3Storage = {
  _handleFile: async (_req: any, file: any, cb: any) => {
    try {
      const folder = file.fieldname === 'avatar' ? 'avatars' : 'banners';
      const fileName = `${folder}/${uuidv4()}-${Date.now()}.${file.originalname.split('.').pop()}`;
      
      // Convert stream to buffer
      const chunks: Buffer[] = [];
      file.stream.on('data', (chunk: Buffer) => chunks.push(chunk));
      file.stream.on('end', async () => {
        try {
          const buffer = Buffer.concat(chunks);
          
          const command = new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: fileName,
            Body: buffer,
            ContentType: file.mimetype,
            ACL: 'public-read',
          });
          
          await s3Client.send(command);
          
          const location = `https://${BUCKET_NAME}.s3.${process.env['AWS_REGION'] || 'us-east-1'}.amazonaws.com/${fileName}`;
          
          cb(null, {
            location,
            key: fileName,
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
    // Check if file is an image
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed') as any, false);
    }
  },
});

// Helper function to delete file from S3
export const deleteFromS3 = async (fileUrl: string): Promise<boolean> => {
  try {
    // Extract key from URL
    const url = new URL(fileUrl);
    const key = url.pathname.substring(1); // Remove leading slash
    
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

export default s3Client;
