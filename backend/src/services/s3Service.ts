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

// Video storage configuration
export const videoStorage: any = {
  _handleFile: async (req: any, file: any, cb: any) => {
    console.log('🎬 videoStorage._handleFile called for:', file.originalname);
    try {
      const userId = req.user?.id;
      console.log('👤 User ID in videoStorage:', userId);
      
      if (!userId) {
        console.log('❌ No user ID in video storage');
        return cb(new Error('User not authenticated'));
      }
      
      // Generate file directory based on upload date (yyyy/mm/dd)
      const now = new Date();
      const year = now.getFullYear();
      const month = String(now.getMonth() + 1).padStart(2, '0');
      const day = String(now.getDate()).padStart(2, '0');
      const fileDirectory = `${year}/${month}/${day}`;
      
      const extension = file.originalname.split('.').pop();
      
      // Store the video filename in req so thumbnail can use the same name
      if (file.fieldname === 'video') {
        // Generate new UUID for video
        const baseFilename = uuidv4();
        const filename = `${baseFilename}.${extension}`;
        req._videoBaseFilename = baseFilename; // Store base name for thumbnail
        req._videoFileDirectory = fileDirectory; // Store directory for thumbnail
        
        const key = `videos/${fileDirectory}/${filename}`;
        
        console.log('📁 Video file details:', {
          originalName: file.originalname,
          mimetype: file.mimetype,
          fileDirectory,
          filename,
          baseFilename,
          key,
        });
        
        // Continue with video upload
        await uploadFileToS3(file, key, fileDirectory, filename, cb);
      } else if (file.fieldname === 'thumbnail') {
        // Use the same base filename as video but with image extension
        const baseFilename = req._videoBaseFilename || uuidv4();
        const thumbnailFileDirectory = req._videoFileDirectory || fileDirectory;
        const filename = `${baseFilename}.${extension}`;
        
        const key = `thumbnails/${thumbnailFileDirectory}/${filename}`;
        
        console.log('📁 Thumbnail file details (using video filename):', {
          originalName: file.originalname,
          mimetype: file.mimetype,
          fileDirectory: thumbnailFileDirectory,
          filename,
          baseFilename,
          key,
        });
        
        // Continue with thumbnail upload
        await uploadFileToS3(file, key, thumbnailFileDirectory, filename, cb);
      } else if (file.fieldname.startsWith('subtitle_')) {
        // Extract language code from fieldname (subtitle_eng, subtitle_tha, etc.)
        const langCode = file.fieldname.replace('subtitle_', '');
        
        // Use the same base filename as video but with subtitle naming
        const baseFilename = req._videoBaseFilename || uuidv4();
        const subtitleFileDirectory = req._videoFileDirectory || fileDirectory;
        
        // Build subtitle filename: baseFilename.langCode.srt or baseFilename.srt (for English)
        // English doesn't need language code suffix
        const filename = (langCode === 'eng' || langCode === 'en') 
          ? `${baseFilename}.${extension}`
          : `${baseFilename}.${langCode}.${extension}`;
        
        const key = `subtitles/${subtitleFileDirectory}/${filename}`;
        
        console.log('📁 Subtitle file details (using video filename):', {
          originalName: file.originalname,
          mimetype: file.mimetype,
          langCode,
          fileDirectory: subtitleFileDirectory,
          filename,
          baseFilename,
          key,
        });
        
        // Continue with subtitle upload
        await uploadFileToS3(file, key, subtitleFileDirectory, filename, cb);
      } else {
        return cb(new Error('Unknown field: ' + file.fieldname));
      }
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

// Helper function to upload file to S3
async function uploadFileToS3(file: any, key: string, fileDirectory: string, filename: string, cb: any) {
  try {
    // Convert stream to buffer
    const chunks: Buffer[] = [];
    file.stream.on('data', (chunk: Buffer) => chunks.push(chunk));
    file.stream.on('end', async () => {
      try {
        const buffer = Buffer.concat(chunks);
        console.log(`📦 Buffer size: ${buffer.length} bytes (${(buffer.length / 1024 / 1024).toFixed(2)} MB)`);
        
        const command = new PutObjectCommand({
          Bucket: BUCKET_NAME,
          Key: key,
          Body: buffer,
          ContentType: file.mimetype,
        });
        
        console.log('☁️  Uploading to S3/R2:', key);
        await s3Client.send(command);
        console.log('✅ Upload to S3/R2 successful!');
        
        // Save buffer to temporary local file for ffmpeg processing (only if VIDEO_CONVERSION is enabled and it's a video)
        let tempPath = null;
        const isVideoConversionEnabled = process.env['VIDEO_CONVERSION'] === 'true';
        
        if (isVideoConversionEnabled && file.fieldname === 'video') {
          const tempDir = require('path').join(process.cwd(), 'temp', 'videos');
          await require('fs').promises.mkdir(tempDir, { recursive: true });
          tempPath = require('path').join(tempDir, filename);
          await require('fs').promises.writeFile(tempPath, buffer);
          console.log(`💾 Saved temp copy for processing: ${tempPath}`);
        } else if (!isVideoConversionEnabled && file.fieldname === 'video') {
          console.log('⚠️  VIDEO_CONVERSION=false - Skipping temp file creation');
        }
        
        cb(null, {
          bucket: BUCKET_NAME,
          key: key,
          fileDirectory: fileDirectory,
          filename: filename,
          size: buffer.length,
          mimetype: file.mimetype,
          originalname: file.originalname,
          tempPath: tempPath, // Will be null if VIDEO_CONVERSION is false
        });
      } catch (error) {
        console.log('❌ Error uploading to S3/R2:', error);
        cb(error);
      }
    });
    
    file.stream.on('error', (error: any) => {
      cb(error);
    });
  } catch (error) {
    cb(error);
  }
}

// Video file filter - handles both video and thumbnail uploads
export const videoFileFilter = (_req: any, file: any, cb: any) => {
  const ext = '.' + file.originalname.split('.').pop()?.toLowerCase();
  const mimetype = file.mimetype?.toLowerCase();
  
  console.log('🎬 File filter check:', {
    fieldname: file.fieldname,
    originalname: file.originalname,
    extension: ext,
    mimetype: mimetype,
  });
  
  // If it's a thumbnail, check image formats
  if (file.fieldname === 'thumbnail') {
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
    const imageMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
    
    if (imageExtensions.includes(ext) || (mimetype && (imageMimeTypes.includes(mimetype) || mimetype.startsWith('image/')))) {
      console.log('✅ Thumbnail image accepted');
      cb(null, true);
    } else {
      console.log('❌ Thumbnail image rejected');
      cb(new Error(`Only image files are allowed for thumbnails: ${imageExtensions.join(', ')}`));
    }
    return;
  }
  
  // If it's a subtitle, check subtitle formats
  if (file.fieldname.startsWith('subtitle_')) {
    const subtitleExtensions = ['.srt', '.vtt', '.ass', '.ssa'];
    const subtitleMimeTypes = ['text/plain', 'text/srt', 'text/vtt', 'application/x-subrip'];
    
    if (subtitleExtensions.includes(ext) || (mimetype && (subtitleMimeTypes.includes(mimetype) || mimetype.startsWith('text/')))) {
      console.log('✅ Subtitle file accepted');
      cb(null, true);
    } else {
      console.log('❌ Subtitle file rejected');
      cb(new Error(`Only subtitle files are allowed: ${subtitleExtensions.join(', ')}`));
    }
    return;
  }
  
  // If it's a video, check video formats
  const allowedExtensions = (process.env['ALLOWED_VIDEO_EXTENSIONS'] || '.mp4,.mkv,.m4v,.mov,.webm,.avi,.flv,.wmv').split(',');
  const allowedMimeTypes = (process.env['ALLOWED_VIDEO_TYPES'] || 'video/mp4,video/webm,video/quicktime,video/x-matroska,video/x-m4v').split(',');
  
  // Allow if either extension OR mimetype matches
  if (allowedExtensions.includes(ext) || (mimetype && (allowedMimeTypes.includes(mimetype) || mimetype.startsWith('video/')))) {
    console.log('✅ Video file accepted');
    cb(null, true);
  } else {
    console.log('❌ Video file rejected');
    cb(new Error(`Only video files are allowed: ${allowedExtensions.join(', ')}`));
  }
};

// Video upload instance
export const videoUpload = multer({
  storage: videoStorage,
  limits: {
    fileSize: parseInt(process.env['MAX_FILE_SIZE']?.replace('MB', '') || '5000') * 1024 * 1024,
  },
  fileFilter: videoFileFilter,
});

// Community post file storage
const communityPostStorage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, '/tmp/'); // Temporary directory for processing
  },
  filename: (_req, file, cb) => {
    const uniqueId = uuidv4();
    const extension = file.originalname.split('.').pop();
    cb(null, `${uniqueId}.${extension}`);
  },
});

// Community post file filter - allow images and videos
const communityPostFileFilter = (_req: any, file: any, cb: any) => {
  const allowedImageTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/octet-stream'];
  const allowedVideoTypes = ['video/mp4', 'video/webm', 'video/quicktime', 'video/avi', 'video/mov'];
  const allowedTypes = [...allowedImageTypes, ...allowedVideoTypes];
  
  // Get file extension
  const fileExtension = file.originalname.split('.').pop()?.toLowerCase();
  const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'mp4', 'webm', 'mov', 'avi'];
  
  // Check MIME type or file extension
  if (allowedTypes.includes(file.mimetype) || (fileExtension && allowedExtensions.includes(fileExtension))) {
    cb(null, true);
  } else {
    cb(new Error(`File type ${file.mimetype} (${fileExtension}) not allowed. Only images and videos are permitted.`));
  }
};

// Community post upload instance
export const communityPostUpload = multer({
  storage: communityPostStorage,
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB limit for community post files
    files: 10, // Maximum 10 files per post
  },
  fileFilter: communityPostFileFilter,
});

// Upload community post files to S3
export const uploadCommunityPostFiles = async (files: Express.Multer.File[], postId: string): Promise<{
  fileDirectory: string;
  images: string[];
  videos: string[];
  videoThumbnails: string[];
  durations: string[];
}> => {
  const today = new Date();
  const fileDirectory = `${today.getFullYear()}/${String(today.getMonth() + 1).padStart(2, '0')}/${String(today.getDate()).padStart(2, '0')}/${postId}`;

  const images: string[] = [];
  const videos: string[] = [];
  const videoThumbnails: string[] = [];
  const durations: string[] = [];
  
  console.log(`📦 Processing ${files.length} files for post ${postId}`);
  
  // Map to track original video filenames to their UUIDs
  const videoOriginalToUuid = new Map<string, string>();

  // First pass: process videos only
  console.log('🎬 FIRST PASS: Processing videos...');
  for (const file of files) {
    const fileExtension = file.originalname.split('.').pop();
    const ext = fileExtension?.toLowerCase();
    const isVideo = file.mimetype.startsWith('video/') ||
                   (ext && ['mp4', 'webm', 'mov', 'avi'].includes(ext));
    
    console.log(`   File: ${file.originalname}, MIME: ${file.mimetype}, isVideo: ${isVideo}`);
    
    if (isVideo) {
      const videoUuid = uuidv4();
      const fileName = `${videoUuid}.${fileExtension}`;
      const s3Key = `community-posts/${fileDirectory}/${fileName}`;
      
      // Store mapping of original filename (without extension) to UUID
      const originalBaseName = file.originalname.split('.').slice(0, -1).join('.');
      videoOriginalToUuid.set(originalBaseName, videoUuid);

      try {
        const uploadCommand = new PutObjectCommand({
          Bucket: BUCKET_NAME,
          Key: s3Key,
          Body: require('fs').readFileSync(file.path),
          ContentType: file.mimetype,
        });
        await s3Client.send(uploadCommand);
        
        videos.push(fileName);
        durations.push('0'); // Placeholder, will be updated from mobile app data
        
        console.log(`✅ Uploaded video: ${fileName} (original: ${file.originalname})`);
      } catch (error) {
        console.error('Error uploading video to S3:', error);
        throw error;
      }
    }
  }

  // Second pass: process images (thumbnails and regular images)
  console.log('🖼️  SECOND PASS: Processing images...');
  console.log(`   Video UUID map has ${videoOriginalToUuid.size} entries`);
  
  for (const file of files) {
    const fileExtension = file.originalname.split('.').pop();
    const ext = fileExtension?.toLowerCase();
    
    // Check if it's an image by MIME type OR file extension
    const isImageByMime = file.mimetype.startsWith('image/') || file.mimetype === 'application/octet-stream';
    const isImageByExt = ext && ['jpg', 'jpeg', 'png', 'webp', 'gif'].includes(ext);
    const isImage = isImageByMime && isImageByExt;
    
    console.log(`   File: ${file.originalname}, MIME: ${file.mimetype}, isImage: ${isImage}`);
    
    if (isImage) {
      // Check if this is a video thumbnail by matching original filename
      const originalBaseName = file.originalname.split('.').slice(0, -1).join('.');
      const matchingVideoUuid = videoOriginalToUuid.get(originalBaseName);
      
      console.log(`      Base name: "${originalBaseName}", Match: ${matchingVideoUuid ? 'YES (thumbnail)' : 'NO (regular image)'}`);
      
      if (matchingVideoUuid) {
        // This is a video thumbnail - upload with same UUID as video
        const fileName = `${matchingVideoUuid}.jpg`;
        const s3Key = `community-posts/${fileDirectory}/${fileName}`;
        
        try {
          const uploadCommand = new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: s3Key,
            Body: require('fs').readFileSync(file.path),
            ContentType: 'image/jpeg', // Force JPEG content type for thumbnails
          });
          await s3Client.send(uploadCommand);
          
          // Add thumbnail filename to videoThumbnails array
          videoThumbnails.push(fileName);
          
          console.log(`✅ Uploaded video thumbnail: ${fileName} (for video: ${matchingVideoUuid}.mp4)`);
        } catch (error) {
          console.error('Error uploading thumbnail to S3:', error);
          throw error;
        }
      } else {
        // This is a regular image
        const fileName = `${uuidv4()}.${fileExtension}`;
        const s3Key = `community-posts/${fileDirectory}/${fileName}`;
        
        try {
          const uploadCommand = new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: s3Key,
            Body: require('fs').readFileSync(file.path),
            ContentType: file.mimetype,
          });
          await s3Client.send(uploadCommand);
          
          images.push(fileName);
          console.log(`✅ Uploaded image: ${fileName}`);
        } catch (error) {
          console.error('Error uploading image to S3:', error);
          throw error;
        }
      }
    }
  }

  // Clean up all temporary files
  for (const file of files) {
    try {
      require('fs').unlinkSync(file.path);
    } catch (error) {
      console.error('Error cleaning up temp file:', error);
    }
  }

          console.log(`📊 Upload Summary:`);
          console.log(`   Images: ${images.length} (${images.join(', ')})`);
          console.log(`   Videos: ${videos.length} (${videos.join(', ')})`);
          console.log(`   Video Thumbnails: ${videoThumbnails.length} (${videoThumbnails.join(', ')})`);
          console.log(`   Durations: ${durations.length} (${durations.join(', ')})`);

          return {
            fileDirectory, // Just yyyy/mm/dd/postId format
            images,
            videos,
            videoThumbnails,
            durations,
          };
};

export default s3Client;
