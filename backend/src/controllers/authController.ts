import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { UserModel } from '../models/User';
import { redisClient } from '../config/database';

export class AuthController {
  private userModel: UserModel;

  constructor() {
    this.userModel = new UserModel(pool);
  }

  /**
   * Register a new user
   */
  register = async (req: Request, res: Response): Promise<void> => {
    try {
      const { username, email, password, first_name, last_name, bio } = req.body;

      // Validation
      if (!username || !email || !password) {
        res.status(400).json({
          success: false,
          message: 'Username, email, and password are required',
        });
        return;
      }

      if (password.length < 6) {
        res.status(400).json({
          success: false,
          message: 'Password must be at least 6 characters long',
        });
        return;
      }

      // Check if user already exists
      const existingUser = await this.userModel.findByEmail(email);
      if (existingUser) {
        res.status(409).json({
          success: false,
          message: 'User with this email already exists',
        });
        return;
      }

      const existingUsername = await this.userModel.findByUsername(username);
      if (existingUsername) {
        res.status(409).json({
          success: false,
          message: 'Username already taken',
        });
        return;
      }

      // Hash password
      const saltRounds = 12;
      const passwordHash = await bcrypt.hash(password, saltRounds);

      // Create user
      const userData = {
        username,
        email,
        password: passwordHash,
        first_name,
        last_name,
        bio,
      };

      const user = await this.userModel.create(userData);

      // Generate tokens
      const accessToken = this.generateAccessToken(user);
      const refreshToken = this.generateRefreshToken(user);

      // Store refresh token in Redis
      await redisClient.setEx(
        `refresh_token:${user.id}`,
        7 * 24 * 60 * 60, // 7 days
        refreshToken
      );

      // Remove password from response
      const { password_hash, ...userResponse } = user;

      res.status(201).json({
        success: true,
        message: 'User registered successfully',
        data: {
          user: userResponse,
          accessToken,
          refreshToken,
        },
      });
    } catch (error) {
      console.error('Registration error:', error);
      res.status(500).json({
        success: false,
        message: 'Registration failed',
      });
    }
  };

  /**
   * Login user
   */
  login = async (req: Request, res: Response): Promise<void> => {
    try {
      const { email, password } = req.body;

      // Validation
      if (!email || !password) {
        res.status(400).json({
          success: false,
          message: 'Email and password are required',
        });
        return;
      }

      // Find user
      const user = await this.userModel.findByEmail(email);
      if (!user) {
        res.status(401).json({
          success: false,
          message: 'Invalid credentials',
        });
        return;
      }

      // Check if user is active
      if (!user.is_active) {
        res.status(401).json({
          success: false,
          message: 'Account is deactivated',
        });
        return;
      }

      // Verify password
      const isValidPassword = await bcrypt.compare(password, user.password_hash);
      if (!isValidPassword) {
        res.status(401).json({
          success: false,
          message: 'Invalid credentials',
        });
        return;
      }

      // Generate tokens
      const accessToken = this.generateAccessToken(user);
      const refreshToken = this.generateRefreshToken(user);

      // Store refresh token in Redis
      await redisClient.setEx(
        `refresh_token:${user.id}`,
        7 * 24 * 60 * 60, // 7 days
        refreshToken
      );

      // Remove password from response
      const { password_hash, ...userResponse } = user;

      res.json({
        success: true,
        message: 'Login successful',
        data: {
          user: userResponse,
          accessToken,
          refreshToken,
        },
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({
        success: false,
        message: 'Login failed',
      });
    }
  };

  /**
   * Refresh access token
   */
  refreshToken = async (req: Request, res: Response): Promise<void> => {
    try {
      const { refreshToken } = req.body;

      if (!refreshToken) {
        res.status(400).json({
          success: false,
          message: 'Refresh token required',
        });
        return;
      }

      // Verify refresh token
      const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET!) as any;
      
      // Check if refresh token exists in Redis
      const storedToken = await redisClient.get(`refresh_token:${decoded.id}`);
      if (!storedToken || storedToken !== refreshToken) {
        res.status(401).json({
          success: false,
          message: 'Invalid refresh token',
        });
        return;
      }

      // Get user
      const user = await this.userModel.findById(decoded.id);
      if (!user || !user.is_active) {
        res.status(401).json({
          success: false,
          message: 'User not found or inactive',
        });
        return;
      }

      // Generate new access token
      const newAccessToken = this.generateAccessToken(user);

      res.json({
        success: true,
        message: 'Token refreshed successfully',
        data: {
          accessToken: newAccessToken,
        },
      });
    } catch (error) {
      if (error instanceof jwt.JsonWebTokenError) {
        res.status(401).json({
          success: false,
          message: 'Invalid refresh token',
        });
        return;
      }

      console.error('Refresh token error:', error);
      res.status(500).json({
        success: false,
        message: 'Token refresh failed',
      });
    }
  };

  /**
   * Logout user
   */
  logout = async (req: Request, res: Response): Promise<void> => {
    try {
      const { refreshToken } = req.body;

      if (refreshToken) {
        // Remove refresh token from Redis
        const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET!) as any;
        await redisClient.del(`refresh_token:${decoded.id}`);
      }

      res.json({
        success: true,
        message: 'Logout successful',
      });
    } catch (error) {
      console.error('Logout error:', error);
      res.status(500).json({
        success: false,
        message: 'Logout failed',
      });
    }
  };

  /**
   * Get current user profile
   */
  getProfile = async (req: any, res: Response): Promise<void> => {
    try {
      const user = await this.userModel.findById(req.user.id);
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
        data: userResponse,
      });
    } catch (error) {
      console.error('Get profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get profile',
      });
    }
  };

  /**
   * Change password
   */
  changePassword = async (req: any, res: Response): Promise<void> => {
    try {
      const { currentPassword, newPassword } = req.body;

      if (!currentPassword || !newPassword) {
        res.status(400).json({
          success: false,
          message: 'Current password and new password are required',
        });
        return;
      }

      if (newPassword.length < 6) {
        res.status(400).json({
          success: false,
          message: 'New password must be at least 6 characters long',
        });
        return;
      }

      // Get user
      const user = await this.userModel.findById(req.user.id);
      if (!user) {
        res.status(404).json({
          success: false,
          message: 'User not found',
        });
        return;
      }

      // Verify current password
      const isValidPassword = await bcrypt.compare(currentPassword, user.password_hash);
      if (!isValidPassword) {
        res.status(401).json({
          success: false,
          message: 'Current password is incorrect',
        });
        return;
      }

      // Hash new password
      const saltRounds = 12;
      const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

      // Update password
      const updateQuery = 'UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2';
      await pool.query(updateQuery, [newPasswordHash, req.user.id]);

      res.json({
        success: true,
        message: 'Password changed successfully',
      });
    } catch (error) {
      console.error('Change password error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to change password',
      });
    }
  };

  /**
   * Generate access token
   */
  private generateAccessToken(user: any): string {
    return jwt.sign(
      {
        id: user.id,
        username: user.username,
        email: user.email,
      },
      process.env.JWT_SECRET!,
      { expiresIn: process.env.JWT_EXPIRES_IN || '15m' }
    );
  }

  /**
   * Generate refresh token
   */
  private generateRefreshToken(user: any): string {
    return jwt.sign(
      {
        id: user.id,
        username: user.username,
        email: user.email,
      },
      process.env.JWT_REFRESH_SECRET!,
      { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' }
    );
  }
}
