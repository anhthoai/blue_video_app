import { Request, Response } from 'express';
import { CommunityPostModel } from '../models/CommunityPost';
import { pool } from '../config/database';
import { StorageService } from '../config/storage';
import { AuthRequest } from '../middleware/auth';

export class CommunityController {
  private communityPostModel: CommunityPostModel;

  constructor() {
    this.communityPostModel = new CommunityPostModel(pool);
  }

  /**
   * Create a new community post
   */
  createPost = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const {
        title,
        content,
        type,
        images,
        videos,
        link_url,
        link_title,
        link_description,
        poll_options,
        tags,
        category,
      } = req.body;

      if (!type) {
        res.status(400).json({
          success: false,
          message: 'Post type is required',
        });
        return;
      }

      // Validate post type
      const validTypes = ['text', 'link', 'poll', 'media'];
      if (!validTypes.includes(type)) {
        res.status(400).json({
          success: false,
          message: 'Invalid post type',
        });
        return;
      }

      // Validate required fields based on type
      if (type === 'text' && !content) {
        res.status(400).json({
          success: false,
          message: 'Content is required for text posts',
        });
        return;
      }

      if (type === 'link' && !link_url) {
        res.status(400).json({
          success: false,
          message: 'Link URL is required for link posts',
        });
        return;
      }

      if (type === 'poll' && (!poll_options || !Array.isArray(poll_options) || poll_options.length < 2)) {
        res.status(400).json({
          success: false,
          message: 'At least 2 poll options are required',
        });
        return;
      }

      if (type === 'media' && (!images || !videos || (images.length === 0 && videos.length === 0))) {
        res.status(400).json({
          success: false,
          message: 'At least one image or video is required for media posts',
        });
        return;
      }

      const postData = {
        user_id: req.user!.id,
        title,
        content,
        type,
        images: images || [],
        videos: videos || [],
        link_url,
        link_title,
        link_description,
        poll_options,
        tags: tags || [],
        category,
      };

      const post = await this.communityPostModel.create(postData);

      res.status(201).json({
        success: true,
        message: 'Post created successfully',
        data: post,
      });
    } catch (error) {
      console.error('Create post error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to create post',
      });
    }
  };

  /**
   * Get post by ID
   */
  getPost = async (req: Request, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const currentUserId = req.headers['x-user-id'] as string;

      const post = await this.communityPostModel.findByIdWithUser(id, currentUserId);
      if (!post) {
        res.status(404).json({
          success: false,
          message: 'Post not found',
        });
        return;
      }

      // Increment views
      await this.communityPostModel.incrementViews(id);

      res.json({
        success: true,
        data: post,
      });
    } catch (error) {
      console.error('Get post error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get post',
      });
    }
  };

  /**
   * Get posts feed
   */
  getFeed = async (req: Request, res: Response): Promise<void> => {
    try {
      const { page = 1, limit = 20 } = req.query;
      const currentUserId = req.headers['x-user-id'] as string;
      
      const offset = (Number(page) - 1) * Number(limit);
      const posts = await this.communityPostModel.getFeed(currentUserId, Number(limit), offset);

      res.json({
        success: true,
        data: posts,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: posts.length,
        },
      });
    } catch (error) {
      console.error('Get feed error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get posts feed',
      });
    }
  };

  /**
   * Get trending posts
   */
  getTrending = async (req: Request, res: Response): Promise<void> => {
    try {
      const { page = 1, limit = 20 } = req.query;
      const currentUserId = req.headers['x-user-id'] as string;
      
      const offset = (Number(page) - 1) * Number(limit);
      const posts = await this.communityPostModel.getTrending(currentUserId, Number(limit), offset);

      res.json({
        success: true,
        data: posts,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: posts.length,
        },
      });
    } catch (error) {
      console.error('Get trending error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get trending posts',
      });
    }
  };

  /**
   * Search posts
   */
  searchPosts = async (req: Request, res: Response): Promise<void> => {
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
      const posts = await this.communityPostModel.search(
        q as string,
        currentUserId,
        Number(limit),
        offset
      );

      res.json({
        success: true,
        data: posts,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: posts.length,
        },
      });
    } catch (error) {
      console.error('Search posts error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to search posts',
      });
    }
  };

  /**
   * Get posts by user
   */
  getUserPosts = async (req: Request, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;
      const { page = 1, limit = 20 } = req.query;
      const currentUserId = req.headers['x-user-id'] as string;
      
      const offset = (Number(page) - 1) * Number(limit);
      const posts = await this.communityPostModel.findByUserId(
        userId,
        currentUserId,
        Number(limit),
        offset
      );

      res.json({
        success: true,
        data: posts,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: posts.length,
        },
      });
    } catch (error) {
      console.error('Get user posts error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get user posts',
      });
    }
  };

  /**
   * Get posts by category
   */
  getPostsByCategory = async (req: Request, res: Response): Promise<void> => {
    try {
      const { category } = req.params;
      const { page = 1, limit = 20 } = req.query;
      const currentUserId = req.headers['x-user-id'] as string;
      
      const offset = (Number(page) - 1) * Number(limit);
      const posts = await this.communityPostModel.getByCategory(
        category,
        currentUserId,
        Number(limit),
        offset
      );

      res.json({
        success: true,
        data: posts,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: posts.length,
        },
      });
    } catch (error) {
      console.error('Get posts by category error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get posts by category',
      });
    }
  };

  /**
   * Update post
   */
  updatePost = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const {
        title,
        content,
        images,
        videos,
        link_url,
        link_title,
        link_description,
        poll_options,
        poll_votes,
        tags,
        category,
        is_public,
      } = req.body;

      // Check if post exists and belongs to user
      const existingPost = await this.communityPostModel.findById(id);
      if (!existingPost) {
        res.status(404).json({
          success: false,
          message: 'Post not found',
        });
        return;
      }

      if (existingPost.user_id !== req.user!.id) {
        res.status(403).json({
          success: false,
          message: 'You can only update your own posts',
        });
        return;
      }

      const updateData = {
        title,
        content,
        images,
        videos,
        link_url,
        link_title,
        link_description,
        poll_options,
        poll_votes,
        tags,
        category,
        is_public,
      };

      const post = await this.communityPostModel.update(id, updateData);

      res.json({
        success: true,
        message: 'Post updated successfully',
        data: post,
      });
    } catch (error) {
      console.error('Update post error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update post',
      });
    }
  };

  /**
   * Delete post
   */
  deletePost = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;

      // Check if post exists and belongs to user
      const existingPost = await this.communityPostModel.findById(id);
      if (!existingPost) {
        res.status(404).json({
          success: false,
          message: 'Post not found',
        });
        return;
      }

      if (existingPost.user_id !== req.user!.id) {
        res.status(403).json({
          success: false,
          message: 'You can only delete your own posts',
        });
        return;
      }

      // Delete associated media files from S3
      if (existingPost.images && existingPost.images.length > 0) {
        for (const imageUrl of existingPost.images) {
          const imageKey = imageUrl.split('/').pop();
          if (imageKey) {
            await StorageService.deleteFile(`images/${imageKey}`);
          }
        }
      }

      if (existingPost.videos && existingPost.videos.length > 0) {
        for (const videoUrl of existingPost.videos) {
          const videoKey = videoUrl.split('/').pop();
          if (videoKey) {
            await StorageService.deleteFile(`videos/${videoKey}`);
          }
        }
      }

      // Delete post record
      await this.communityPostModel.delete(id);

      res.json({
        success: true,
        message: 'Post deleted successfully',
      });
    } catch (error) {
      console.error('Delete post error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to delete post',
      });
    }
  };

  /**
   * Get post stats
   */
  getPostStats = async (req: Request, res: Response): Promise<void> => {
    try {
      const { userId } = req.query;
      const stats = await this.communityPostModel.getStats(userId as string);

      res.json({
        success: true,
        data: stats,
      });
    } catch (error) {
      console.error('Get post stats error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get post stats',
      });
    }
  };

  /**
   * Get categories
   */
  getCategories = async (req: Request, res: Response): Promise<void> => {
    try {
      const categories = await this.communityPostModel.getCategories();

      res.json({
        success: true,
        data: categories,
      });
    } catch (error) {
      console.error('Get categories error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get categories',
      });
    }
  };

  /**
   * Vote on poll
   */
  votePoll = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const { option } = req.body;

      if (!option) {
        res.status(400).json({
          success: false,
          message: 'Poll option is required',
        });
        return;
      }

      // Check if post exists and is a poll
      const post = await this.communityPostModel.findById(id);
      if (!post) {
        res.status(404).json({
          success: false,
          message: 'Post not found',
        });
        return;
      }

      if (post.type !== 'poll') {
        res.status(400).json({
          success: false,
          message: 'This post is not a poll',
        });
        return;
      }

      // Update poll votes
      const currentVotes = post.poll_votes || {};
      const userVoteKey = `user_${req.user!.id}`;
      
      // Check if user already voted
      if (currentVotes[userVoteKey]) {
        res.status(400).json({
          success: false,
          message: 'You have already voted on this poll',
        });
        return;
      }

      // Add user vote
      currentVotes[userVoteKey] = option;
      
      const updateData = {
        poll_votes: currentVotes,
      };

      await this.communityPostModel.update(id, updateData);

      res.json({
        success: true,
        message: 'Vote recorded successfully',
      });
    } catch (error) {
      console.error('Vote poll error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to vote on poll',
      });
    }
  };
}
