import { Request, Response } from 'express';
import { UserModel } from '../models/User';
import { pool } from '../config/database';
import { StorageService } from '../config/storage';
import { AuthRequest } from '../middleware/auth';

export class UserController {
  private userModel: UserModel;

  constructor() {
    this.userModel = new UserModel(pool);
  }

  /**
   * Get user profile
   */
  getProfile = async (req: Request, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;
      const currentUserId = req.headers['x-user-id'] as string;

      const profile = await this.userModel.getProfile(userId, currentUserId);
      if (!profile) {
        res.status(404).json({
          success: false,
          message: 'User not found',
        });
        return;
      }

      res.json({
        success: true,
        data: profile,
      });
    } catch (error) {
      console.error('Get profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get user profile',
      });
    }
  };

  /**
   * Update user profile
   */
  updateProfile = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { first_name, last_name, bio } = req.body;

      const updateData = {
        first_name,
        last_name,
        bio,
      };

      const user = await this.userModel.update(req.user!.id, updateData);
      if (!user) {
        res.status(404).json({
          success: false,
          message: 'User not found',
        });
        return;
      }

      // Remove password from response
      const { password_hash, ...userResponse } = user;

      res.json({
        success: true,
        message: 'Profile updated successfully',
        data: userResponse,
      });
    } catch (error) {
      console.error('Update profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to update profile',
      });
    }
  };

  /**
   * Upload profile picture
   */
  uploadAvatar = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      if (!req.file) {
        res.status(400).json({
          success: false,
          message: 'No image file uploaded',
        });
        return;
      }

      // Upload avatar to S3
      const avatarResult = await StorageService.uploadFile(req.file, 'avatars');
      
      // Update user avatar
      const user = await this.userModel.update(req.user!.id, {
        avatar_url: avatarResult.url,
      });

      if (!user) {
        res.status(404).json({
          success: false,
          message: 'User not found',
        });
        return;
      }

      // Remove password from response
      const { password_hash, ...userResponse } = user;

      res.json({
        success: true,
        message: 'Avatar uploaded successfully',
        data: userResponse,
      });
    } catch (error) {
      console.error('Upload avatar error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to upload avatar',
      });
    }
  };

  /**
   * Search users
   */
  searchUsers = async (req: Request, res: Response): Promise<void> => {
    try {
      const { q, page = 1, limit = 20 } = req.query;
      
      if (!q) {
        res.status(400).json({
          success: false,
          message: 'Search query is required',
        });
        return;
      }

      const offset = (Number(page) - 1) * Number(limit);
      const users = await this.userModel.search(q as string, Number(limit), offset);

      res.json({
        success: true,
        data: users,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: users.length,
        },
      });
    } catch (error) {
      console.error('Search users error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to search users',
      });
    }
  };

  /**
   * Get user's followers
   */
  getFollowers = async (req: Request, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;
      const { page = 1, limit = 20 } = req.query;
      
      const offset = (Number(page) - 1) * Number(limit);
      const followers = await this.userModel.getFollowers(userId, Number(limit), offset);

      res.json({
        success: true,
        data: followers,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: followers.length,
        },
      });
    } catch (error) {
      console.error('Get followers error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get followers',
      });
    }
  };

  /**
   * Get user's following
   */
  getFollowing = async (req: Request, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;
      const { page = 1, limit = 20 } = req.query;
      
      const offset = (Number(page) - 1) * Number(limit);
      const following = await this.userModel.getFollowing(userId, Number(limit), offset);

      res.json({
        success: true,
        data: following,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: following.length,
        },
      });
    } catch (error) {
      console.error('Get following error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get following',
      });
    }
  };

  /**
   * Follow user
   */
  followUser = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;

      if (userId === req.user!.id) {
        res.status(400).json({
          success: false,
          message: 'You cannot follow yourself',
        });
        return;
      }

      // Check if user exists
      const targetUser = await this.userModel.findById(userId);
      if (!targetUser) {
        res.status(404).json({
          success: false,
          message: 'User not found',
        });
        return;
      }

      // Check if already following
      const existingFollow = await pool.query(
        'SELECT id FROM follows WHERE follower_id = $1 AND following_id = $2',
        [req.user!.id, userId]
      );

      if (existingFollow.rows.length > 0) {
        res.status(400).json({
          success: false,
          message: 'You are already following this user',
        });
        return;
      }

      // Create follow relationship
      await pool.query(
        'INSERT INTO follows (follower_id, following_id) VALUES ($1, $2)',
        [req.user!.id, userId]
      );

      res.json({
        success: true,
        message: 'User followed successfully',
      });
    } catch (error) {
      console.error('Follow user error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to follow user',
      });
    }
  };

  /**
   * Unfollow user
   */
  unfollowUser = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;

      // Check if following relationship exists
      const existingFollow = await pool.query(
        'SELECT id FROM follows WHERE follower_id = $1 AND following_id = $2',
        [req.user!.id, userId]
      );

      if (existingFollow.rows.length === 0) {
        res.status(400).json({
          success: false,
          message: 'You are not following this user',
        });
        return;
      }

      // Remove follow relationship
      await pool.query(
        'DELETE FROM follows WHERE follower_id = $1 AND following_id = $2',
        [req.user!.id, userId]
      );

      res.json({
        success: true,
        message: 'User unfollowed successfully',
      });
    } catch (error) {
      console.error('Unfollow user error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to unfollow user',
      });
    }
  };

  /**
   * Check if following user
   */
  isFollowing = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;

      const follow = await pool.query(
        'SELECT id FROM follows WHERE follower_id = $1 AND following_id = $2',
        [req.user!.id, userId]
      );

      res.json({
        success: true,
        data: {
          isFollowing: follow.rows.length > 0,
        },
      });
    } catch (error) {
      console.error('Check following error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to check following status',
      });
    }
  };

  /**
   * Get user stats
   */
  getUserStats = async (req: Request, res: Response): Promise<void> => {
    try {
      const { userId } = req.params;

      // Get user profile with stats
      const profile = await this.userModel.getProfile(userId);
      if (!profile) {
        res.status(404).json({
          success: false,
          message: 'User not found',
        });
        return;
      }

      res.json({
        success: true,
        data: {
          followers_count: profile.followers_count,
          following_count: profile.following_count,
          videos_count: profile.videos_count,
          posts_count: profile.posts_count,
        },
      });
    } catch (error) {
      console.error('Get user stats error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get user stats',
      });
    }
  };

  /**
   * Get suggested users
   */
  getSuggestedUsers = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { limit = 10 } = req.query;

      // Get users that the current user is not following
      const query = `
        SELECT 
          u.id,
          u.username,
          u.first_name,
          u.last_name,
          u.bio,
          u.avatar_url,
          u.is_verified,
          u.created_at,
          COALESCE(followers.count, 0) as followers_count,
          COALESCE(following.count, 0) as following_count,
          COALESCE(videos.count, 0) as videos_count,
          COALESCE(posts.count, 0) as posts_count
        FROM users u
        LEFT JOIN (
          SELECT following_id, COUNT(*) as count
          FROM follows
          GROUP BY following_id
        ) followers ON u.id = followers.following_id
        LEFT JOIN (
          SELECT follower_id, COUNT(*) as count
          FROM follows
          GROUP BY follower_id
        ) following ON u.id = following.follower_id
        LEFT JOIN (
          SELECT user_id, COUNT(*) as count
          FROM videos
          WHERE is_public = true
          GROUP BY user_id
        ) videos ON u.id = videos.user_id
        LEFT JOIN (
          SELECT user_id, COUNT(*) as count
          FROM community_posts
          WHERE is_public = true
          GROUP BY user_id
        ) posts ON u.id = posts.user_id
        WHERE u.id != $1 
          AND u.is_active = true
          AND u.id NOT IN (
            SELECT following_id FROM follows WHERE follower_id = $1
          )
        ORDER BY (followers.count + videos.count + posts.count) DESC
        LIMIT $2
      `;

      const result = await pool.query(query, [req.user!.id, Number(limit)]);
      const users = result.rows;

      res.json({
        success: true,
        data: users,
      });
    } catch (error) {
      console.error('Get suggested users error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get suggested users',
      });
    }
  };

  /**
   * Delete user account
   */
  deleteAccount = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { password } = req.body;

      if (!password) {
        res.status(400).json({
          success: false,
          message: 'Password is required to delete account',
        });
        return;
      }

      // Get user and verify password
      const user = await this.userModel.findById(req.user!.id);
      if (!user) {
        res.status(404).json({
          success: false,
          message: 'User not found',
        });
        return;
      }

      // Note: In a real application, you would verify the password here
      // For now, we'll just delete the account
      
      // Soft delete user
      const deleted = await this.userModel.delete(req.user!.id);
      if (!deleted) {
        res.status(500).json({
          success: false,
          message: 'Failed to delete account',
        });
        return;
      }

      res.json({
        success: true,
        message: 'Account deleted successfully',
      });
    } catch (error) {
      console.error('Delete account error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to delete account',
      });
    }
  };
}
