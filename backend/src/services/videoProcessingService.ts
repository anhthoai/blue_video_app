import ffmpeg from 'fluent-ffmpeg';
import { promises as fs } from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

// Set ffmpeg path if specified in environment
if (process.env['FFMPEG_PATH']) {
  ffmpeg.setFfmpegPath(process.env['FFMPEG_PATH']);
  console.log('🎬 FFmpeg path set to:', process.env['FFMPEG_PATH']);
}

if (process.env['FFPROBE_PATH']) {
  ffmpeg.setFfprobePath(process.env['FFPROBE_PATH']);
  console.log('🎬 FFprobe path set to:', process.env['FFPROBE_PATH']);
}

const BUCKET_NAME = process.env['S3_BUCKET_NAME'] || 'blue-video-storage';

// S3 Client configuration
const s3Config: any = {
  region: process.env['S3_REGION'] || 'auto',
  credentials: {
    accessKeyId: process.env['S3_ACCESS_KEY_ID'] || '',
    secretAccessKey: process.env['S3_SECRET_ACCESS_KEY'] || '',
  },
};

if (process.env['S3_ENDPOINT']) {
  s3Config.endpoint = process.env['S3_ENDPOINT'];
  s3Config.forcePathStyle = true;
}

const s3Client = new S3Client(s3Config);

export interface VideoMetadata {
  duration: number;
  width: number;
  height: number;
  format: string;
  bitrate: number;
  fps: number;
  hasAudio: boolean;
  audioCodec: string | undefined;
  videoCodec: string | undefined;
}

export interface ThumbnailResult {
  thumbnailUrls: string[]; // S3 keys
  thumbnailFiles: { key: string; buffer: Buffer }[];
}

/**
 * Extract video metadata using ffmpeg
 */
export async function extractVideoMetadata(videoPath: string): Promise<VideoMetadata> {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(videoPath, (err, metadata) => {
      if (err) {
        console.error('❌ Error extracting video metadata:', err);
        reject(err);
        return;
      }

      try {
        const videoStream = metadata.streams.find(s => s.codec_type === 'video');
        const audioStream = metadata.streams.find(s => s.codec_type === 'audio');

        if (!videoStream) {
          reject(new Error('No video stream found'));
          return;
        }

        const result: VideoMetadata = {
          duration: metadata.format.duration || 0,
          width: videoStream.width || 0,
          height: videoStream.height || 0,
          format: metadata.format.format_name || 'unknown',
          bitrate: metadata.format.bit_rate ? parseInt(metadata.format.bit_rate.toString()) : 0,
          fps: videoStream.r_frame_rate 
            ? eval(videoStream.r_frame_rate.replace('/', '/')) // e.g., "30/1" -> 30
            : 0,
          hasAudio: !!audioStream,
          audioCodec: audioStream?.codec_name,
          videoCodec: videoStream.codec_name,
        };

        console.log('📊 Video metadata extracted:', {
          duration: `${result.duration}s`,
          resolution: `${result.width}x${result.height}`,
          fps: result.fps,
          format: result.format,
          hasAudio: result.hasAudio,
        });

        resolve(result);
      } catch (error) {
        console.error('❌ Error parsing video metadata:', error);
        reject(error);
      }
    });
  });
}

/**
 * Generate 5 thumbnails at different timestamps
 * Returns local file paths
 */
export async function generateThumbnails(
  videoPath: string,
  outputDir: string,
  count: number = 5
): Promise<string[]> {
  // Create output directory if it doesn't exist
  await fs.mkdir(outputDir, { recursive: true });

  // Get video duration first
  const metadata = await extractVideoMetadata(videoPath);
  const duration = metadata.duration;

  if (duration <= 0) {
    throw new Error('Invalid video duration');
  }

  console.log(`🖼️  Generating ${count} thumbnails from ${duration}s video...`);

  // Calculate timestamps for thumbnails (evenly distributed)
  const timestamps: string[] = [];
  for (let i = 0; i < count; i++) {
    // Skip first 5% and last 5% of video to avoid black frames
    const position = 0.05 + (i / (count - 1)) * 0.9;
    const timestamp = duration * position;
    timestamps.push(timestamp.toFixed(2));
  }

  console.log('📍 Thumbnail timestamps:', timestamps.map(t => `${t}s`).join(', '));

  // Generate thumbnails
  const thumbnailPaths: string[] = [];

  for (let i = 0; i < timestamps.length; i++) {
    const timestamp = timestamps[i];
    if (!timestamp) {
      console.error(`⚠️  Invalid timestamp at index ${i}`);
      continue;
    }
    
    const filename = `thumbnail_${i + 1}_${uuidv4()}.jpg`;
    const outputPath = path.join(outputDir, filename);

    await new Promise<void>((resolve, reject) => {
      ffmpeg(videoPath)
        .seekInput(parseFloat(timestamp))
        .outputOptions([
          '-vframes 1', // Extract 1 frame
          '-q:v 2', // High quality (2-5 is good, lower is better)
          '-vf scale=640:-1', // Scale to 640px width, maintain aspect ratio
        ])
        .output(outputPath)
        .on('end', () => {
          console.log(`✅ Thumbnail ${i + 1}/${count} generated: ${filename}`);
          thumbnailPaths.push(outputPath);
          resolve();
        })
        .on('error', (err) => {
          console.error(`❌ Error generating thumbnail ${i + 1}:`, err);
          reject(err);
        })
        .run();
    });
  }

  return thumbnailPaths;
}

/**
 * Upload thumbnails to S3/R2
 */
export async function uploadThumbnailsToS3(
  thumbnailPaths: string[],
  fileDirectory: string
): Promise<string[]> {
  const s3Keys: string[] = [];

  for (const thumbnailPath of thumbnailPaths) {
    const filename = path.basename(thumbnailPath);
    const key = `thumbnails/${fileDirectory}/${filename}`;

    // Read file buffer
    const buffer = await fs.readFile(thumbnailPath);

    // Upload to S3
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: buffer,
      ContentType: 'image/jpeg',
    });

    await s3Client.send(command);
    console.log(`☁️  Thumbnail uploaded to S3: ${key}`);

    s3Keys.push(key);
  }

  return s3Keys;
}

/**
 * Clean up temporary thumbnail files
 */
export async function cleanupThumbnails(thumbnailPaths: string[]): Promise<void> {
  for (const thumbnailPath of thumbnailPaths) {
    try {
      await fs.unlink(thumbnailPath);
      console.log(`🗑️  Cleaned up: ${thumbnailPath}`);
    } catch (error) {
      console.error(`⚠️  Failed to delete ${thumbnailPath}:`, error);
    }
  }
}

/**
 * Process video: extract metadata and generate thumbnails
 */
export async function processVideo(
  videoPath: string,
  fileDirectory: string
): Promise<{ metadata: VideoMetadata; thumbnails: string[] }> {
  const tempDir = path.join(process.cwd(), 'temp', 'thumbnails', uuidv4());

  try {
    // Extract metadata
    const metadata = await extractVideoMetadata(videoPath);

    // Generate thumbnails
    const thumbnailPaths = await generateThumbnails(videoPath, tempDir, 5);

    // Upload thumbnails to S3
    const thumbnails = await uploadThumbnailsToS3(thumbnailPaths, fileDirectory);

    // Clean up local files
    await cleanupThumbnails(thumbnailPaths);

    // Clean up temp directory
    try {
      await fs.rmdir(tempDir);
    } catch (error) {
      // Ignore error if directory is not empty
    }

    return {
      metadata,
      thumbnails,
    };
  } catch (error) {
    console.error('❌ Error processing video:', error);
    // Clean up temp directory on error
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch (cleanupError) {
      // Ignore cleanup errors
    }
    throw error;
  }
}

