import { Request, Response } from 'express';
import { VideoModel } from '../models/Video';
import { pool } from '../config/database';
import { StorageService } from '../config/storage';
import { AuthRequest } from '../middleware/auth';
import ffmpeg from 'fluent-ffmpeg';
import path from 'path';
import fs from 'fs';

export class VideoController {
  private videoModel: VideoModel;

  constructor() {
    this.videoModel = new VideoModel(pool);
  }

  /**
   * Upload video
   */
  uploadVideo = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      if (!req.file) {
        res.status(400).json({
          success: false,
          message: 'No video file uploaded',
        });
        return;
      }

      const { title, description } = req.body;

      if (!title) {
        res.status(400).json({
          success: false,
          message: 'Video title is required',
        });
        return;
      }

      // Upload video to S3
      const videoResult = await StorageService.uploadFile(req.file, 'videos');
      
      // Generate thumbnail
      const thumbnailResult = await this.generateThumbnail(req.file);
      
      // Get video duration and file size
      const videoInfo = await this.getVideoInfo(req.file);

      // Create video record
      const videoData = {
        user_id: req.user!.id,
        title,
        description,
        video_url: videoResult.url,
        thumbnail_url: thumbnailResult.url,
        duration: videoInfo.duration,
        file_size: videoInfo.fileSize,
        quality: videoInfo.quality,
      };

      const video = await this.videoModel.create(videoData);

      res.status(201).json({
        success: true,
        message: 'Video uploaded successfully',
        data: video,
      });
    } catch (error) {
      console.error('Video upload error:', error);
      res.status(500).json({
        success: false,
        message: 'Video upload failed',
      });
    }
  };

  /**
   * Get video by ID
   */
  getVideo = async (req: Request, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const currentUserId = req.headers['x-user-id'] as string;

      const video = await this.videoModel.findByIdWithUser(id, currentUserId);
      if (!video) {
        res.status(404).json({
          success: false,
          message: 'Video not found',
        });
        return;
      }

      // Increment views
      await this.videoModel.incrementViews(id);

      res.json({
        success: true,
        data: video,
      });
    } catch (error) {
      console.error('Get video error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get video',
      });
    }
  };

  /**
   * Get videos feed
   */
  getFeed = async (req: Request, res: Response): Promise<void> => {
    try {
      const { page = 1, limit = 20 } = req.query;
      const currentUserId = req.headers['x-user-id'] as string;
      
      const offset = (Number(page) - 1) * Number(limit);
      const videos = await this.videoModel.getFeed(currentUserId, Number(limit), offset);

      res.json({
        success: true,
        data: videos,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: videos.length,
        },
      });
    } catch (error) {
      console.error('Get feed error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get videos feed',
      });
    }
  };

  /**
   * Get trending videos
   */
  getTrending = async (req: Request, res: Response): Promise<void> => {
    try {
      const { page = 1, limit = 20 } = req.query;
      const currentUserId = req.headers['x-user-id'] as string;
      
      const offset = (Number(page) - 1) * Number(limit);
      const videos = await this.videoModel.getTrending(currentUserId, Number(limit), offset);

      res.json({
        success: true,
        data: videos,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: videos.length,
        },
      });
    } catch (error) {
      console.error('Get trending error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get trending videos',
      });
    }
  };

  /**
   * Search videos
   */
  searchVideos = async (req: Request, res: Response): Promise<void> => {
    try {
      const { q, page = 1, limit = 20 } = req.query;
      const currentUserId = req.headers['x-user-id'] as string;
      
      if (!q) {
        res.status(400).json({
          success: false,
          message: 'Search query is required',
        });
        return;
      }

      const offset = (Number(page) - 1) * Number(limit);
      const videos = await this.videoModel.search(
        q as string,
        currentUserId,
        Number(limit),
        offset
      );

      res.json({
        success: true,
        data: videos,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: videos.length,
        },
      });
    } catch (error) {
      console.error('Search videos error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to search videos',
      });
    }
  };

  /**
   * Get user's videos
   */
  getUserVideos = async (req: Request, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;
      const { page = 1, limit = 20 } = req.query;
      const currentUserId = req.headers['x-user-id'] as string;
      
      const offset = (Number(page) - 1) * Number(limit);
      const videos = await this.videoModel.findByUserId(
        userId,
        currentUserId,
        Number(limit),
        offset
      );

      res.json({
        success: true,
        data: videos,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: videos.length,
        },
      });
    } catch (error) {
      console.error('Get user videos error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get user videos',
      });
    }
  };

  /**
   * Update video
   */
  updateVideo = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const { title, description, is_public } = req.body;

      // Check if video exists and belongs to user
      const existingVideo = await this.videoModel.findById(id);
      if (!existingVideo) {
        res.status(404).json({
          success: false,
          message: 'Video not found',
        });
        return;
      }

      if (existingVideo.user_id !== req.user!.id) {
        res.status(403).json({
          success: false,
          message: 'You can only update your own videos',
        });
        return;
      }

      const updateData = {
        title,
        description,
        is_public,
      };

      const video = await this.videoModel.update(id, updateData);

      res.json({
        success: true,
        message: 'Video updated successfully',
        data: video,
      });
    } catch (error) {
      console.error('Update video error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update video',
      });
    }
  };

  /**
   * Delete video
   */
  deleteVideo = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;

      // Check if video exists and belongs to user
      const existingVideo = await this.videoModel.findById(id);
      if (!existingVideo) {
        res.status(404).json({
          success: false,
          message: 'Video not found',
        });
        return;
      }

      if (existingVideo.user_id !== req.user!.id) {
        res.status(403).json({
          success: false,
          message: 'You can only delete your own videos',
        });
        return;
      }

      // Delete video file from S3
      const videoKey = existingVideo.video_url.split('/').pop();
      if (videoKey) {
        await StorageService.deleteFile(`videos/${videoKey}`);
      }

      // Delete thumbnail file from S3
      if (existingVideo.thumbnail_url) {
        const thumbnailKey = existingVideo.thumbnail_url.split('/').pop();
        if (thumbnailKey) {
          await StorageService.deleteFile(`thumbnails/${thumbnailKey}`);
        }
      }

      // Delete video record
      await this.videoModel.delete(id);

      res.json({
        success: true,
        message: 'Video deleted successfully',
      });
    } catch (error) {
      console.error('Delete video error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to delete video',
      });
    }
  };

  /**
   * Get video stats
   */
  getVideoStats = async (req: Request, res: Response): Promise<void> => {
    try {
      const { userId } = req.query;
      const stats = await this.videoModel.getStats(userId as string);

      res.json({
        success: true,
        data: stats,
      });
    } catch (error) {
      console.error('Get video stats error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get video stats',
      });
    }
  };

  /**
   * Generate video thumbnail
   */
  private async generateThumbnail(file: Express.Multer.File): Promise<{ url: string; key: string }> {
    return new Promise((resolve, reject) => {
      const tempPath = `/tmp/${Date.now()}_${file.originalname}`;
      const thumbnailPath = `/tmp/thumb_${Date.now()}.jpg`;

      // Write file to temp location
      fs.writeFileSync(tempPath, file.buffer);

      ffmpeg(tempPath)
        .screenshots({
          timestamps: ['5%'],
          filename: path.basename(thumbnailPath),
          folder: path.dirname(thumbnailPath),
        })
        .on('end', async () => {
          try {
            // Read thumbnail file
            const thumbnailBuffer = fs.readFileSync(thumbnailPath);
            
            // Upload thumbnail to S3
            const thumbnailFile = {
              buffer: thumbnailBuffer,
              originalname: path.basename(thumbnailPath),
              mimetype: 'image/jpeg',
              size: thumbnailBuffer.length,
            } as Express.Multer.File;

            const result = await StorageService.uploadFile(thumbnailFile, 'thumbnails');
            
            // Clean up temp files
            fs.unlinkSync(tempPath);
            fs.unlinkSync(thumbnailPath);
            
            resolve(result);
          } catch (error) {
            reject(error);
          }
        })
        .on('error', (error) => {
          // Clean up temp files
          if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
          if (fs.existsSync(thumbnailPath)) fs.unlinkSync(thumbnailPath);
          reject(error);
        });
    });
  }

  /**
   * Get video information
   */
  private async getVideoInfo(file: Express.Multer.File): Promise<{
    duration: number;
    fileSize: number;
    quality: string;
  }> {
    return new Promise((resolve, reject) => {
      const tempPath = `/tmp/${Date.now()}_${file.originalname}`;
      
      // Write file to temp location
      fs.writeFileSync(tempPath, file.buffer);

      ffmpeg.ffprobe(tempPath, (err, metadata) => {
        // Clean up temp file
        if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
        
        if (err) {
          reject(err);
          return;
        }

        const duration = Math.round(metadata.format.duration || 0);
        const fileSize = file.size;
        const quality = metadata.streams[0]?.height || 720;

        resolve({
          duration,
          fileSize,
          quality: `${quality}p`,
        });
      });
    });
  }
}
