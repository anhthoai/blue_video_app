/// <reference path="./types/express.d.ts" />

// Load environment variables FIRST before any other imports
import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { emailService } from './services/emailService';
import { upload, deleteFromS3, chatFileStorage, chatFileFilter, videoUpload, communityPostUpload, uploadCommunityPostFiles } from './services/s3Service';
import { processVideo } from './services/videoProcessingService';
import { promises as fs } from 'fs';
import { serializeUserWithUrls, buildAvatarUrl, buildFileUrlSync, buildFileUrl, buildCommunityPostFileUrl } from './utils/fileUrl';
import { PrismaClient } from '@prisma/client';
import multer from 'multer';
import { paymentService, IPNNotification } from './services/paymentService';

// Initialize Prisma Client
const prisma = new PrismaClient();

const app = express();
const server = createServer(app);
const io = new SocketIOServer(server, {
  cors: {
    origin: process.env['SOCKET_CORS_ORIGIN']?.split(',') || ['http://localhost:3000'],
    methods: ['GET', 'POST'],
  },
});

const PORT = process.env['PORT'] || 3000;

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));

// CORS configuration
app.use(cors({
  origin: process.env['CORS_ORIGIN']?.split(',') || ['http://localhost:3000'],
  credentials: true,
}));

// Rate limiting (more lenient for development)
const limiter = rateLimit({
  windowMs: parseInt(process.env['RATE_LIMIT_WINDOW_MS'] || '60000'), // 1 minute
  max: parseInt(process.env['RATE_LIMIT_MAX_REQUESTS'] || '1000'), // 1000 requests per minute for development
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.',
  },
  skip: (req) => {
    // Skip rate limiting for local development IPs
    const ip = req.ip || req.connection.remoteAddress || '';
    return ip === '::1' || ip === '127.0.0.1' || ip.includes('192.168');
  },
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Compression middleware
app.use(compression());

// Logging middleware
app.use(morgan('combined'));

// Health check endpoint
app.get('/health', (_req, res) => {
  res.json({
    success: true,
    message: 'Blue Video API is running (Local Development Mode)',
    timestamp: new Date().toISOString(),
    version: process.env['API_VERSION'] || 'v1',
    mode: 'development',
    database: 'Mock (Prisma ready)',
    redis: process.env['USE_REDIS'] === 'true' ? 'Enabled' : 'Disabled',
  });
});

// Authentication middleware
const authenticateToken = async (req: any, res: any, next: any) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    console.log('🔍 Auth middleware - URL:', req.url);
    console.log('🔍 Auth middleware - Auth header:', authHeader);
    console.log('🔍 Auth middleware - Token:', token ? 'Present' : 'Missing');

    if (!token) {
      console.log('❌ No token provided');
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const JWT_SECRET = process.env['JWT_SECRET'] || 'your_super_secret_jwt_key_here';
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    
    console.log('🔍 Auth middleware - Decoded token:', decoded);
    
    // Attach user info to request
    req.user = {
      id: decoded.userId,
      email: decoded.email,
    };
    
    console.log('🔍 Auth middleware - Attached user:', req.user);
    
    next();
  } catch (error) {
    console.log('❌ Auth middleware error:', error);
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token',
    });
  }
};

// Helper to get current user ID (optional auth)
const getCurrentUserId = async (req: any): Promise<string | null> => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) return null;
    
    const JWT_SECRET = process.env['JWT_SECRET'] || 'your_super_secret_jwt_key_here';
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    return decoded.userId;
  } catch (error) {
    return null;
  }
};

// Mock API endpoints for testing
app.get('/api/v1/test', (_req, res) => {
  res.json({
    success: true,
    message: 'API is working!',
    data: {
      timestamp: new Date().toISOString(),
      environment: process.env['NODE_ENV'] || 'development',
      database: 'Mock mode - Prisma ready',
      redis: process.env['USE_REDIS'] === 'true' ? 'Enabled' : 'Disabled',
    },
  });
});

// Real authentication endpoint
app.post('/api/v1/auth/login', async (req, res) => {
  try {
    const { email, password, rememberMe } = req.body;
    
    console.log(`🔐 Login attempt - Email: ${email}`);
    
    if (!email || !password) {
      console.log('❌ Missing email or password');
      res.status(400).json({
        success: false,
        message: 'Email and password are required',
      });
      return;
    }

    // Find user by email
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      console.log(`❌ User not found: ${email}`);
      res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
      return;
    }

    console.log(`✅ User found: ${user.username} (${user.email})`);
    console.log(`🔍 User isActive: ${user.isActive}`);
    console.log(`🔍 User role: ${user.role}`);

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);

    if (!isPasswordValid) {
      console.log('❌ Invalid password');
      res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
      return;
    }

    console.log('✅ Password valid');

    // Check if user is active
    if (!user.isActive) {
      console.log('❌ Account disabled');
      res.status(403).json({
        success: false,
        message: 'Account is disabled',
      });
      return;
    }

    // Generate tokens
    const accessTokenExpiry = rememberMe ? '30d' : '24h';
    const accessToken = jwt.sign(
      { userId: user.id, email: user.email, role: user.role },
      process.env['JWT_SECRET'] || 'your-secret-key',
      { expiresIn: accessTokenExpiry }
    );

    const refreshToken = jwt.sign(
      { userId: user.id },
      process.env['REFRESH_TOKEN_SECRET'] || 'your-refresh-secret',
      { expiresIn: '90d' }
    );

    // Return user data and tokens
    console.log(`✅ Login successful for ${user.email}`);
    console.log(`🔑 Generated access token (expires in ${accessTokenExpiry})`);
    
    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          bio: user.bio,
          avatarUrl: user.avatarUrl,
          role: user.role,
          isVerified: user.isVerified,
          coinBalance: user.coinBalance,
          isVip: user.isVip,
          createdAt: user.createdAt.toISOString(),
        },
        accessToken,
        refreshToken,
      },
    });
  } catch (error) {
    console.error('❌ Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Login failed',
    });
  }
});

// Real user registration  
app.post('/api/v1/auth/register', async (req, res) => {
  try {
    const { username, email, password, firstName, lastName, bio } = req.body;
    
    if (!username || !email || !password) {
      res.status(400).json({
        success: false,
        message: 'Username, email, and password are required',
      });
      return;
    }

    // Check if user already exists
    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [
          { email },
          { username },
        ],
      },
    });

    if (existingUser) {
      res.status(409).json({
        success: false,
        message: existingUser.email === email 
          ? 'Email already registered' 
          : 'Username already taken',
      });
      return;
    }

    // Check if this is the first user (make them admin)
    const userCount = await prisma.user.count();
    const isFirstUser = userCount === 0;

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create user
    const newUser = await prisma.user.create({
      data: {
        username,
        email,
        passwordHash,
        firstName,
        lastName,
        bio,
        role: isFirstUser ? 'ADMIN' : 'USER',
        isVerified: isFirstUser, // Auto-verify admin
      },
    });

    // Generate tokens
    const accessToken = jwt.sign(
      { userId: newUser.id, email: newUser.email, role: newUser.role },
      process.env['JWT_SECRET'] || 'your-secret-key',
      { expiresIn: '24h' }
    );

    const refreshToken = jwt.sign(
      { userId: newUser.id },
      process.env['REFRESH_TOKEN_SECRET'] || 'your-refresh-secret',
      { expiresIn: '90d' }
    );

    console.log(`✅ New user registered: ${email} ${isFirstUser ? '(ADMIN)' : ''}`);

    res.status(201).json({
      success: true,
      message: `Registration successful${isFirstUser ? ' - You are the first user and have been granted admin privileges!' : ''}`,
      data: {
        user: {
          id: newUser.id,
          username: newUser.username,
          email: newUser.email,
          firstName: newUser.firstName,
          lastName: newUser.lastName,
          bio: newUser.bio,
          avatarUrl: newUser.avatarUrl,
          role: newUser.role,
          isVerified: newUser.isVerified,
          createdAt: newUser.createdAt.toISOString(),
        },
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
});

// Logout endpoint
app.post('/api/v1/auth/logout', async (_req, res) => {
  try {
    // In a real app, you might invalidate the token in a blacklist
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
});

// Forgot password endpoint
app.post('/api/v1/auth/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    
    console.log(`🔐 Password reset requested for: ${email}`);
    
    if (!email) {
      console.log('❌ No email provided');
      res.status(400).json({
        success: false,
        message: 'Email is required',
      });
      return;
    }

    // Find user by email
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      // Don't reveal if user exists or not for security
      console.log(`⚠️  User not found for email: ${email}`);
      res.json({
        success: true,
        message: 'If an account with that email exists, a password reset link has been sent.',
      });
      return;
    }

    console.log(`✅ User found: ${user.username} (${user.id})`);

    // Generate reset token (valid for 1 hour)
    const resetToken = jwt.sign(
      { userId: user.id, email: user.email, type: 'password_reset' },
      process.env['JWT_SECRET'] || 'your-secret-key',
      { expiresIn: '1h' }
    );

    console.log(`🎫 Reset token generated: ${resetToken.substring(0, 20)}...`);

    // Send email with reset link
    if (emailService.isEmailConfigured()) {
      console.log('📧 Attempting to send email...');
      const emailSent = await emailService.sendPasswordResetEmail(email, resetToken);
      if (emailSent) {
        console.log(`✅ Password reset email sent to: ${email}`);
      } else {
        console.log(`⚠️  Failed to send email, but token generated`);
      }
    } else {
      console.log('⚠️  Email service not configured, showing token in development mode');
    }

    // Always log token for testing in development
    if (process.env['NODE_ENV'] === 'development') {
      console.log(`\n${'='.repeat(80)}`);
      console.log(`📧 PASSWORD RESET TOKEN (Development Mode)`);
      console.log(`${'='.repeat(80)}`);
      console.log(`Email: ${email}`);
      console.log(`Token: ${resetToken}`);
      console.log(`Reset Link: ${process.env['FRONTEND_URL'] || 'http://localhost:8080'}/auth/reset-password?token=${resetToken}`);
      console.log(`${'='.repeat(80)}\n`);
    }

    res.json({
      success: true,
      message: 'If an account with that email exists, a password reset link has been sent.',
      // In development, return the token for testing
      ...(process.env['NODE_ENV'] === 'development' && { resetToken }),
    });
  } catch (error) {
    console.error('❌ Forgot password error:', error);
    res.status(500).json({
      success: false,
      message: 'Password reset request failed',
    });
  }
});

// Reset password endpoint
app.post('/api/v1/auth/reset-password', async (req, res) => {
  try {
    const { token, newPassword } = req.body;
    
    if (!token || !newPassword) {
      res.status(400).json({
        success: false,
        message: 'Token and new password are required',
      });
      return;
    }

    // Verify reset token
    const decoded = jwt.verify(
      token,
      process.env['JWT_SECRET'] || 'your-secret-key'
    ) as { userId: string; type: string };

    if (decoded.type !== 'password_reset') {
      res.status(400).json({
        success: false,
        message: 'Invalid reset token',
      });
      return;
    }

    // Hash new password
    const passwordHash = await bcrypt.hash(newPassword, 10);

    // Update user password
    await prisma.user.update({
      where: { id: decoded.userId },
      data: { passwordHash },
    });

    console.log(`✅ Password reset successful for user: ${decoded.userId}`);

    res.json({
      success: true,
      message: 'Password reset successful',
    });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(400).json({
      success: false,
      message: error instanceof jwt.JsonWebTokenError 
        ? 'Invalid or expired reset token'
        : 'Password reset failed',
    });
  }
});

// Mock video upload endpoint
// REMOVED: Mock upload endpoint was blocking the real upload endpoint
// The real upload endpoint with S3/R2 integration is defined later in this file

// Get user videos by user ID
app.get('/api/v1/users/:userId/videos', async (req, res) => {
  try {
    const { userId } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    
    // Get videos from database for specific user
    const videos = await prisma.video.findMany({
      where: {
        userId: userId,
        isPublic: true,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            avatar: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      skip: offset,
      take: Number(limit),
    });

    // Convert to camelCase and serialize BigInt for JSON
    const serializedVideos = videos.map(video => ({
      id: video.id,
      userId: video.userId,
      title: video.title,
      description: video.description,
      videoUrl: video.videoUrl,
      thumbnailUrl: video.thumbnailUrl,
      duration: video.duration,
      fileSize: video.fileSize ? video.fileSize.toString() : null,
      quality: video.quality,
      views: video.views,
      likes: video.likes,
      comments: video.comments,
      shares: video.shares,
      downloads: video.downloads || 0,
      isPublic: video.isPublic,
      createdAt: video.createdAt.toISOString(),
      updatedAt: video.updatedAt.toISOString(),
      // New fields for video playback
      fileName: video.fileName,
      fileDirectory: video.fileDirectory,
      remotePlayUrl: video.remotePlayUrl,
      embedCode: video.embedCode,
      cost: video.cost,
      status: video.status,
      tags: video.tags,
      subtitles: video.subtitles,
      thumbnails: video.thumbnails || [],
      user: video.user ? serializeUserWithUrls(video.user) : null,
      // Also include user data at the top level for compatibility
      username: video.user?.username,
      firstName: video.user?.firstName,
      lastName: video.user?.lastName,
      userAvatarUrl: video.user ? buildAvatarUrl(video.user) : null,
    }));

    res.json({
      success: true,
      data: serializedVideos,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: videos.length,
      },
    });
  } catch (error) {
    console.error('Error fetching user videos:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch user videos',
    });
  }
});

// Increment video view count
app.post('/api/v1/videos/:id/view', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Update video view count
    const video = await prisma.video.update({
      where: { id },
      data: {
        views: {
          increment: 1,
        },
      },
      select: {
        id: true,
        views: true,
      },
    });

    res.json({
      success: true,
      data: {
        videoId: video.id,
        views: video.views,
      },
    });
  } catch (error) {
    console.error('Error incrementing video view:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to increment video view',
    });
  }
});

// Toggle like on video
app.post('/api/v1/videos/:id/like', async (req, res) => {
  try {
    const { id } = req.params;
    const currentUserId = await getCurrentUserId(req);

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    // Check if video exists
    const video = await prisma.video.findUnique({
      where: { id },
    });

    if (!video) {
      res.status(404).json({
        success: false,
        message: 'Video not found',
      });
      return;
    }

    // Check if user has already liked this video
    const existingLike = await prisma.like.findFirst({
      where: {
        userId: currentUserId,
        targetId: id,
        targetType: 'VIDEO',
      },
    });

    let isLiked: boolean;
    let updatedVideo;

    if (existingLike) {
      // Unlike: Delete the like record
      await prisma.like.delete({
        where: { id: existingLike.id },
      });

      // Decrement like count
      updatedVideo = await prisma.video.update({
        where: { id },
        data: {
          likes: {
            decrement: 1,
          },
        },
        select: {
          id: true,
          likes: true,
        },
      });
      isLiked = false;
    } else {
      // Like: Create a like record
      await prisma.like.create({
        data: {
          userId: currentUserId,
          targetId: id,
          targetType: 'VIDEO',
          contentId: id, // Same as targetId for videos
          contentType: 'VIDEO',
          type: 'LIKE',
        },
      });

      // Increment like count
      updatedVideo = await prisma.video.update({
        where: { id },
        data: {
          likes: {
            increment: 1,
          },
        },
        select: {
          id: true,
          likes: true,
        },
      });
      isLiked = true;
    }

    res.json({
      success: true,
      data: {
        videoId: updatedVideo.id,
        likes: updatedVideo.likes,
        isLiked,
      },
    });
  } catch (error) {
    console.error('Error toggling video like:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to toggle video like',
    });
  }
});

// Increment video share count
app.post('/api/v1/videos/:id/share', async (req, res) => {
  try {
    const { id } = req.params;
    const { platform } = req.body; // Optional: track which platform was used

    // Update video share count
    const video = await prisma.video.update({
      where: { id },
      data: {
        shares: {
          increment: 1,
        },
      },
      select: {
        id: true,
        shares: true,
      },
    });

    console.log(`Video ${id} shared${platform ? ` on ${platform}` : ''}`);

    res.json({
      success: true,
      data: {
        videoId: video.id,
        shares: video.shares,
      },
    });
  } catch (error) {
    console.error('Error incrementing video share:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to increment video share',
    });
  }
});

// Increment video download count
app.post('/api/v1/videos/:id/download', async (req, res) => {
  try {
    const { id } = req.params;

    // Update video download count
    const video = await prisma.video.update({
      where: { id },
      data: {
        downloads: {
          increment: 1,
        },
      },
      select: {
        id: true,
        downloads: true,
      },
    });

    res.json({
      success: true,
      data: {
        videoId: video.id,
        downloads: video.downloads || 0,
      },
    });
  } catch (error) {
    console.error('Error incrementing video download:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to increment video download',
    });
  }
});

// Get trending videos (sorted by views)
// IMPORTANT: This must come BEFORE /api/v1/videos/:id to avoid route collision
app.get('/api/v1/videos/trending', async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    
    const videos = await prisma.video.findMany({
      where: {
        isPublic: true,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatar: true,
            avatarUrl: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
      orderBy: [
        { views: 'desc' },
        { createdAt: 'desc' },
      ],
      skip: offset,
      take: Number(limit),
    });

    const serializedVideos = videos.map(video => ({
      id: video.id,
      userId: video.userId,
      categoryId: video.categoryId,
      title: video.title,
      description: video.description,
      videoUrl: video.videoUrl,
      thumbnailUrl: video.thumbnailUrl,
      duration: video.duration,
      fileSize: video.fileSize ? video.fileSize.toString() : null,
      quality: video.quality,
      views: video.views,
      likes: video.likes,
      comments: video.comments,
      shares: video.shares,
      downloads: video.downloads,
      isPublic: video.isPublic,
      createdAt: video.createdAt.toISOString(),
      updatedAt: video.updatedAt.toISOString(),
      // New fields for video playback
      fileName: video.fileName,
      fileDirectory: video.fileDirectory,
      remotePlayUrl: video.remotePlayUrl,
      embedCode: video.embedCode,
      cost: video.cost,
      status: video.status,
      tags: video.tags,
      subtitles: video.subtitles,
      thumbnails: video.thumbnails || [],
      user: video.user ? serializeUserWithUrls(video.user) : null,
      username: video.user?.username,
      firstName: video.user?.firstName,
      lastName: video.user?.lastName,
      userAvatarUrl: video.user ? buildAvatarUrl(video.user) : null,
    }));

    res.json({
      success: true,
      data: serializedVideos,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: videos.length,
      },
    });
  } catch (error) {
    console.error('Error fetching trending videos:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch trending videos',
    });
  }
});

// Upload video
app.post('/api/v1/videos/upload', authenticateToken, videoUpload.any(), async (req: any, res) => {
  console.log('🎬 ========== VIDEO UPLOAD REQUEST RECEIVED ==========');
  console.log('🎬 Timestamp:', new Date().toISOString());
  
  try {
    const userId = req.user?.id;
    console.log('👤 User ID from token:', userId);
    
    if (!userId) {
      console.log('❌ No user ID - authentication failed');
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    const files = req.files as Express.Multer.File[];
    const videoFile = files.find(f => f.fieldname === 'video');
    const thumbnailFile = files.find(f => f.fieldname === 'thumbnail');
    const subtitleFiles = files.filter(f => f.fieldname.startsWith('subtitle_'));

    console.log('📁 Video file received:', videoFile ? 'YES' : 'NO');
    console.log('📁 Thumbnail file received:', thumbnailFile ? 'YES' : 'NO');
    console.log('📁 Subtitle files received:', subtitleFiles.length);

    if (!videoFile) {
      console.log('❌ No video file in request');
      return res.status(400).json({
        success: false,
        message: 'Video file is required',
      });
    }

    const {
      title,
      description,
      categoryId,
      tags,
      cost,
      status,
      duration,
      subtitles,
    } = req.body;
    
    console.log('📝 Request body:', { title, description, categoryId, tags, cost, status, duration, subtitles });

    // Parse tags
    const tagsArray = tags ? tags.split(',').map((tag: string) => tag.trim()) : [];
    
    // Parse subtitle languages
    const subtitleLanguages = subtitles ? subtitles.split(',').map((lang: string) => lang.trim()) : [];

    console.log('📹 Creating video record:', {
      userId,
      title,
      description,
      categoryId,
      fileName: (videoFile as any).filename,
      fileDirectory: (videoFile as any).fileDirectory,
      thumbnailUploaded: thumbnailFile ? 'YES (will use same filename as video)' : 'NO',
      duration,
      fileSize: videoFile.size,
      tags: tagsArray,
      cost,
      status: status || 'PUBLIC',
    });

    // Create video record
    // Note: thumbnailUrl is left empty - frontend will calculate it as thumbnails/{fileDirectory}/{fileName}
    // Only set thumbnailUrl if there's a custom thumbnail URL different from the default pattern
    const video = await prisma.video.create({
      data: {
        userId,
        title,
        description: description || null,
        categoryId: categoryId || null,
        fileName: (videoFile as any).filename,
        fileDirectory: (videoFile as any).fileDirectory,
        thumbnailUrl: null, // Leave empty - frontend will use thumbnails/{fileDirectory}/{fileName}
        duration: duration ? parseInt(duration) : null,
        fileSize: BigInt(videoFile.size),
        tags: tagsArray,
        cost: cost ? parseInt(cost) : 0,
        status: (status as any) || 'PUBLIC',
        quality: [],
        subtitles: subtitleLanguages,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatar: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
    });

    console.log('✅ Video created successfully:', {
      id: video.id,
      title: video.title,
      fileName: video.fileName,
      fileDirectory: video.fileDirectory,
      status: video.status,
      isPublic: video.isPublic,
    });

    // Process video asynchronously (extract metadata and generate thumbnails)
    // Don't await - let it run in background and client can poll for status
    processVideoAsync(video.id, videoFile, video.fileDirectory || '').catch(err => {
      console.error('Error processing video async:', err);
    });

    return res.json({
      success: true,
      message: 'Video uploaded successfully, processing thumbnails...',
      data: {
        id: video.id,
        title: video.title,
        fileName: video.fileName,
        fileDirectory: video.fileDirectory,
        status: video.status,
      },
    });
  } catch (error) {
    console.error('Error uploading video:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to upload video',
    });
  }
});

// Async function to process video (runs in background)
async function processVideoAsync(videoId: string, videoFile: any, fileDirectory: string) {
  // Check if video conversion/processing is enabled
  const isVideoConversionEnabled = process.env['VIDEO_CONVERSION'] === 'true';
  
  if (!isVideoConversionEnabled) {
    console.log('⚠️  Video conversion is disabled (VIDEO_CONVERSION=false)');
    console.log('   Skipping backend video processing - frontend will handle thumbnails');
    
    // Clean up temp file if it exists
    const tempVideoPath = videoFile.tempPath;
    if (tempVideoPath) {
      try {
        await fs.unlink(tempVideoPath);
        console.log(`🗑️  Cleaned up temp video: ${tempVideoPath}`);
      } catch (err) {
        console.error(`⚠️  Failed to clean up temp video: ${err}`);
      }
    }
    return;
  }
  
  const tempVideoPath = videoFile.tempPath;
  
  if (!tempVideoPath) {
    console.log('⚠️  No temp video path available, skipping processing');
    return;
  }
  
  try {
    console.log(`🎬 Starting async video processing for: ${videoId}`);
    console.log(`📁 Using temp video file: ${tempVideoPath}`);
    
    const result = await processVideo(tempVideoPath, fileDirectory);
    
    // Update video record with metadata and thumbnails
    await prisma.video.update({
      where: { id: videoId },
      data: {
        duration: Math.round(result.metadata.duration),
        thumbnailUrl: result.thumbnails[0] || null, // Use first thumbnail as default
        thumbnails: result.thumbnails, // Store all thumbnails for selection
      },
    });
    
    console.log(`✅ Video ${videoId} processed successfully`);
    console.log(`   - Duration: ${result.metadata.duration}s`);
    console.log(`   - Resolution: ${result.metadata.width}x${result.metadata.height}`);
    console.log(`   - Thumbnails generated: ${result.thumbnails.length}`);
    console.log(`🖼️  Generated thumbnails:`, result.thumbnails);
    
  } catch (error) {
    console.error(`❌ Error processing video ${videoId}:`, error);
  } finally {
    // Clean up temp file
    try {
      await fs.unlink(tempVideoPath);
      console.log(`🗑️  Cleaned up temp video: ${tempVideoPath}`);
    } catch (err) {
      console.error(`⚠️  Failed to clean up temp video: ${err}`);
    }
  }
}

// Update video thumbnail selection
app.patch('/api/v1/videos/:id/thumbnail', authenticateToken, async (req: any, res) => {
  try {
    const { id } = req.params;
    const { thumbnailIndex } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    // Get video to check ownership and thumbnails
    const video = await prisma.video.findUnique({
      where: { id },
      select: { userId: true, thumbnails: true },
    });

    if (!video) {
      return res.status(404).json({
        success: false,
        message: 'Video not found',
      });
    }

    if (video.userId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this video',
      });
    }

    if (!video.thumbnails || video.thumbnails.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No thumbnails available for this video',
      });
    }

    const index = parseInt(thumbnailIndex);
    if (isNaN(index) || index < 0 || index >= video.thumbnails.length) {
      return res.status(400).json({
        success: false,
        message: 'Invalid thumbnail index',
      });
    }

    // Update the selected thumbnail
    const selectedThumbnail = video.thumbnails[index];
    const updatedVideo = await prisma.video.update({
      where: { id },
      data: {
        thumbnailUrl: selectedThumbnail || null,
      },
    });

    console.log(`🖼️  Updated thumbnail for video ${id} to index ${index}`);

    return res.json({
      success: true,
      message: 'Thumbnail updated successfully',
      data: {
        thumbnailUrl: updatedVideo.thumbnailUrl,
      },
    });
  } catch (error) {
    console.error('Error updating thumbnail:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update thumbnail',
    });
  }
});

// Get single video by ID
app.get('/api/v1/videos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const currentUserId = await getCurrentUserId(req);
    
    // Get video from database using Prisma
    const video = await prisma.video.findUnique({
      where: {
        id: id,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            avatar: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
    });

    if (!video) {
      res.status(404).json({
        success: false,
        message: 'Video not found',
      });
      return;
    }

    // Check if current user has liked this video
    let isLiked = false;
    if (currentUserId) {
      const existingLike = await prisma.like.findFirst({
        where: {
          userId: currentUserId,
          targetId: video.id,
          targetType: 'VIDEO',
        },
      });
      isLiked = !!existingLike;
    }

    // Convert to camelCase and serialize BigInt for JSON
    const serializedVideo = {
      id: video.id,
      userId: video.userId,
      title: video.title,
      description: video.description,
      videoUrl: video.videoUrl,
      thumbnailUrl: video.thumbnailUrl,
      duration: video.duration,
      fileSize: video.fileSize ? video.fileSize.toString() : null,
      quality: video.quality,
      views: video.views,
      likes: video.likes,
      comments: video.comments,
      shares: video.shares,
      downloads: video.downloads || 0,
      isLiked: isLiked,
      isPublic: video.isPublic,
      createdAt: video.createdAt.toISOString(),
      updatedAt: video.updatedAt.toISOString(),
      // New fields for video playback
      fileName: video.fileName,
      fileDirectory: video.fileDirectory,
      remotePlayUrl: video.remotePlayUrl,
      embedCode: video.embedCode,
      cost: video.cost,
      status: video.status,
      tags: video.tags,
      subtitles: video.subtitles,
      thumbnails: video.thumbnails || [],
      user: video.user ? serializeUserWithUrls(video.user) : null,
      // Also include user data at the top level for compatibility
      username: video.user?.username,
      firstName: video.user?.firstName,
      lastName: video.user?.lastName,
      // Build full avatar URL using storage fields; fallback to serialized user
      userAvatarUrl: video.user ? (buildAvatarUrl(video.user) || video.user.avatarUrl || null) : null,
    };

    res.json({
      success: true,
      data: serializedVideo,
    });
  } catch (error) {
    console.error('Error fetching video:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch video',
    });
  }
});

// Videos endpoint using real database data
app.get('/api/v1/videos', async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    
    console.log('📺 Fetching videos from database (page:', page, ', limit:', limit, ')');
    
    // Get videos from database using Prisma
    const videos = await prisma.video.findMany({
      where: {
        isPublic: true,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            isVerified: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      skip: offset,
      take: Number(limit),
    });

    // Convert to camelCase and serialize BigInt for JSON
    const serializedVideos = videos.map(video => ({
      id: video.id,
      userId: video.userId,
      title: video.title,
      description: video.description,
      videoUrl: video.videoUrl,
      thumbnailUrl: video.thumbnailUrl,
      duration: video.duration,
      fileSize: video.fileSize ? video.fileSize.toString() : null,
      quality: video.quality,
      views: video.views,
      likes: video.likes,
      comments: video.comments,
      shares: video.shares,
      downloads: video.downloads || 0,
      isPublic: video.isPublic,
      createdAt: video.createdAt.toISOString(),
      updatedAt: video.updatedAt.toISOString(),
      // New fields for video playback
      fileName: video.fileName,
      fileDirectory: video.fileDirectory,
      remotePlayUrl: video.remotePlayUrl,
      embedCode: video.embedCode,
      cost: video.cost,
      status: video.status,
      tags: video.tags,
      subtitles: video.subtitles,
      thumbnails: video.thumbnails || [],
      user: video.user ? serializeUserWithUrls(video.user) : null,
      // Also include user data at the top level for compatibility
      username: video.user?.username,
      firstName: video.user?.firstName,
      lastName: video.user?.lastName,
      userAvatarUrl: video.user ? buildAvatarUrl(video.user) : null,
    }));

    console.log(`✅ Found ${videos.length} videos in database`);
    console.log('First video sample:', videos[0] ? {
      id: videos[0].id,
      title: videos[0].title,
      fileName: videos[0].fileName,
      fileDirectory: videos[0].fileDirectory,
      remotePlayUrl: videos[0].remotePlayUrl,
      isPublic: videos[0].isPublic,
    } : 'No videos');

    res.json({
      success: true,
      data: serializedVideos,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: videos.length,
      },
    });
  } catch (error) {
    console.error('Error fetching videos:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch videos',
    });
  }
});

// Get videos by category
app.get('/api/v1/categories/:categoryId/videos', async (req, res) => {
  try {
    const { categoryId } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    
    const videos = await prisma.video.findMany({
      where: {
        categoryId: categoryId,
        isPublic: true,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatar: true,
            avatarUrl: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      skip: offset,
      take: Number(limit),
    });

    const serializedVideos = videos.map(video => ({
      id: video.id,
      userId: video.userId,
      categoryId: video.categoryId,
      title: video.title,
      description: video.description,
      videoUrl: video.videoUrl,
      thumbnailUrl: video.thumbnailUrl,
      duration: video.duration,
      fileSize: video.fileSize ? video.fileSize.toString() : null,
      quality: video.quality,
      views: video.views,
      likes: video.likes,
      comments: video.comments,
      shares: video.shares,
      downloads: video.downloads,
      isPublic: video.isPublic,
      createdAt: video.createdAt.toISOString(),
      updatedAt: video.updatedAt.toISOString(),
      // New fields for video playback
      fileName: video.fileName,
      fileDirectory: video.fileDirectory,
      remotePlayUrl: video.remotePlayUrl,
      embedCode: video.embedCode,
      cost: video.cost,
      status: video.status,
      tags: video.tags,
      subtitles: video.subtitles,
      thumbnails: video.thumbnails || [],
      user: video.user ? serializeUserWithUrls(video.user) : null,
      username: video.user?.username,
      firstName: video.user?.firstName,
      lastName: video.user?.lastName,
      userAvatarUrl: video.user ? buildAvatarUrl(video.user) : null,
    }));

    res.json({
      success: true,
      data: serializedVideos,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: videos.length,
      },
    });
  } catch (error) {
    console.error('Error fetching videos by category:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch videos',
    });
  }
});

// Get all categories (hierarchical structure)
app.get('/api/v1/categories', async (_req, res) => {
  try {
    const categories = await prisma.category.findMany({
      orderBy: {
        categoryOrder: 'asc',
      },
      include: {
        children: {
          orderBy: {
            categoryOrder: 'asc',
          },
        },
        _count: {
          select: {
            videos: true,
          },
        },
      },
    });

    // Build category tree (only parent categories at root level)
    const rootCategories = categories.filter(cat => !cat.parentId);

    const serializedCategories = rootCategories.map(category => ({
      id: category.id,
      parentId: category.parentId,
      categoryName: category.categoryName,
      categoryOrder: category.categoryOrder,
      categoryDesc: category.categoryDesc,
      categoryThumb: category.categoryThumb 
        ? buildFileUrlSync(category.fileDirectory, category.categoryThumb, 'categories')
        : null,
      isDefault: category.isDefault,
      createdAt: category.createdAt.toISOString(),
      videoCount: category._count.videos,
      children: category.children.map(child => ({
        id: child.id,
        parentId: child.parentId,
        categoryName: child.categoryName,
        categoryOrder: child.categoryOrder,
        categoryDesc: child.categoryDesc,
        categoryThumb: child.categoryThumb
          ? buildFileUrlSync(child.fileDirectory, child.categoryThumb, 'categories')
          : null,
        isDefault: child.isDefault,
        createdAt: child.createdAt.toISOString(),
      })),
    }));

    res.json({
      success: true,
      data: serializedCategories,
    });
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch categories',
    });
  }
});

// Helper function to get user ID from JWT token
// Note: getCurrentUserId is already defined at line 116 - removed duplicate


// Get coin transaction history (must be before /users/:userId route)
app.get('/api/v1/users/coin-transactions', authenticateToken, async (req, res): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    
    console.log('🔍 Coin transactions request - User ID:', currentUserId);
    console.log('🔍 Request headers:', req.headers);
    console.log('🔍 Request user:', req.user);
    
    if (!currentUserId) {
      console.log('❌ No user ID found in request');
      res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
      return;
    }
    
    const { type, page = 1, limit = 20 } = req.query;
    const pageNum = parseInt(page as string, 10);
    const limitNum = parseInt(limit as string, 10);
    const offset = (pageNum - 1) * limitNum;
    
    console.log('🔍 Query params:', { type, page: pageNum, limit: limitNum, offset });
    
    // Build where clause for filtering
    const whereClause: any = {
      userId: currentUserId,
    };
    
    if (type && ['RECHARGE', 'EARNED', 'USED'].includes(type as string)) {
      whereClause.type = type;
    }
    
    console.log('🔍 Where clause:', whereClause);
    
    // Fetch transactions with pagination
    const [transactions, totalCount] = await Promise.all([
      prisma.coinTransaction.findMany({
        where: whereClause,
        include: {
          relatedPost: {
            select: {
              id: true,
              title: true,
              type: true,
              content: true,
              createdAt: true,
              user: {
                select: {
                  id: true,
                  username: true,
                  firstName: true,
                  lastName: true,
                  avatarUrl: true,
                  avatar: true,
                  fileDirectory: true,
                },
              },
            },
          },
          relatedUser: {
            select: {
              id: true,
              username: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
              avatar: true,
              fileDirectory: true,
            },
          },
          payment: {
            select: {
              id: true,
              extOrderId: true,
              amount: true,
              currency: true,
              paymentMethod: true,
              status: true,
              createdAt: true,
              completedAt: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip: offset,
        take: limitNum,
      }),
      prisma.coinTransaction.count({
        where: whereClause,
      }),
    ]);
    
    console.log(`🔍 Found ${transactions.length} transactions out of ${totalCount} total`);
    
    // Map transactions to response format with proper avatar URLs
    const mappedTransactions = await Promise.all(transactions.map(async (transaction) => {
      let relatedPost = transaction.relatedPost;
      let relatedUser = transaction.relatedUser;
      
      // Build proper avatar URL for post author
      if (relatedPost && relatedPost.user) {
        const avatarUrl = relatedPost.user.avatar && relatedPost.user.fileDirectory
          ? await buildFileUrl(relatedPost.user.fileDirectory, relatedPost.user.avatar, 'avatars')
          : relatedPost.user.avatarUrl;
        
        relatedPost = {
          ...relatedPost,
          user: {
            ...relatedPost.user,
            avatarUrl: avatarUrl,
          },
        };
      }
      
      // Build proper avatar URL for related user (buyer/seller)
      if (relatedUser) {
        const avatarUrl = relatedUser.avatar && relatedUser.fileDirectory
          ? await buildFileUrl(relatedUser.fileDirectory, relatedUser.avatar, 'avatars')
          : relatedUser.avatarUrl;
        
        relatedUser = {
          ...relatedUser,
          avatarUrl: avatarUrl,
        };
      }
      
      return {
        id: transaction.id,
        type: transaction.type,
        amount: transaction.amount,
        status: transaction.status,
        description: transaction.description,
        relatedPost: relatedPost,
        relatedUser: relatedUser,
        payment: transaction.payment,
        metadata: transaction.metadata,
        createdAt: transaction.createdAt,
        updatedAt: transaction.updatedAt,
      };
    }));
    
    res.json({
      success: true,
      data: {
        transactions: mappedTransactions,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: totalCount,
          totalPages: Math.ceil(totalCount / limitNum),
        },
      },
    });
  } catch (error) {
    console.error('❌ Error fetching coin transactions:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch coin transactions',
    });
  }
});

// Get user profile by ID
app.get('/api/v1/users/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const currentUserId = await getCurrentUserId(req);
    
    // If no valid user, return 401 to trigger sign out
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }
    
    console.log(`🔍 Fetching profile for user: ${userId}`);
    
    // Get user from database using Prisma
    const user = await prisma.user.findUnique({
      where: {
        id: userId,
      },
      select: {
        id: true,
        username: true,
        email: true,
        firstName: true,
        lastName: true,
        bio: true,
        avatarUrl: true,
        avatar: true,
        fileDirectory: true,
        isVerified: true,
        role: true,
        coinBalance: true,
        isVip: true,
        createdAt: true,
        updatedAt: true,
        _count: {
          select: {
            followers: true,
            following: true,
            videos: true,
          },
        },
      },
    });

    // Manually count followers as backup
    const manualFollowersCount = await prisma.follow.count({
      where: {
        followingId: userId,
      },
    });
    
    const manualFollowingCount = await prisma.follow.count({
      where: {
        followerId: userId,
      },
    });
    
    const manualVideosCount = await prisma.video.count({
      where: {
        userId: userId,
      },
    });

    if (!user) {
      console.log(`❌ User not found: ${userId}`);
      res.status(404).json({
        success: false,
        message: 'User not found',
      });
      return;
    }

    // Check if current user is following this user
    let isFollowing = false;
    let isBlocked = false;
    
    if (currentUserId) {
      const followRelation = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: currentUserId,
            followingId: userId,
          },
        },
      });
      isFollowing = !!followRelation;

      const blockRelation = await prisma.userBlock.findUnique({
        where: {
          blockerId_blockedId: {
            blockerId: currentUserId,
            blockedId: userId,
          },
        },
      });
      isBlocked = !!blockRelation;
    }

    console.log(`✅ User found: ${user.username} (${user.id})`);
    console.log(`📊 Prisma _count - Followers: ${user._count.followers}, Following: ${user._count.following}, Videos: ${user._count.videos}`);
    console.log(`📊 Manual count - Followers: ${manualFollowersCount}, Following: ${manualFollowingCount}, Videos: ${manualVideosCount}`);
    console.log(`👥 Current user ${currentUserId} isFollowing: ${isFollowing}`);

    // Build proper avatar URL
    const avatarUrl = user.avatar && user.fileDirectory
      ? await buildFileUrl(user.fileDirectory, user.avatar, 'avatars')
      : user.avatarUrl;

    // Use manual counts as they are more reliable
    const serializedUser = {
      id: user.id,
      username: user.username,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      bio: user.bio,
      avatarUrl: avatarUrl,
      isVerified: user.isVerified,
      role: user.role,
      coinBalance: user.coinBalance,
      isVip: user.isVip,
      followersCount: manualFollowersCount,
      followingCount: manualFollowingCount,
      videosCount: manualVideosCount,
      isFollowing,
      isBlocked,
      createdAt: user.createdAt.toISOString(),
      updatedAt: user.updatedAt.toISOString(),
    };

    res.json({
      success: true,
      data: serializedUser,
    });
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch user profile',
    });
  }
});

// Report user
app.post('/api/v1/users/:userId/report', async (req, res) => {
  try {
    const { userId } = req.params;
    const { reason, description } = req.body;
    const reporterId = await getCurrentUserId(req);
    
    // If no valid user, return 401 to trigger sign out
    if (!reporterId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }
    
    console.log(`🚨 User report: ${userId} - ${reason} by user: ${reporterId}`);
    
    if (!reason) {
      res.status(400).json({
        success: false,
        message: 'Report reason is required',
      });
      return;
    }

    // Check if user exists
    const reportedUser = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!reportedUser) {
      res.status(404).json({
        success: false,
        message: 'User not found',
      });
      return;
    }

    // Check if user is trying to report themselves
    if (reporterId === userId) {
      res.status(400).json({
        success: false,
        message: 'Cannot report yourself',
      });
      return;
    }

    // Create the report in database
    const report = await prisma.userReport.create({
      data: {
        reporterId,
        reportedId: userId,
        reason,
        description: description || null,
        status: 'PENDING',
      },
    });

    console.log(`✅ Report created: ${report.id}`);

    res.json({
      success: true,
      message: 'User reported successfully',
      data: {
        reportId: report.id,
      },
    });
  } catch (error) {
    console.error('Error reporting user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to report user',
    });
  }
});

// Block user
app.post('/api/v1/users/:userId/block', async (req, res) => {
  try {
    const { userId } = req.params;
    const blockerId = await getCurrentUserId(req);
    
    // If no valid user, return 401 to trigger sign out
    if (!blockerId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }
    
    console.log(`🚫 Blocking user: ${userId} by user: ${blockerId}`);

    // Check if user exists
    const userToBlock = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!userToBlock) {
      res.status(404).json({
        success: false,
        message: 'User not found',
      });
      return;
    }

    // Check if user is trying to block themselves
    if (blockerId === userId) {
      res.status(400).json({
        success: false,
        message: 'Cannot block yourself',
      });
      return;
    }

    // Check if already blocked
    const existingBlock = await prisma.userBlock.findUnique({
      where: {
        blockerId_blockedId: {
          blockerId,
          blockedId: userId,
        },
      },
    });

    if (existingBlock) {
      res.status(400).json({
        success: false,
        message: 'User is already blocked',
      });
      return;
    }

    // Create the block in database
    const block = await prisma.userBlock.create({
      data: {
        blockerId,
        blockedId: userId,
      },
    });

    // Also unfollow the user if currently following
    await prisma.follow.deleteMany({
      where: {
        followerId: blockerId,
        followingId: userId,
      },
    });

    console.log(`✅ User blocked: ${block.id}`);

    res.json({
      success: true,
      message: 'User blocked successfully',
      data: {
        blockId: block.id,
      },
    });
  } catch (error) {
    console.error('Error blocking user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to block user',
    });
  }
});

// Unblock user
app.delete('/api/v1/users/:userId/block', async (req, res) => {
  try {
    const { userId } = req.params;
    const blockerId = await getCurrentUserId(req);
    
    // If no valid user, return 401 to trigger sign out
    if (!blockerId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }
    
    console.log(`✅ Unblocking user: ${userId} by user: ${blockerId}`);

    // Check if block exists
    const existingBlock = await prisma.userBlock.findUnique({
      where: {
        blockerId_blockedId: {
          blockerId,
          blockedId: userId,
        },
      },
    });

    if (!existingBlock) {
      res.status(404).json({
        success: false,
        message: 'User is not blocked',
      });
      return;
    }

    // Remove the block from database
    await prisma.userBlock.delete({
      where: {
        id: existingBlock.id,
      },
    });

    console.log(`✅ User unblocked: ${userId}`);

    res.json({
      success: true,
      message: 'User unblocked successfully',
    });
  } catch (error) {
    console.error('Error unblocking user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to unblock user',
    });
  }
});

// Follow user
app.post('/api/v1/users/:userId/follow', async (req, res) => {
  try {
    const { userId } = req.params;
    const followerId = await getCurrentUserId(req);
    
    // If no valid user, return 401 to trigger sign out
    if (!followerId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }
    
    console.log(`👥 Following user: ${userId} by user: ${followerId}`);
    
    // Debug: Check if both users exist
    const followerExists = await prisma.user.findUnique({
      where: { id: followerId },
      select: { id: true, username: true },
    });
    
    const targetUserExists = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, username: true },
    });
    
    console.log(`Follower exists:`, followerExists);
    console.log(`Target user exists:`, targetUserExists);
    
    if (!followerExists) {
      res.status(400).json({
        success: false,
        message: 'Follower user not found',
      });
      return;
    }
    
    if (!targetUserExists) {
      res.status(400).json({
        success: false,
        message: 'Target user not found',
      });
      return;
    }

    // Check if user exists
    const userToFollow = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!userToFollow) {
      res.status(404).json({
        success: false,
        message: 'User not found',
      });
      return;
    }

    // Check if user is trying to follow themselves
    if (followerId === userId) {
      res.status(400).json({
        success: false,
        message: 'Cannot follow yourself',
      });
      return;
    }

    // Check if already following
    const existingFollow = await prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId,
          followingId: userId,
        },
      },
    });

    if (existingFollow) {
      res.status(400).json({
        success: false,
        message: 'Already following this user',
      });
      return;
    }

    // Check if user is blocked
    const isBlocked = await prisma.userBlock.findFirst({
      where: {
        OR: [
          {
            blockerId: followerId,
            blockedId: userId,
          },
          {
            blockerId: userId,
            blockedId: followerId,
          },
        ],
      },
    });

    if (isBlocked) {
      res.status(403).json({
        success: false,
        message: 'Cannot follow this user',
      });
      return;
    }

    // Create the follow relationship in database
    const follow = await prisma.follow.create({
      data: {
        followerId,
        followingId: userId,
      },
    });

    console.log(`✅ User followed: ${follow.id}`);
    
    // Debug: Check the followers count after following
    const updatedUser = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        _count: {
          select: {
            followers: true,
          },
        },
      },
    });
    console.log(`📊 Followers count after follow: ${updatedUser?._count.followers}`);

    res.json({
      success: true,
      message: 'User followed successfully',
      data: {
        followId: follow.id,
      },
    });
  } catch (error) {
    console.error('Error following user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to follow user',
    });
  }
});

// Unfollow user
app.delete('/api/v1/users/:userId/follow', async (req, res) => {
  try {
    const { userId } = req.params;
    const followerId = await getCurrentUserId(req);
    
    // If no valid user, return 401 to trigger sign out
    if (!followerId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }
    
    console.log(`👥 Unfollowing user: ${userId} by user: ${followerId}`);

    // Check if follow relationship exists
    const existingFollow = await prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId,
          followingId: userId,
        },
      },
    });

    if (!existingFollow) {
      res.status(404).json({
        success: false,
        message: 'Not following this user',
      });
      return;
    }

    // Remove the follow relationship from database
    await prisma.follow.delete({
      where: {
        id: existingFollow.id,
      },
    });

    console.log(`✅ User unfollowed: ${userId}`);
    
    // Debug: Check the followers count after unfollowing
    const updatedUser = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        _count: {
          select: {
            followers: true,
          },
        },
      },
    });
    console.log(`📊 Followers count after unfollow: ${updatedUser?._count.followers}`);

    res.json({
      success: true,
      message: 'User unfollowed successfully',
    });
  } catch (error) {
    console.error('Error unfollowing user:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to unfollow user',
    });
  }
});

// Get comments for content (video or post)
app.get('/api/v1/social/comments', async (req, res) => {
  try {
    const { contentId, contentType } = req.query;
    const currentUserId = await getCurrentUserId(req);
    
    if (!contentId || !contentType) {
      res.status(400).json({
        success: false,
        message: 'contentId and contentType are required',
      });
      return;
    }
    
    // Map COMMUNITY_POST to POST for the database enum
    let mappedContentType = String(contentType).toUpperCase();
    if (mappedContentType === 'COMMUNITY_POST') {
      mappedContentType = 'POST';
    }

    // Get comments from database using Prisma
    const comments = await prisma.comment.findMany({
      where: {
        contentId: String(contentId),
        contentType: mappedContentType as any,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            avatar: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    // Check which comments current user has liked
    const commentIds = comments.map(c => c.id);
    const userLikes = currentUserId ? await prisma.like.findMany({
      where: {
        userId: currentUserId,
        targetId: { in: commentIds },
        targetType: 'COMMENT',
      },
      select: {
        targetId: true,
      },
    }) : [];
    
    const likedCommentIds = new Set(userLikes.map(l => l.targetId));

    // Convert to camelCase with hierarchical structure
    const parentComments = comments.filter(c => !c.parentId);
    const childComments = comments.filter(c => c.parentId);
    
    const serializedComments = await Promise.all(parentComments.map(async (comment) => {
      const replies = await Promise.all(childComments
        .filter(c => c.parentId === comment.id)
        .map(async (reply) => {
          // Build proper avatar URL for reply
          const replyAvatarUrl = reply.user.avatar && reply.user.fileDirectory
            ? await buildFileUrl(reply.user.fileDirectory, reply.user.avatar, 'avatars')
            : reply.user.avatarUrl;

          return {
            id: reply.id,
            userId: reply.userId,
            contentId: reply.contentId,
            contentType: reply.contentType,
            content: reply.content,
            likes: reply.likes,
            isLiked: likedCommentIds.has(reply.id),
            parentCommentId: reply.parentId,
            createdAt: reply.createdAt.toISOString(),
            updatedAt: reply.updatedAt.toISOString(),
            username: reply.user.firstName && reply.user.lastName 
              ? `${reply.user.firstName} ${reply.user.lastName}`
              : reply.user.username,
            userAvatar: replyAvatarUrl,
            isVerified: reply.user.isVerified,
          };
        }));

      // Build proper avatar URL for main comment
      const commentAvatarUrl = comment.user.avatar && comment.user.fileDirectory
        ? await buildFileUrl(comment.user.fileDirectory, comment.user.avatar, 'avatars')
        : comment.user.avatarUrl;

      return {
        id: comment.id,
        userId: comment.userId,
        contentId: comment.contentId,
        contentType: comment.contentType,
        content: comment.content,
        likes: comment.likes,
        isLiked: likedCommentIds.has(comment.id),
        parentCommentId: comment.parentId,
        createdAt: comment.createdAt.toISOString(),
        updatedAt: comment.updatedAt.toISOString(),
        username: comment.user.firstName && comment.user.lastName 
          ? `${comment.user.firstName} ${comment.user.lastName}`
          : comment.user.username,
        userAvatar: commentAvatarUrl,
        isVerified: comment.user.isVerified,
        replies: replies,
      };
    }));

    res.json({
      success: true,
      data: serializedComments,
    });
  } catch (error) {
    console.error('Error fetching comments:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch comments',
    });
  }
});

// Add comment to content (video or post)
app.post('/api/v1/social/comments', async (req, res) => {
  try {
    const { contentId, contentType, content, parentCommentId } = req.body;
    const currentUserId = await getCurrentUserId(req);

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    if (!contentId || !contentType || !content) {
      res.status(400).json({
        success: false,
        message: 'contentId, contentType, and content are required',
      });
      return;
    }

    // Map COMMUNITY_POST to POST for the database enum
    let mappedContentType = String(contentType).toUpperCase();
    if (mappedContentType === 'COMMUNITY_POST') {
      mappedContentType = 'POST';
    }

    // Create comment in database
    const comment = await prisma.comment.create({
      data: {
        userId: currentUserId,
        contentId: String(contentId),
        contentType: mappedContentType as any,
        content: String(content),
        parentId: parentCommentId || null,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            avatar: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
    });

    // Update comment count on the content (video or community post)
    if (contentType === 'VIDEO') {
      await prisma.video.update({
        where: { id: contentId },
        data: {
          comments: {
            increment: 1,
          },
        },
      });
    } else if (contentType === 'COMMUNITY_POST') {
      await prisma.communityPost.update({
        where: { id: contentId },
        data: {
          comments: {
            increment: 1,
          },
        },
      });
    }

    // Build proper avatar URL
    const commentAvatarUrl = comment.user.avatar && comment.user.fileDirectory
      ? await buildFileUrl(comment.user.fileDirectory, comment.user.avatar, 'avatars')
      : comment.user.avatarUrl;

    // Convert to camelCase
    const serializedComment = {
      id: comment.id,
      userId: comment.userId,
      contentId: comment.contentId,
      contentType: comment.contentType,
      content: comment.content,
      likes: comment.likes,
      isLiked: false,
      parentCommentId: comment.parentId,
      createdAt: comment.createdAt.toISOString(),
      updatedAt: comment.updatedAt.toISOString(),
      username: comment.user.firstName && comment.user.lastName 
        ? `${comment.user.firstName} ${comment.user.lastName}`
        : comment.user.username,
      userAvatar: commentAvatarUrl,
      isVerified: comment.user.isVerified,
      replies: [],
    };

    res.json({
      success: true,
      data: serializedComment,
    });
  } catch (error) {
    console.error('Error adding comment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to add comment',
    });
  }
});

// Toggle like on comment
app.post('/api/v1/social/comments/:commentId/like', async (req, res) => {
  try {
    const { commentId } = req.params;
    const currentUserId = await getCurrentUserId(req);

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    // Check if comment exists
    const comment = await prisma.comment.findUnique({
      where: { id: commentId },
    });

    if (!comment) {
      res.status(404).json({
        success: false,
        message: 'Comment not found',
      });
      return;
    }

    // Check if user has already liked this comment
    const existingLike = await prisma.like.findFirst({
      where: {
        userId: currentUserId,
        targetId: commentId,
        targetType: 'COMMENT',
      },
    });

    let isLiked: boolean;
    let updatedComment;

    if (existingLike) {
      // Unlike: Delete the like record
      await prisma.like.delete({
        where: { id: existingLike.id },
      });

      // Decrement like count
      updatedComment = await prisma.comment.update({
        where: { id: commentId },
        data: {
          likes: {
            decrement: 1,
          },
        },
        select: {
          id: true,
          likes: true,
        },
      });
      isLiked = false;
    } else {
      // Like: Create a like record
      await prisma.like.create({
        data: {
          userId: currentUserId,
          targetId: commentId,
          targetType: 'COMMENT',
          contentId: commentId, // Use commentId as contentId for comment likes
          contentType: comment.contentType,
          type: 'LIKE',
        },
      });

      // Increment like count
      updatedComment = await prisma.comment.update({
        where: { id: commentId },
        data: {
          likes: {
            increment: 1,
          },
        },
        select: {
          id: true,
          likes: true,
        },
      });
      isLiked = true;
    }

    res.json({
      success: true,
      data: {
        commentId: updatedComment.id,
        likes: updatedComment.likes,
        isLiked,
      },
    });
  } catch (error) {
    console.error('Error toggling comment like:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to toggle comment like',
    });
  }
});

// Edit comment
app.put('/api/v1/social/comments/:commentId', async (req, res) => {
  try {
    const { commentId } = req.params;
    const { content } = req.body;
    const currentUserId = await getCurrentUserId(req);

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    if (!content || content.trim().isEmpty) {
      res.status(400).json({
        success: false,
        message: 'Comment content is required',
      });
      return;
    }

    // Check if comment exists and user is the author
    const comment = await prisma.comment.findUnique({
      where: { id: commentId },
      select: {
        id: true,
        userId: true,
        content: true,
      },
    });

    if (!comment) {
      res.status(404).json({
        success: false,
        message: 'Comment not found',
      });
      return;
    }

    if (comment.userId !== currentUserId) {
      res.status(403).json({
        success: false,
        message: 'You can only edit your own comments',
      });
      return;
    }

    // Update the comment
    const updatedComment = await prisma.comment.update({
      where: { id: commentId },
      data: {
        content: content.trim(),
        updatedAt: new Date(),
      },
      select: {
        id: true,
        content: true,
        updatedAt: true,
      },
    });

    res.json({
      success: true,
      data: {
        commentId: updatedComment.id,
        content: updatedComment.content,
        updatedAt: updatedComment.updatedAt,
      },
    });
  } catch (error) {
    console.error('Error editing comment:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
});

// Delete comment
app.delete('/api/v1/social/comments/:commentId', async (req, res) => {
  try {
    const { commentId } = req.params;
    const currentUserId = await getCurrentUserId(req);

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    // Check if comment exists and user is the author
    const comment = await prisma.comment.findUnique({
      where: { id: commentId },
      select: {
        id: true,
        userId: true,
        contentId: true,
        contentType: true,
        parentId: true,
      },
    });

    if (!comment) {
      res.status(404).json({
        success: false,
        message: 'Comment not found',
      });
      return;
    }

    if (comment.userId !== currentUserId) {
      res.status(403).json({
        success: false,
        message: 'You can only delete your own comments',
      });
      return;
    }

    // Delete all likes for this comment
    await prisma.like.deleteMany({
      where: {
        targetId: commentId,
        targetType: 'COMMENT',
      },
    });

    // Only delete replies if this is a parent comment (not a reply itself)
    if (!comment.parentId) {
      // Delete all replies to this comment
      await prisma.comment.deleteMany({
        where: {
          parentId: commentId,
        },
      });
    }

    // Delete the comment itself
    await prisma.comment.delete({
      where: { id: commentId },
    });

    // Decrement comment count on the content (video or community post)
    if (comment.contentType === 'VIDEO') {
      await prisma.video.update({
        where: { id: comment.contentId },
        data: {
          comments: {
            decrement: 1,
          },
        },
      });
    } else if (comment.contentType === 'POST') {
      await prisma.communityPost.update({
        where: { id: comment.contentId },
        data: {
          comments: {
            decrement: 1,
          },
        },
      });
    }

    res.json({
      success: true,
      message: 'Comment deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting comment:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
});

// Like/Unlike a community post
app.post('/api/v1/community/posts/:postId/like', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    // Check if user already liked this post
    const existingLike = await prisma.communityPostLike.findUnique({
      where: {
        userId_postId: {
          userId: userId,
          postId: postId,
        },
      },
    });

    if (existingLike) {
      // Unlike: remove the like
      await prisma.communityPostLike.delete({
        where: {
          userId_postId: {
            userId: userId,
            postId: postId,
          },
        },
      });

      // Decrement likes count
      await prisma.communityPost.update({
        where: { id: postId },
        data: {
          likes: {
            decrement: 1,
          },
        },
      });

      return res.json({
        success: true,
        liked: false,
        message: 'Post unliked successfully',
      });
    } else {
      // Like: create new like
      await prisma.communityPostLike.create({
        data: {
          userId: userId,
          postId: postId,
        },
      });

      // Increment likes count
      await prisma.communityPost.update({
        where: { id: postId },
        data: {
          likes: {
            increment: 1,
          },
        },
      });

      return res.json({
        success: true,
        liked: true,
        message: 'Post liked successfully',
      });
    }
    } catch (error) {
      console.error('Error liking/unliking post:', error);
      return res.status(500).json({
        success: false,
        message: 'Internal server error',
      });
    }
  });

// Bookmark/Unbookmark a community post
app.post('/api/v1/community/posts/:postId/bookmark', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    // Check if user already bookmarked this post
    const existingBookmark = await prisma.communityPostBookmark.findUnique({
      where: {
        userId_postId: {
          userId: userId,
          postId: postId,
        },
      },
    });

    if (existingBookmark) {
      // Unbookmark: remove the bookmark
      await prisma.communityPostBookmark.delete({
        where: {
          userId_postId: {
            userId: userId,
            postId: postId,
          },
        },
      });

      return res.json({
        success: true,
        bookmarked: false,
        message: 'Post unbookmarked successfully',
      });
    } else {
      // Bookmark: create new bookmark
      await prisma.communityPostBookmark.create({
        data: {
          userId: userId,
          postId: postId,
        },
      });

      return res.json({
        success: true,
        bookmarked: true,
        message: 'Post bookmarked successfully',
      });
    }
    } catch (error) {
      console.error('Error bookmarking/unbookmarking post:', error);
      return res.status(500).json({
        success: false,
        message: 'Internal server error',
      });
    }
  });

// Report a community post
app.post('/api/v1/community/posts/:postId/report', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user?.id;
    const { reason, description } = req.body;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    // Create report
    await prisma.communityPostReport.create({
      data: {
        userId: userId,
        postId: postId,
        reason: reason || 'Inappropriate content',
        description: description || '',
      },
    });

    return res.json({
      success: true,
      message: 'Post reported successfully',
    });
    } catch (error) {
      console.error('Error reporting post:', error);
      return res.status(500).json({
        success: false,
        message: 'Internal server error',
      });
    }
  });

// Pin/Unpin a community post (admin only)
app.post('/api/v1/community/posts/:postId/pin', authenticateToken, async (req, res) => {
  try {
    const { postId } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    // Get current post details
    const post = await prisma.communityPost.findUnique({
      where: { id: postId },
      select: { isPinned: true, userId: true },
    });

    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found',
      });
    }

    // Check if user is the author of the post
    if (post.userId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'You can only pin your own posts',
      });
    }

    // If pinning this post, unpin all other posts by this user first
    if (!post.isPinned) {
      await prisma.communityPost.updateMany({
        where: { 
          userId: userId,
          isPinned: true,
        },
        data: {
          isPinned: false,
        },
      });
    }

    // Toggle pin status for this post
    await prisma.communityPost.update({
      where: { id: postId },
      data: {
        isPinned: !post.isPinned,
      },
    });

    return res.json({
      success: true,
      pinned: !post.isPinned,
      message: `Post ${!post.isPinned ? 'pinned' : 'unpinned'} successfully`,
    });
    } catch (error) {
      console.error('Error pinning/unpinning post:', error);
      return res.status(500).json({
        success: false,
        message: 'Internal server error',
      });
    }
  });

// Follow/Unfollow a user
app.post('/api/v1/users/:userId/follow', authenticateToken, async (req, res) => {
  try {
    const { userId: targetUserId } = req.params;
    const followerId = req.user?.id;

    if (!followerId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    if (followerId === targetUserId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot follow yourself',
      });
    }

    // Check if already following
    const existingFollow = await prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId: followerId,
          followingId: targetUserId,
        },
      },
    });

    if (existingFollow) {
      // Unfollow: remove the follow
      await prisma.follow.delete({
        where: {
          followerId_followingId: {
            followerId: followerId,
            followingId: targetUserId,
          },
        },
      });

      return res.json({
        success: true,
        following: false,
        message: 'User unfollowed successfully',
      });
    } else {
      // Follow: create new follow
      await prisma.follow.create({
        data: {
          followerId: followerId,
          followingId: targetUserId,
        },
      });

      return res.json({
        success: true,
        following: true,
        message: 'User followed successfully',
      });
    }
    } catch (error) {
      console.error('Error following/unfollowing user:', error);
      return res.status(500).json({
        success: false,
        message: 'Internal server error',
      });
    }
  });

// Increment post views
app.post('/api/v1/community/posts/:postId/view', async (req, res) => {
  try {
    const { postId } = req.params;

    await prisma.communityPost.update({
      where: { id: postId },
      data: {
        views: {
          increment: 1,
        },
      },
    });

    return res.json({
      success: true,
      message: 'View count updated',
    });
    } catch (error) {
      console.error('Error updating view count:', error);
      return res.status(500).json({
        success: false,
        message: 'Internal server error',
      });
    }
  });

// Get posts by tag
app.get('/api/v1/community/posts/tag/:tag', authenticateToken, async (req, res) => {
  try {
    const { tag } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    const currentUserId = req.user?.id;

    // Get posts that contain this tag
    const posts = await prisma.communityPost.findMany({
      where: {
        tags: {
          has: tag,
        },
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            isVerified: true,
            avatar: true,
            fileDirectory: true,
          },
        },
      },
      orderBy: [
        { isPinned: 'desc' },
        { createdAt: 'desc' },
      ],
      skip: offset,
      take: Number(limit),
    });

    // Build URLs for each post
    const postsWithUrls = await Promise.all(
      posts.map(async (post) => {
        // Build image URLs
        const imageUrls = await Promise.all(
          post.images.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build video URLs
        const videoUrls = await Promise.all(
          post.videos.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build video thumbnail URLs from database
        const videoThumbnailUrls = await Promise.all(
          post.videoThumbnails.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build avatar URL (async)
        const avatarUrl = post.user.avatar && post.user.fileDirectory
          ? await buildFileUrl(post.user.fileDirectory, post.user.avatar, 'avatars')
          : null;

        // Check if current user has liked this post
        const isLiked = currentUserId ? await prisma.communityPostLike.findUnique({
          where: {
            userId_postId: {
              userId: currentUserId,
              postId: post.id,
            },
          },
        }) : null;

        // Check if current user has bookmarked this post
        const isBookmarked = currentUserId ? await prisma.communityPostBookmark.findUnique({
          where: {
            userId_postId: {
              userId: currentUserId,
              postId: post.id,
            },
          },
        }) : null;

        return {
          ...post,
          username: post.user.username,
          firstName: post.user.firstName,
          lastName: post.user.lastName,
          isVerified: post.user.isVerified,
          userAvatar: avatarUrl,
          imageUrls: imageUrls.filter((url) => url != null),
          videoUrls: videoUrls.filter((url) => url != null),
          videoThumbnailUrls: videoThumbnailUrls.filter((url) => url != null),
          isLiked: isLiked != null,
          isBookmarked: isBookmarked != null,
        };
      })
    );

    return res.json({
      success: true,
      data: postsWithUrls,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: postsWithUrls.length,
      },
    });
    } catch (error) {
      console.error('Error fetching posts by tag:', error);
      return res.status(500).json({
        success: false,
        message: 'Internal server error',
      });
    }
  });

// Community posts endpoint using real database data
app.get('/api/v1/community/posts', authenticateToken, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    const currentUserId = req.user?.id;
    
    // Get community posts from database using Prisma
    const posts = await prisma.communityPost.findMany({
      where: {
        isPublic: true,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatar: true,
            avatarUrl: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      skip: offset,
      take: Number(limit),
    });

    // Add file URLs and user interaction status to posts
    const postsWithUrls = await Promise.all(
      posts.map(async (post) => {
        // Build image URLs
        const imageUrls = await Promise.all(
          post.images.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build video URLs
        const videoUrls = await Promise.all(
          post.videos.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build video thumbnail URLs from database
        const videoThumbnailUrls = await Promise.all(
          post.videoThumbnails.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build avatar URL (async)
        const avatarUrl = post.user.avatar && post.user.fileDirectory
          ? await buildFileUrl(post.user.fileDirectory, post.user.avatar, 'avatars')
          : null;

        // Check if current user has liked this post
        const isLiked = currentUserId ? await prisma.communityPostLike.findUnique({
          where: {
            userId_postId: {
              userId: currentUserId,
              postId: post.id,
            },
          },
        }) : null;

        // Check if current user has bookmarked this post
        const isBookmarked = currentUserId ? await prisma.communityPostBookmark.findUnique({
          where: {
            userId_postId: {
              userId: currentUserId,
              postId: post.id,
            },
          },
        }) : null;

        return {
          ...post,
          username: post.user.username,
          firstName: post.user.firstName,
          lastName: post.user.lastName,
          isVerified: post.user.isVerified,
          userAvatar: avatarUrl,
          imageUrls: imageUrls.filter((url) => url != null),
          videoUrls: videoUrls.filter((url) => url != null),
          videoThumbnailUrls: videoThumbnailUrls.filter((url) => url != null),
          isLiked: isLiked != null,
          isBookmarked: isBookmarked != null,
        };
      })
    );

    res.json({
      success: true,
      data: postsWithUrls,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: posts.length,
      },
    });
  } catch (error) {
    console.error('Error fetching community posts:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch community posts',
    });
  }
});

// Get trending community posts (ordered by views)
app.get('/api/v1/community/posts/trending', authenticateToken, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    const currentUserId = req.user?.id;
    
    // Get community posts ordered by views (descending)
    const posts = await prisma.communityPost.findMany({
      where: {
        isPublic: true,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatar: true,
            avatarUrl: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
      orderBy: {
        views: 'desc', // Order by views descending (most viewed first)
      },
      skip: offset,
      take: Number(limit),
    });


    // Add file URLs and user interaction status to posts
    const postsWithUrls = await Promise.all(
      posts.map(async (post) => {
        // Build image URLs
        const imageUrls = await Promise.all(
          post.images.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build video URLs
        const videoUrls = await Promise.all(
          post.videos.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build video thumbnail URLs from database
        const videoThumbnailUrls = await Promise.all(
          post.videoThumbnails.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build avatar URL (async)
        const avatarUrl = post.user.avatar && post.user.fileDirectory
          ? await buildFileUrl(post.user.fileDirectory, post.user.avatar, 'avatars')
          : null;

        // Check if current user has liked this post
        const isLiked = currentUserId ? await prisma.communityPostLike.findUnique({
          where: {
            userId_postId: {
              userId: currentUserId,
              postId: post.id,
            },
          },
        }) : null;

        // Check if current user has bookmarked this post
        const isBookmarked = currentUserId ? await prisma.communityPostBookmark.findUnique({
          where: {
            userId_postId: {
              userId: currentUserId,
              postId: post.id,
            },
          },
        }) : null;

        return {
          ...post,
          username: post.user.username,
          firstName: post.user.firstName,
          lastName: post.user.lastName,
          isVerified: post.user.isVerified,
          userAvatar: avatarUrl,
          imageUrls: imageUrls.filter((url) => url != null),
          videoUrls: videoUrls.filter((url) => url != null),
          videoThumbnailUrls: videoThumbnailUrls.filter((url) => url != null),
          isLiked: isLiked != null,
          isBookmarked: isBookmarked != null,
        };
      })
    );

    res.json({
      success: true,
      data: postsWithUrls,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: posts.length,
      },
    });
  } catch (error) {
    console.error('Error fetching trending posts:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch trending posts',
    });
  }
});

// Search community posts (comprehensive search across author, username, content, tags)
app.get('/api/v1/community/posts/search', authenticateToken, async (req, res) => {
  try {
    const { q: query, page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    const currentUserId = req.user?.id;

    if (!query || query.toString().trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Search query is required',
      });
    }

    const searchTerm = `%${query.toString().trim()}%`;

    // Search across multiple fields using Prisma's OR condition
    const posts = await prisma.communityPost.findMany({
      where: {
        AND: [
          { isPublic: true },
          {
            OR: [
              // Search in post content
              { content: { contains: searchTerm, mode: 'insensitive' } },
              // Search in post title
              { title: { contains: searchTerm, mode: 'insensitive' } },
              // Search in tags array
              { tags: { has: query.toString().trim() } },
              // Search in tags array (case insensitive - need to check each tag)
              { tags: { hasSome: [query.toString().trim().toLowerCase()] } },
              // Search in user's first name
              { user: { firstName: { contains: searchTerm, mode: 'insensitive' } } },
              // Search in user's last name
              { user: { lastName: { contains: searchTerm, mode: 'insensitive' } } },
              // Search in username
              { user: { username: { contains: searchTerm, mode: 'insensitive' } } },
            ],
          },
        ],
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatar: true,
            avatarUrl: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
      orderBy: [
        // Order by user name first (author), then by post creation date, then by tag relevance
        { user: { firstName: 'asc' } },
        { user: { lastName: 'asc' } },
        { createdAt: 'desc' },
      ],
      skip: offset,
      take: Number(limit),
    });

    // Add file URLs and user interaction status to posts
    const postsWithUrls = await Promise.all(
      posts.map(async (post) => {
        // Build image URLs
        const imageUrls = await Promise.all(
          post.images.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build video URLs
        const videoUrls = await Promise.all(
          post.videos.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build video thumbnail URLs from database
        const videoThumbnailUrls = await Promise.all(
          post.videoThumbnails.map((fileName) =>
            buildCommunityPostFileUrl(post.fileDirectory, fileName)
          )
        );

        // Build avatar URL (async)
        const avatarUrl = post.user.avatar && post.user.fileDirectory
          ? await buildFileUrl(post.user.fileDirectory, post.user.avatar, 'avatars')
          : null;

        // Check if current user has liked this post
        const isLiked = currentUserId ? await prisma.communityPostLike.findUnique({
          where: {
            userId_postId: {
              userId: currentUserId,
              postId: post.id,
            },
          },
        }) : null;

        // Check if current user has bookmarked this post
        const isBookmarked = currentUserId ? await prisma.communityPostBookmark.findUnique({
          where: {
            userId_postId: {
              userId: currentUserId,
              postId: post.id,
            },
          },
        }) : null;

        return {
          ...post,
          username: post.user.username,
          firstName: post.user.firstName,
          lastName: post.user.lastName,
          isVerified: post.user.isVerified,
          userAvatar: avatarUrl,
          imageUrls: imageUrls.filter((url) => url != null),
          videoUrls: videoUrls.filter((url) => url != null),
          videoThumbnailUrls: videoThumbnailUrls.filter((url) => url != null),
          isLiked: isLiked != null,
          isBookmarked: isBookmarked != null,
        };
      })
    );

    return res.json({
      success: true,
      data: postsWithUrls,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: posts.length,
      },
      query: query.toString().trim(),
    });
  } catch (error) {
    console.error('Error searching community posts:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to search posts',
    });
  }
});

// Create community post endpoint
app.post('/api/v1/community/posts', authenticateToken, communityPostUpload.array('files', 10), async (req, res) => {
  try {
    const {
      content,
      linkUrl,
      linkTitle,
      linkDescription,
      pollOptions,
      tags: tagsString,
      cost: costString,
      requiresVip: requiresVipString,
      allowComments: allowCommentsString,
      allowCommentLinks: allowCommentLinksString,
      isPinned: isPinnedString,
      isNsfw: isNsfwString,
      replyRestriction,
    } = req.body || {};

    // Parse form data strings to proper types
    const tags = tagsString ? JSON.parse(tagsString) : [];
    const cost = costString ? parseInt(costString) : 0;
    const requiresVip = requiresVipString === 'true';
    const allowComments = allowCommentsString !== 'false'; // Default to true
    const allowCommentLinks = allowCommentLinksString === 'true';
    const isPinned = isPinnedString === 'true';
    const isNsfw = isNsfwString === 'true';

    // Get uploaded files
    const uploadedFiles = req.files as Express.Multer.File[] || [];

    // Get current user from database
    const currentUser = await prisma.user.findUnique({
      where: { id: (req as any).user.id },
      select: { id: true, username: true, role: true },
    });

    if (!currentUser) {
      return res.status(401).json({
        success: false,
        message: 'User not found',
      });
    }

    // For now, skip coin validation since coins field doesn't exist yet
    // TODO: Add coins field to User model when implementing payment system

    // Create the post first to get the post ID
    const newPost = await prisma.communityPost.create({
      data: {
        userId: currentUser.id,
        content: content || null,
        type: 'MEDIA' as const, // Always MEDIA type for posts with text + media
        images: [], // Will be updated after file upload
        videos: [], // Will be updated after file upload
        fileDirectory: null, // Will be updated after file upload
        linkUrl: linkUrl || null,
        linkTitle: linkTitle || null,
        linkDescription: linkDescription || null,
        pollOptions: pollOptions || null,
        tags: tags || [],
        cost: cost || 0,
        requiresVip: requiresVip || false,
        allowComments: allowComments !== false, // Default to true
        allowCommentLinks: allowCommentLinks || false,
        isPinned: isPinned || false,
        isNsfw: isNsfw || false,
        replyRestriction: replyRestriction || 'FOLLOWERS',
      },
    });

    // Upload files to S3 if any files were uploaded
    let fileDirectory: string | null = null;
    let images: string[] = [];
    let videos: string[] = [];
    let durations: string[] = [];

    if (uploadedFiles.length > 0) {
      try {
        const uploadResult = await uploadCommunityPostFiles(uploadedFiles, newPost.id);
        fileDirectory = uploadResult.fileDirectory;
        images = uploadResult.images;
        videos = uploadResult.videos;
        const videoThumbnails = uploadResult.videoThumbnails;

        // Get durations from request body if provided (from mobile app)
        const videoDurationsString = req.body?.videoDurations;
        console.log('📊 Received videoDurations string:', videoDurationsString);
        if (videoDurationsString) {
          try {
            const parsedDurations = JSON.parse(videoDurationsString);
            // Ensure all durations are strings
            durations = parsedDurations.map((d: any) => String(d));
            console.log('✅ Parsed durations:', durations);
          } catch (error) {
            console.error('❌ Error parsing video durations:', error);
            durations = [];
          }
        } else {
          console.log('⚠️  No videoDurations received from mobile app');
        }

        // Update the post with file information
        await prisma.communityPost.update({
          where: { id: newPost.id },
          data: {
            fileDirectory,
            images,
            videos,
            videoThumbnails,
            duration: durations,
          },
        });
      } catch (uploadError) {
        console.error('Error uploading files:', uploadError);
        // Delete the post if file upload failed
        await prisma.communityPost.delete({
          where: { id: newPost.id },
        });
        return res.status(500).json({
          success: false,
          message: 'Failed to upload files',
        });
      }
    }

    // Fetch the final post with user info
    const finalPost = await prisma.communityPost.findUnique({
      where: { id: newPost.id },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatar: true,
            avatarUrl: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
    });

    if (!finalPost) {
      return res.status(500).json({
        success: false,
        message: 'Failed to create post',
      });
    }

    // Build avatar URL (async)
    const avatarUrl = finalPost.user.avatar && finalPost.user.fileDirectory
      ? await buildFileUrl(finalPost.user.fileDirectory, finalPost.user.avatar, 'avatars')
      : finalPost.user.avatarUrl;

    // Return the created post with user info
    const postWithUser = {
      ...finalPost,
      username: finalPost.user.username,
      firstName: finalPost.user.firstName,
      lastName: finalPost.user.lastName,
      isVerified: finalPost.user.isVerified,
      userAvatar: avatarUrl,
      isLiked: false, // Default for now
    };

    return res.json({
      success: true,
      message: 'Post created successfully',
      data: postWithUser,
    });

  } catch (error) {
    console.error('Error creating community post:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to create post',
    });
  }
});

// Get all available tags from community posts
app.get('/api/v1/community/tags', authenticateToken, async (_req, res) => {
  try {
    // Get all posts with tags
    const posts = await prisma.communityPost.findMany({
      select: {
        tags: true,
      },
      where: {
        isPublic: true,
      },
    });

    // Extract all unique tags
    const allTags = new Set<string>();
    posts.forEach(post => {
      post.tags.forEach(tag => {
        if (tag.trim() !== '') {
          allTags.add(tag.trim());
        }
      });
    });

    // Convert to array and sort alphabetically
    const tagsArray = Array.from(allTags).sort();

    return res.json({
      success: true,
      tags: tagsArray,
    });
  } catch (error) {
    console.error('Error fetching tags:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch tags',
    });
  }
});

// ============================================
// Chat API Endpoints
// ============================================

// Get chat rooms for current user
app.get('/api/v1/chat/rooms', async (req, res) => {
  try {
    const currentUserId = await getCurrentUserId(req);
    
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);

    // Get chat rooms where user is a participant
    const chatRooms = await prisma.chatRoom.findMany({
      where: {
        participants: {
          some: {
            userId: currentUserId,
          },
        },
      },
      include: {
        participants: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                firstName: true,
                lastName: true,
                avatarUrl: true,
                avatar: true,
                fileDirectory: true,
                isVerified: true,
              },
            },
          },
        },
        messages: {
          orderBy: {
            createdAt: 'desc',
          },
          take: 1,
          include: {
            user: {
              select: {
                id: true,
                username: true,
                firstName: true,
                lastName: true,
                avatarUrl: true,
                avatar: true,
                fileDirectory: true,
              },
            },
          },
        },
        creator: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
          },
        },
      },
      orderBy: {
        updatedAt: 'desc',
      },
      skip: offset,
      take: Number(limit),
    });

    // Serialize chat rooms
    const serializedRooms = chatRooms.map(room => ({
      id: room.id,
      name: room.name,
      type: room.type,
      isGroup: room.type === 'GROUP',
      participants: room.participants.map((p: any) => ({
        id: p.user.id,
        username: p.user.username,
        firstName: p.user.firstName,
        lastName: p.user.lastName,
        avatarUrl: buildAvatarUrl(p.user) || p.user.avatarUrl,
        isVerified: p.user.isVerified,
        joinedAt: p.joinedAt.toISOString(),
        role: p.role,
      })),
      lastMessage: room.messages.length > 0 && room.messages[0] ? {
        id: room.messages[0].id,
        content: room.messages[0].content,
        type: room.messages[0].messageType,
        createdAt: room.messages[0].createdAt.toISOString(),
        userId: room.messages[0].userId,
        username: room.messages[0].user?.username || 'Unknown',
        userAvatar: room.messages[0].user ? (buildAvatarUrl(room.messages[0].user) || room.messages[0].user.avatarUrl) : null,
      } : null,
      unreadCount: 0, // TODO: Implement unread count
      isOnline: false, // TODO: Implement online status
      createdAt: room.createdAt.toISOString(),
      updatedAt: room.updatedAt.toISOString(),
      createdBy: room.creator ? {
        id: room.creator.id,
        username: room.creator.username,
        firstName: room.creator.firstName,
        lastName: room.creator.lastName,
      } : null,
    }));

    res.json({
      success: true,
      data: serializedRooms,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: serializedRooms.length,
      },
    });
  } catch (error) {
    console.error('Error fetching chat rooms:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch chat rooms',
    });
  }
});

// Get users for chat creation
app.get('/api/v1/users/search/users', async (req, res) => {
  try {
    const currentUserId = await getCurrentUserId(req);
    
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    const { q = '', limit = 20 } = req.query;

    const users = await prisma.user.findMany({
      where: {
        AND: [
          { id: { not: currentUserId } }, // Exclude current user
          {
            OR: [
              { username: { contains: q as string, mode: 'insensitive' } },
              { firstName: { contains: q as string, mode: 'insensitive' } },
              { lastName: { contains: q as string, mode: 'insensitive' } },
            ],
          },
        ],
      },
      select: {
        id: true,
        username: true,
        firstName: true,
        lastName: true,
        avatar: true,
        fileDirectory: true,
        isVerified: true,
      },
      take: Number(limit),
    });

    const serializedUsers = users.map(user => ({
      id: user.id,
      username: user.username,
      firstName: user.firstName,
      lastName: user.lastName,
      avatarUrl: user.avatar && user.fileDirectory 
        ? `${process.env['CDN_URL'] || process.env['S3_ENDPOINT']}/${user.fileDirectory}/${user.avatar}`
        : null,
      isVerified: user.isVerified,
    }));

    res.json({
      success: true,
      data: serializedUsers,
    });
  } catch (error) {
    console.error('Error searching users:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to search users',
    });
  }
});

// Create a new chat room
app.post('/api/v1/chat/rooms', async (req, res) => {
  try {
    const currentUserId = await getCurrentUserId(req);
    
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    const { name, type = 'PRIVATE', participantIds = [] } = req.body;

    if (!name && type === 'GROUP') {
      res.status(400).json({
        success: false,
        message: 'Room name is required for group chats',
      });
      return;
    }

    // For private messages, ensure only 2 participants
    if (type === 'PRIVATE' && participantIds.length !== 1) {
      res.status(400).json({
        success: false,
        message: 'Private messages require exactly one other participant',
      });
      return;
    }

    // Validate that all participant IDs exist in the database
    if (participantIds.length > 0) {
      const validUsers = await prisma.user.findMany({
        where: {
          id: {
            in: participantIds,
          },
        },
        select: {
          id: true,
        },
      });

      const validUserIds = validUsers.map(user => user.id);
      const invalidIds = participantIds.filter((id: string) => !validUserIds.includes(id));

      if (invalidIds.length > 0) {
        res.status(400).json({
          success: false,
          message: `Invalid participant IDs: ${invalidIds.join(', ')}`,
        });
        return;
      }
    }

    // Check if private chat already exists
    if (type === 'PRIVATE') {
      const existingRoom = await prisma.chatRoom.findFirst({
        where: {
          type: 'PRIVATE',
          participants: {
            every: {
              userId: {
                in: [currentUserId, participantIds[0]],
              },
            },
          },
        },
        include: {
          participants: true,
        },
      });

      if (existingRoom) {
        return res.json({
          success: true,
          data: existingRoom,
          message: 'Existing chat room found',
        });
      }
    }

    // Create chat room
    const chatRoom = await prisma.chatRoom.create({
      data: {
        name: type === 'PRIVATE' ? null : name,
        type: type.toUpperCase() as any,
        createdBy: currentUserId,
        participants: {
          create: [
            { userId: currentUserId },
            ...participantIds.map((id: string) => ({ userId: id })),
          ],
        },
      },
      include: {
        participants: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                firstName: true,
                lastName: true,
                avatarUrl: true,
                avatar: true,
                fileDirectory: true,
                isVerified: true,
              },
            },
          },
        },
        creator: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
          },
        },
      },
    });

    return res.json({
      success: true,
      data: {
        id: chatRoom.id,
        name: chatRoom.name,
        type: chatRoom.type,
        isGroup: chatRoom.type === 'GROUP',
        participants: chatRoom.participants.map((p: any) => ({
          id: p.user.id,
          username: p.user.username,
          firstName: p.user.firstName,
          lastName: p.user.lastName,
          avatarUrl: buildAvatarUrl(p.user) || p.user.avatarUrl,
          isVerified: p.user.isVerified,
        })),
        createdAt: chatRoom.createdAt.toISOString(),
        createdBy: {
          id: chatRoom.creator.id,
          username: chatRoom.creator.username,
          firstName: chatRoom.creator.firstName,
          lastName: chatRoom.creator.lastName,
        },
      },
    });
  } catch (error) {
    console.error('Error creating chat room:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to create chat room',
    });
  }
});

// Get messages for a chat room
app.get('/api/v1/chat/rooms/:roomId/messages', async (req, res) => {
  try {
    const currentUserId = await getCurrentUserId(req);
    
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    const { roomId } = req.params;
    const { page = 1, limit = 50 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);

    // Check if user is participant in this room
    const room = await prisma.chatRoom.findFirst({
      where: {
        id: roomId,
        participants: {
          some: {
            userId: currentUserId,
          },
        },
      },
    });

    if (!room) {
      res.status(403).json({
        success: false,
        message: 'Access denied to this chat room',
      });
      return;
    }

    // Get messages
    const messages = await prisma.chatMessage.findMany({
      where: {
        roomId: roomId,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            avatar: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      skip: offset,
      take: Number(limit),
    });

    // Serialize messages with dynamic fileUrl
    const serializedMessages = messages.map((message: any) => {
      // Determine file folder based on message type
      let fileFolder: string | undefined;
      if (message.fileName && message.fileDirectory) {
        const msgType = message.messageType.toLowerCase();
        if (msgType === 'image') fileFolder = 'chat/photo';
        else if (msgType === 'video') fileFolder = 'chat/video';
        else if (msgType === 'audio') fileFolder = 'chat/audio';
        else if (msgType === 'file') fileFolder = 'chat/doc';
      }

      return {
        id: message.id,
        content: message.content,
        type: message.messageType,
        fileUrl: message.fileName && message.fileDirectory
          ? (buildFileUrlSync(message.fileDirectory, message.fileName, fileFolder) || '')
          : null,
        fileName: message.fileName,
        fileDirectory: message.fileDirectory,
        fileSize: message.fileSize,
        mimeType: message.mimeType,
        createdAt: message.createdAt.toISOString(),
        updatedAt: message.updatedAt.toISOString(),
        userId: message.userId,
        roomId: message.roomId,
        username: message.user.username,
        userAvatar: buildAvatarUrl(message.user) || message.user.avatarUrl,
        isEdited: message.updatedAt > message.createdAt,
        isDeleted: false,
      };
    });

    res.json({
      success: true,
      data: serializedMessages.reverse(), // Reverse to get chronological order
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: serializedMessages.length,
      },
    });
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch messages',
    });
  }
});

// Send a message to a chat room
app.post('/api/v1/chat/rooms/:roomId/messages', async (req, res) => {
  try {
    const currentUserId = await getCurrentUserId(req);
    
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    const { roomId } = req.params;
    const { content, type = 'TEXT', fileName, fileDirectory, fileSize, mimeType } = req.body;

    if (!content && !fileName) {
      res.status(400).json({
        success: false,
        message: 'Message content or file is required',
      });
      return;
    }

    // Check if user is participant in this room
    const room = await prisma.chatRoom.findFirst({
      where: {
        id: roomId,
        participants: {
          some: {
            userId: currentUserId,
          },
        },
      },
    });

    if (!room) {
      res.status(403).json({
        success: false,
        message: 'Access denied to this chat room',
      });
      return;
    }

    // Create message
    const message = await prisma.chatMessage.create({
      data: {
        content: content || '',
        messageType: type.toUpperCase() as any,
        fileName: fileName || null,
        fileDirectory: fileDirectory || null,
        fileSize: fileSize ? parseInt(fileSize) : null,
        mimeType: mimeType || null,
        userId: currentUserId,
        roomId: roomId,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            avatar: true,
            fileDirectory: true,
            isVerified: true,
          },
        },
      },
    });

    // Update room's updatedAt timestamp
    await prisma.chatRoom.update({
      where: { id: roomId },
      data: { updatedAt: new Date() },
    });

    // Determine file folder based on message type
    let fileFolder: string | undefined;
    if (message.fileName && message.fileDirectory) {
      const msgType = message.messageType.toLowerCase();
      if (msgType === 'image') fileFolder = 'chat/photo';
      else if (msgType === 'video') fileFolder = 'chat/video';
      else if (msgType === 'audio') fileFolder = 'chat/audio';
      else if (msgType === 'file') fileFolder = 'chat/doc';
    }

    // Serialize message with dynamic fileUrl
    const serializedMessage = {
      id: message.id,
      content: message.content,
      type: message.messageType,
      fileUrl: message.fileName && message.fileDirectory
        ? (buildFileUrlSync(message.fileDirectory, message.fileName, fileFolder) || '')
        : null,
      fileName: message.fileName,
      fileDirectory: message.fileDirectory,
      fileSize: message.fileSize,
      mimeType: message.mimeType,
      createdAt: message.createdAt.toISOString(),
      updatedAt: message.updatedAt.toISOString(),
      userId: message.userId,
      roomId: message.roomId,
      username: message.user.username,
      userAvatar: buildAvatarUrl(message.user) || message.user.avatarUrl,
      isEdited: false,
      isDeleted: false,
    };

    // Emit to Socket.IO for real-time updates
    io.to(`chat-${roomId}`).emit('new-message', serializedMessage);

    res.json({
      success: true,
      data: serializedMessage,
    });
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send message',
    });
  }
});

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log(`User connected: ${socket.id}`);

  // Join user to their personal room
  socket.on('join-user-room', (userId) => {
    socket.join(`user-${userId}`);
    console.log(`User ${userId} joined their room`);
  });

  // Join chat room
  socket.on('join-chat-room', (roomId) => {
    socket.join(`chat-${roomId}`);
    console.log(`User joined chat room: ${roomId}`);
  });

  // Leave chat room
  socket.on('leave-chat-room', (roomId) => {
    socket.leave(`chat-${roomId}`);
    console.log(`User left chat room: ${roomId}`);
  });

  // Handle chat messages
  socket.on('send-message', (data) => {
    const { roomId, message, userId, username } = data;
    
    // Broadcast message to room
    socket.to(`chat-${roomId}`).emit('new-message', {
      id: Date.now().toString(),
      roomId,
      userId,
      username,
      content: message,
      createdAt: new Date().toISOString(),
    });
  });

  // Handle typing indicators
  socket.on('typing-start', (data) => {
    const { roomId, userId, username } = data;
    socket.to(`chat-${roomId}`).emit('user-typing', {
      userId,
      username,
      isTyping: true,
    });
  });

  socket.on('typing-stop', (data) => {
    const { roomId, userId } = data;
    socket.to(`chat-${roomId}`).emit('user-typing', {
      userId,
      isTyping: false,
    });
  });

  // Handle video likes/comments
  socket.on('video-like', (data) => {
    const { videoId, userId, username } = data;
    socket.broadcast.emit('video-liked', {
      videoId,
      userId,
      username,
      timestamp: new Date().toISOString(),
    });
  });

  socket.on('video-comment', (data) => {
    const { videoId, userId, username, comment } = data;
    socket.broadcast.emit('video-commented', {
      videoId,
      userId,
      username,
      comment,
      timestamp: new Date().toISOString(),
    });
  });

  // Handle notifications
  socket.on('subscribe-notifications', (userId) => {
    socket.join(`notifications-${userId}`);
    console.log(`User ${userId} subscribed to notifications`);
  });

  socket.on('disconnect', () => {
    console.log(`User disconnected: ${socket.id}`);
  });
});

// ============================================
// Profile Management Routes
// ============================================

// Update user profile
app.put('/api/v1/users/profile', async (req, res) => {
  try {
    const currentUserId = await getCurrentUserId(req);
    
    // If no valid user, return 401 to trigger sign out
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }
    
    const { username, bio, firstName, lastName } = req.body;
    
    console.log(`📝 Updating profile for user: ${currentUserId}`);
    
    // Validate input
    if (!username || username.trim().length < 3) {
      res.status(400).json({
        success: false,
        message: 'Username must be at least 3 characters long',
      });
      return;
    }
    
    // Check if username is already taken by another user
    const existingUser = await prisma.user.findFirst({
      where: {
        username: username.trim(),
        id: { not: currentUserId },
      },
    });
    
    if (existingUser) {
      res.status(400).json({
        success: false,
        message: 'Username is already taken',
      });
      return;
    }
    
    // Update user profile
    const updatedUser = await prisma.user.update({
      where: { id: currentUserId },
      data: {
        username: username.trim(),
        bio: bio?.trim() || null,
        firstName: firstName?.trim() || null,
        lastName: lastName?.trim() || null,
        updatedAt: new Date(),
      },
      select: {
        id: true,
        username: true,
        email: true,
        firstName: true,
        lastName: true,
        bio: true,
        avatarUrl: true,
        bannerUrl: true,
        isVerified: true,
        role: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    
    console.log(`✅ Profile updated for user: ${updatedUser.username}`);
    
    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        ...updatedUser,
        createdAt: updatedUser.createdAt.toISOString(),
        updatedAt: updatedUser.updatedAt.toISOString(),
      },
    });
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update profile',
    });
  }
});

// Update user coin balance
app.put('/api/v1/users/coin-balance', authenticateToken, async (req, res): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
      return;
    }
    
    const { coinBalance, transactionType, description, paymentId, relatedPostId } = req.body;
    
    if (typeof coinBalance !== 'number' || coinBalance < 0) {
      res.status(400).json({
        success: false,
        message: 'Invalid coin balance value',
      });
      return;
    }
    
    console.log(`💰 Updating coin balance for user ${currentUserId}: ${coinBalance}`);
    
    // Get current user to calculate the difference
    const currentUser = await prisma.user.findUnique({
      where: { id: currentUserId },
      select: { coinBalance: true },
    });
    
    if (!currentUser) {
      res.status(404).json({
        success: false,
        message: 'User not found',
      });
      return;
    }
    
    const coinDifference = coinBalance - currentUser.coinBalance;
    
    // Update user's coin balance in database
    const updatedUser = await prisma.user.update({
      where: { id: currentUserId },
      data: { coinBalance },
      select: {
        id: true,
        username: true,
        email: true,
        firstName: true,
        lastName: true,
        bio: true,
        avatar: true,
        banner: true,
        avatarUrl: true,
        bannerUrl: true,
        isVerified: true,
        coinBalance: true,
        isVip: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    
    // Create coin transaction if there's a difference
    if (coinDifference !== 0 && transactionType) {
      await prisma.coinTransaction.create({
        data: {
          userId: currentUserId,
          type: transactionType, // 'RECHARGE', 'EARNED', or 'USED'
          amount: coinDifference,
          description: description || `Coin balance ${coinDifference > 0 ? 'increased' : 'decreased'} by ${Math.abs(coinDifference)} coins`,
          // Don't include paymentId for now to avoid foreign key constraint
          relatedPostId: relatedPostId || null, // Make it optional
          metadata: {
            previousBalance: currentUser.coinBalance,
            newBalance: coinBalance,
            difference: coinDifference,
            paymentId: paymentId, // Store in metadata instead
          },
        },
      });
      
      console.log(`✅ Created coin transaction: ${transactionType} ${coinDifference} coins`);
    }
    
    console.log(`✅ Coin balance updated successfully: ${updatedUser.coinBalance}`);
    
    res.json({
      success: true,
      message: 'Coin balance updated successfully',
      data: {
        coinBalance: updatedUser.coinBalance,
      },
    });
  } catch (error) {
    console.error('❌ Error updating coin balance:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update coin balance',
    });
  }
});

// Get coin transaction history

// Create coin transaction (internal use)
app.post('/api/v1/coin-transactions', authenticateToken, async (req, res): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
      return;
    }
    
    const {
      type,
      amount,
      description,
      relatedPostId,
      relatedUserId,
      paymentId,
      metadata,
    } = req.body;
    
    // Validate required fields
    if (!type || !['RECHARGE', 'EARNED', 'USED'].includes(type)) {
      res.status(400).json({
        success: false,
        message: 'Invalid transaction type',
      });
      return;
    }
    
    if (typeof amount !== 'number' || amount === 0) {
      res.status(400).json({
        success: false,
        message: 'Invalid amount',
      });
      return;
    }
    
    console.log(`💰 Creating coin transaction: ${type} ${amount} coins for user ${currentUserId}`);
    
    // Create transaction
    const transaction = await prisma.coinTransaction.create({
      data: {
        userId: currentUserId,
        type,
        amount,
        description,
        relatedPostId,
        relatedUserId,
        paymentId,
        metadata,
      },
      include: {
        relatedPost: {
          select: {
            id: true,
            title: true,
            type: true,
          },
        },
        relatedUser: {
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
          },
        },
        payment: {
          select: {
            id: true,
            amount: true,
            currency: true,
          },
        },
      },
    });
    
    console.log(`✅ Coin transaction created: ${transaction.id}`);
    
    res.json({
      success: true,
      data: {
        transaction: {
          id: transaction.id,
          type: transaction.type,
          amount: transaction.amount,
          status: transaction.status,
          description: transaction.description,
          relatedPost: transaction.relatedPost ? {
            id: transaction.relatedPost.id,
            title: transaction.relatedPost.title,
            type: transaction.relatedPost.type,
          } : null,
          relatedUser: transaction.relatedUser ? {
            id: transaction.relatedUser.id,
            username: transaction.relatedUser.username,
            name: `${transaction.relatedUser.firstName || ''} ${transaction.relatedUser.lastName || ''}`.trim() || transaction.relatedUser.username,
          } : null,
          payment: transaction.payment ? {
            id: transaction.payment.id,
            amount: transaction.payment.amount,
            currency: transaction.payment.currency,
          } : null,
          metadata: transaction.metadata,
          createdAt: transaction.createdAt,
          updatedAt: transaction.updatedAt,
        },
      },
    });
  } catch (error) {
    console.error('❌ Error creating coin transaction:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create coin transaction',
    });
  }
});

// Middleware to attach user info for upload
const attachUserInfoForUpload = async (req: any, res: any, next: any) => {
  const currentUserId = await getCurrentUserId(req);
  if (!currentUserId) {
    res.status(401).json({
      success: false,
      message: 'Authentication required - please sign in again',
    });
    return;
  }
  
  // Get user info for file directory generation
  const user = await prisma.user.findUnique({
    where: { id: currentUserId },
    select: { id: true, createdAt: true, fileDirectory: true, avatar: true, banner: true },
  });
  
  if (!user) {
    res.status(401).json({
      success: false,
      message: 'User not found',
    });
    return;
  }
  
  // Attach user info to request object
  (req as any).userId = user.id;
  (req as any).userCreatedAt = user.createdAt;
  (req as any).currentUser = user;
  next();
};

// Chat file upload configuration
const chatUpload = multer({ 
  storage: chatFileStorage,
  fileFilter: chatFileFilter,
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit
});

// Upload chat attachment
app.post('/api/v1/chat/upload', attachUserInfoForUpload, chatUpload.single('file'), async (req, res) => {
  try {
    const currentUserId = await getCurrentUserId(req);
    
    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required - please sign in again',
      });
      return;
    }

    if (!(req as any).file) {
      res.status(400).json({
        success: false,
        message: 'No file uploaded',
      });
      return;
    }

    const file = (req as any).file;
    
    res.json({
      success: true,
      data: {
        fileUrl: file.location,
        fileName: file.filename,
        fileDirectory: file.fileDirectory,
        folder: file.folder,
        fileSize: file.size,
        mimeType: file.mimetype,
        originalName: file.originalname,
      },
    });
  } catch (error) {
    console.error('Error uploading chat attachment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to upload file',
    });
  }
});

// Generate presigned URL for file access
app.post('/api/v1/files/presigned-url', async (req, res) => {
  try {
    const { objectKey } = req.body;
    
    if (!objectKey) {
      res.status(400).json({
        success: false,
        message: 'Object key is required',
      });
      return;
    }

    // Import S3 dependencies
    const { GetObjectCommand } = await import('@aws-sdk/client-s3');
    const { getSignedUrl } = await import('@aws-sdk/s3-request-presigner');
    const s3Client = (await import('./services/s3Service')).default;

    const command = new GetObjectCommand({
      Bucket: process.env['S3_BUCKET_NAME'] || '',
      Key: objectKey,
    });

    // Generate presigned URL valid for 1 hour
    const presignedUrl = await getSignedUrl(s3Client, command, {
      expiresIn: 3600, // 1 hour
    });

    res.json({
      success: true,
      data: {
        url: presignedUrl,
        expiresIn: 3600,
      },
    });
  } catch (error) {
    console.error('Error generating presigned URL:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate presigned URL',
    });
  }
});

// Upload avatar
app.post('/api/v1/users/avatar', attachUserInfoForUpload, upload.single('avatar'), async (req, res) => {
  try {
    const currentUserId = (req as any).userId;
    const currentUser = (req as any).currentUser;
    
    if (!req.file) {
      res.status(400).json({
        success: false,
        message: 'No avatar file provided',
      });
      return;
    }
    
    const fileInfo = req.file as any;
    console.log(`🖼️ Uploading avatar for user: ${currentUserId}`);
    
    // Delete old avatar from S3 if it exists
    if (currentUser.avatar && currentUser.fileDirectory) {
      await deleteFromS3({
        folder: 'avatars',
        fileDirectory: currentUser.fileDirectory,
        filename: currentUser.avatar,
      });
    }
    
    // Update user with new avatar info
    const updatedUser = await prisma.user.update({
      where: { id: currentUserId },
      data: {
        avatar: fileInfo.filename,
        fileDirectory: fileInfo.fileDirectory,
        updatedAt: new Date(),
      },
      select: {
        id: true,
        username: true,
        email: true,
        firstName: true,
        lastName: true,
        bio: true,
        avatar: true,
        banner: true,
        avatarUrl: true,
        bannerUrl: true,
        fileDirectory: true,
        isVerified: true,
        role: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    
    console.log(`✅ Avatar uploaded for user: ${updatedUser.username}`);
    
    // Build avatar URL dynamically
    const { serializeUserWithUrls } = await import('./utils/fileUrl');
    const serializedUser = serializeUserWithUrls(updatedUser);
    
    res.json({
      success: true,
      message: 'Avatar uploaded successfully',
      data: {
        ...serializedUser,
        createdAt: updatedUser.createdAt.toISOString(),
        updatedAt: updatedUser.updatedAt.toISOString(),
      },
    });
  } catch (error) {
    console.error('Error uploading avatar:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to upload avatar',
    });
  }
});

// Upload banner
app.post('/api/v1/users/banner', attachUserInfoForUpload, upload.single('banner'), async (req, res) => {
  try {
    const currentUserId = (req as any).userId;
    const currentUser = (req as any).currentUser;
    
    if (!req.file) {
      res.status(400).json({
        success: false,
        message: 'No banner file provided',
      });
      return;
    }
    
    const fileInfo = req.file as any;
    console.log(`🖼️ Uploading banner for user: ${currentUserId}`);
    
    // Delete old banner from S3 if it exists
    if (currentUser.banner && currentUser.fileDirectory) {
      await deleteFromS3({
        folder: 'banners',
        fileDirectory: currentUser.fileDirectory,
        filename: currentUser.banner,
      });
    }
    
    // Update user with new banner info
    const updatedUser = await prisma.user.update({
      where: { id: currentUserId },
      data: {
        banner: fileInfo.filename,
        fileDirectory: fileInfo.fileDirectory,
        updatedAt: new Date(),
      },
      select: {
        id: true,
        username: true,
        email: true,
        firstName: true,
        lastName: true,
        bio: true,
        avatar: true,
        banner: true,
        avatarUrl: true,
        bannerUrl: true,
        fileDirectory: true,
        isVerified: true,
        role: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    
    console.log(`✅ Banner uploaded for user: ${updatedUser.username}`);
    
    // Build banner URL dynamically
    const { serializeUserWithUrls } = await import('./utils/fileUrl');
    const serializedUser = serializeUserWithUrls(updatedUser);
    
    res.json({
      success: true,
      message: 'Banner uploaded successfully',
      data: {
        ...serializedUser,
        createdAt: updatedUser.createdAt.toISOString(),
        updatedAt: updatedUser.updatedAt.toISOString(),
      },
    });
  } catch (error) {
    console.error('Error uploading banner:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to upload banner',
    });
  }
});

// ============================================================================
// PAYMENT ENDPOINTS
// ============================================================================

// Get coin packages
app.get('/api/v1/payment/packages', (_req, res): void => {
  console.log('🎯 Payment packages endpoint called');
  try {
    const packages = paymentService.getCoinPackages();
    console.log('🎯 Packages retrieved:', packages.length);
    res.json({
      success: true,
      data: packages,
    });
    return;
  } catch (error) {
    console.error('Error getting coin packages:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get coin packages',
    });
    return;
  }
});

// Demo payment endpoint (no auth required)
app.post('/api/v1/payment/create-invoice-demo', async (req, res): Promise<void> => {
  try {
    const { coins, targetCurrency = 'BTC' } = req.body;

    if (!coins) {
      res.status(400).json({
        success: false,
        message: 'Coins amount is required',
      });
      return;
    }

    // Convert coins to USD
    const usdAmount = paymentService.coinsToUsd(coins);

    // Generate unique order ID
    const extOrderId = `DEMO${Date.now()}`;

    // Create payment invoice (demo)
    const paymentResponse = await paymentService.createInvoice({
      usdAmount,
      extOrderId,
      targetCurrency,
    });

    res.json({
      success: true,
      data: {
        orderId: extOrderId,
        paymentId: paymentResponse.id,
        amount: paymentResponse.amount,
        currency: paymentResponse.currencyCode,
        address: paymentResponse.addr,
        qrCode: paymentResponse.qrCode,
        paymentUri: paymentResponse.paymentUri,
        coins: coins,
        usdAmount: usdAmount,
      },
    });
  } catch (error) {
    console.error('❌ Payment invoice creation error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create payment invoice',
    });
  }
});

// Create payment invoice
app.post('/api/v1/payment/create-invoice', authenticateToken, async (req, res): Promise<void> => {
  try {
    const { coins, targetCurrency = 'BTC' } = req.body;
    const currentUserId = req.user?.id || 'demo-user-id'; // Fallback for demo

    if (!coins) {
      res.status(400).json({
        success: false,
        message: 'Coins amount is required',
      });
      return;
    }

    // Convert coins to USD
    const usdAmount = paymentService.coinsToUsd(coins);

    // Generate unique order ID
    const extOrderId = `ORD${Date.now()}`;

    // Create payment invoice
    const paymentResponse = await paymentService.createInvoice({
      usdAmount,
      extOrderId,
      targetCurrency,
    });

    // Store payment record in database
    await prisma.payment.create({
      data: {
        userId: currentUserId,
        extOrderId,
        amount: usdAmount,
        coins,
        currency: targetCurrency,
        status: 'PENDING',
        paymentId: paymentResponse.id,
        paymentAddress: paymentResponse.addr,
        paymentUri: paymentResponse.paymentUri,
        qrCode: paymentResponse.qrCode,
      },
    });

    res.json({
      success: true,
      data: {
        orderId: extOrderId,
        paymentId: paymentResponse.id,
        amount: paymentResponse.amount,
        currency: paymentResponse.currencyCode,
        address: paymentResponse.addr,
        paymentUri: paymentResponse.paymentUri,
        qrCode: paymentResponse.qrCode,
        coins,
        usdAmount,
      },
    });
    return;
  } catch (error) {
    console.error('Error creating payment invoice:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create payment invoice',
    });
    return;
  }
});

// Real USDT payment endpoint
app.post('/api/v1/payment/create-usdt-invoice', authenticateToken, async (req, res): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    const { coins } = req.body;

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
      return;
    }

    if (!coins) {
      res.status(400).json({
        success: false,
        message: 'Coins amount is required',
      });
      return;
    }

    // Convert coins to USD
    const usdAmount = paymentService.coinsToUsd(coins);

    // Generate unique order ID
    const extOrderId = `USDT${Date.now()}`;

    // Create USDT payment invoice
    const paymentResponse = await paymentService.createInvoice({
      usdAmount,
      extOrderId,
      targetCurrency: 'USDT',
    });

    // Store payment record in database
    await prisma.payment.create({
      data: {
        userId: currentUserId,
        extOrderId: extOrderId,
        amount: usdAmount,
        currency: 'USD',
        coins: coins,
        status: 'PENDING',
        paymentMethod: 'USDT',
        metadata: {
          paymentId: paymentResponse.id,
          address: paymentResponse.addr,
          qrCode: paymentResponse.qrCode,
        },
      },
    });

    res.json({
      success: true,
      data: {
        orderId: extOrderId,
        paymentId: paymentResponse.id,
        amount: paymentResponse.amount,
        currency: paymentResponse.currencyCode,
        address: paymentResponse.addr,
        qrCode: paymentResponse.qrCode,
        paymentUri: paymentResponse.paymentUri,
        coins: coins,
        usdAmount: usdAmount,
      },
    });
  } catch (error) {
    console.error('❌ USDT payment invoice creation error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create USDT payment invoice',
    });
    return;
  }
});

// Real Credit Card payment endpoint
app.post('/api/v1/payment/create-credit-card-invoice', authenticateToken, async (req, res): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    const { coins } = req.body;

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
      return;
    }

    if (!coins) {
      res.status(400).json({
        success: false,
        message: 'Coins amount is required',
      });
      return;
    }

    // Get user email
    const user = await prisma.user.findUnique({
      where: { id: currentUserId },
      select: { email: true, username: true },
    });

    if (!user) {
      res.status(404).json({
        success: false,
        message: 'User not found',
      });
      return;
    }

    // Convert coins to USD
    const usdAmount = paymentService.coinsToUsd(coins);

    // Generate unique order ID
    const extOrderId = `CC${Date.now()}`;

    // Create Credit Card payment invoice
    const paymentResponse = await paymentService.createCreditCardInvoice({
      amount: usdAmount,
      currency: 'USD',
      extOrderId: extOrderId,
      email: user.email,
      productName: `Coin Recharge - ${coins} coins`,
    });

    // Store payment record in database
    await prisma.payment.create({
      data: {
        userId: currentUserId,
        extOrderId: extOrderId,
        amount: usdAmount,
        currency: 'USD',
        coins: coins,
        status: 'PENDING',
        paymentMethod: 'CREDIT_CARD',
        metadata: {
          transId: paymentResponse.transId,
          endpointUrl: paymentResponse.endpointUrl,
          sign: paymentResponse.sign,
        },
      },
    });

    res.json({
      success: true,
      data: {
        orderId: extOrderId,
        transId: paymentResponse.transId,
        amount: paymentResponse.amount,
        currency: 'USD',
        endpointUrl: paymentResponse.endpointUrl,
        sign: paymentResponse.sign,
        coins: coins,
        usdAmount: usdAmount,
      },
    });
  } catch (error) {
    console.error('❌ Credit Card payment invoice creation error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create Credit Card payment invoice',
    });
    return;
  }
});

// Handle IPN notifications

// Extract IPN processing logic into a reusable function
async function processIPNNotification(notification: IPNNotification): Promise<void> {
  // Find payment record
  const payment = await prisma.payment.findUnique({
    where: { extOrderId: notification.extOrderId },
    include: { user: true },
  });

  if (!payment) {
    console.error('Payment not found:', notification.extOrderId);
    throw new Error('Payment not found');
  }

  if (notification.status === 'OK') {
    // Update payment status
    await prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: 'COMPLETED',
        transactionId: notification.btcTxid || notification.txid,
        completedAt: new Date(),
      },
    });

    // Add coins to user balance
    await prisma.user.update({
      where: { id: payment.userId },
      data: {
        coinBalance: {
          increment: payment.coins,
        },
      },
    });

    // Create coin transaction record
    await prisma.coinTransaction.create({
      data: {
        userId: payment.userId,
        type: 'RECHARGE',
        amount: payment.coins,
        description: `${payment.paymentMethod} coin recharge - ${payment.coins} coins`,
        paymentId: payment.id,
        metadata: {
          paymentMethod: payment.paymentMethod,
          transactionId: notification.btcTxid || notification.txid,
          gatewayNotification: notification as any, // Type assertion for JSON storage
        },
      },
    });

    console.log(`✅ Payment completed: ${payment.coins} coins added to user ${payment.userId}`);
  } else {
    // Update payment status to failed
    await prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: 'FAILED',
        completedAt: new Date(),
      },
    });

    console.log(`❌ Payment failed for order: ${notification.extOrderId}`);
  }
}

// Demo endpoint to simulate IPN for local development
app.post('/api/v1/payment/simulate-ipn/:orderId', async (req, res): Promise<void> => {
  try {
    const { orderId } = req.params;
    console.log('🎭 Simulating IPN for local development - Order ID:', orderId);
    
    // Find the payment record
    const payment = await prisma.payment.findUnique({
      where: { extOrderId: orderId },
      include: { user: true },
    });

    if (!payment) {
      res.status(404).json({ success: false, message: 'Payment not found' });
      return;
    }

    if (payment.status === 'COMPLETED') {
      res.json({ success: true, message: 'Payment already completed' });
      return;
    }

    // Simulate successful IPN notification
    const mockIPN: IPNNotification = {
      extOrderId: orderId,
      status: 'OK',
      sbpayMethod: payment.paymentMethod === 'USDT' ? 'cryptocurrency' : 'creditcard',
      currencyCode: payment.paymentMethod === 'USDT' ? 'USDT' : 'USD',
      btcTxid: payment.paymentMethod === 'USDT' ? `mock_tx_${Date.now()}` : '',
      txid: payment.paymentMethod === 'USDT' ? `mock_tx_${Date.now()}` : '',
      signature: 'mock_signature_for_local_dev',
    };

    // Process the mock IPN
    await processIPNNotification(mockIPN);

    res.json({ success: true, message: 'Mock IPN processed successfully' });
  } catch (error) {
    console.error('❌ Error simulating IPN:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// Payment status endpoint for frontend polling
app.get('/api/v1/payment/status/:orderId', authenticateToken, async (req, res): Promise<void> => {
  try {
    const { orderId } = req.params;
    
    const payment = await prisma.payment.findUnique({
      where: { extOrderId: orderId },
      select: {
        id: true,
        status: true,
        coins: true,
        amount: true,
        completedAt: true,
        transactionId: true,
      },
    });

    if (!payment) {
      res.status(404).json({ success: false, message: 'Payment not found' });
      return;
    }

    res.json({
      success: true,
      data: {
        status: payment.status,
        coins: payment.coins,
        amount: payment.amount,
        completedAt: payment.completedAt,
        transactionId: payment.transactionId,
      },
    });
  } catch (error) {
    console.error('❌ Error checking payment status:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

app.post('/api/v1/payment/ipn', express.urlencoded({ extended: true }), async (req, res): Promise<void> => {
  try {
    const notification: IPNNotification = req.body;

    console.log('🎯 IPN notification received:', notification);

    // For demo purposes, accept all notifications
    // In production, verify signature
    if (!paymentService.verifyIPNSignature(notification)) {
      console.error('Invalid IPN signature:', notification);
      res.status(400).send('Invalid signature');
      return;
    }

    await processIPNNotification(notification);

    res.send('OK');
    return;
  } catch (error) {
    console.error('Error processing IPN:', error);
    res.status(500).send('Internal server error');
    return;
  }
});

// Get user's payment history
app.get('/api/v1/payment/history', authenticateToken, async (req, res): Promise<void> => {
  try {
    const currentUserId = req.user?.id;
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
      return;
    }

    const payments = await prisma.payment.findMany({
      where: { userId: currentUserId },
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: Number(limit),
      select: {
        id: true,
        extOrderId: true,
        amount: true,
        coins: true,
        currency: true,
        status: true,
        createdAt: true,
        completedAt: true,
      },
    });

    res.json({
      success: true,
      data: payments,
    });
    return;
  } catch (error) {
    console.error('Error getting payment history:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get payment history',
    });
    return;
  }
});

// Unlock a post (mark as permanently unlocked for user)
app.post('/api/v1/posts/:postId/unlock', authenticateToken, async (req, res): Promise<void> => {
  try {
    const { postId } = req.params;
    const currentUserId = req.user?.id;

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
      return;
    }

    // Check if post exists and requires payment
    const post = await prisma.communityPost.findUnique({
      where: { id: postId },
      select: { 
        id: true, 
        cost: true, 
        requiresVip: true, 
        userId: true,
        title: true,
        user: {
          select: {
            id: true,
            username: true,
            coinBalance: true,
          },
        },
      },
    });

    if (!post) {
      res.status(404).json({
        success: false,
        message: 'Post not found',
      });
      return;
    }

    // Check if post actually requires payment
    if (post.cost === 0 && !post.requiresVip) {
      res.status(400).json({
        success: false,
        message: 'Post does not require payment',
      });
      return;
    }

    // Check if user already unlocked this post
    const existingUnlock = await prisma.unlockedPost.findUnique({
      where: {
        userId_postId: {
          userId: currentUserId,
          postId: postId,
        },
      },
    });

    if (existingUnlock) {
      res.json({
        success: true,
        message: 'Post already unlocked',
        data: { unlocked: true },
      });
      return;
    }

    // Create unlock record
    await prisma.unlockedPost.create({
      data: {
        userId: currentUserId,
        postId: postId,
      },
    });

    console.log(`✅ Post ${postId} unlocked for user ${currentUserId}`);

    // Create EARNED transaction for post author (only for coin posts, not VIP posts)
    if (post.cost > 0 && post.userId !== currentUserId) {
      try {
        // Add coins to author's balance
        await prisma.user.update({
          where: { id: post.userId },
          data: {
            coinBalance: {
              increment: post.cost,
            },
          },
        });

        // Create EARNED transaction for author
        await prisma.coinTransaction.create({
          data: {
            userId: post.userId,
            type: 'EARNED',
            amount: post.cost,
            description: `Earned ${post.cost} coins from post "${post.title || 'Untitled'}"`,
            relatedPostId: postId,
            relatedUserId: currentUserId, // The buyer
            metadata: {
              postTitle: post.title,
              buyerId: currentUserId,
              earnings: post.cost,
              unlockType: 'post_purchase',
            },
          },
        });

        console.log(`💰 Author ${post.userId} earned ${post.cost} coins from post ${postId} (bought by ${currentUserId})`);
      } catch (error) {
        console.error('❌ Error creating earned transaction:', error);
        // Don't fail the unlock if earning transaction fails
      }
    }

    res.json({
      success: true,
      message: 'Post unlocked successfully',
      data: { unlocked: true },
    });
  } catch (error) {
    console.error('❌ Error unlocking post:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to unlock post',
    });
  }
});

// Check if user has unlocked a specific post
app.get('/api/v1/posts/:postId/unlock-status', authenticateToken, async (req, res): Promise<void> => {
  try {
    const { postId } = req.params;
    const currentUserId = req.user?.id;

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
      return;
    }

    // Check if user has unlocked this post
    const unlockRecord = await prisma.unlockedPost.findUnique({
      where: {
        userId_postId: {
          userId: currentUserId,
          postId: postId,
        },
      },
    });

    res.json({
      success: true,
      data: { 
        unlocked: !!unlockRecord,
        unlockedAt: unlockRecord?.unlockedAt || null,
      },
    });
  } catch (error) {
    console.error('❌ Error checking unlock status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to check unlock status',
    });
  }
});

// Get all unlocked posts for current user
app.get('/api/v1/users/unlocked-posts', authenticateToken, async (req, res): Promise<void> => {
  try {
    const currentUserId = req.user?.id;

    if (!currentUserId) {
      res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
      return;
    }

    const unlockedPosts = await prisma.unlockedPost.findMany({
      where: { userId: currentUserId },
      include: {
        post: {
          select: {
            id: true,
            title: true,
            content: true,
            type: true,
            images: true,
            videos: true,
            cost: true,
            requiresVip: true,
            createdAt: true,
          },
        },
      },
      orderBy: { unlockedAt: 'desc' },
    });

    res.json({
      success: true,
      data: unlockedPosts,
    });
  } catch (error) {
    console.error('❌ Error getting unlocked posts:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get unlocked posts',
    });
  }
});

// 404 handler
app.use('*', (_req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
});

// Global error handler
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Global error handler:', err);

  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
    ...(process.env['NODE_ENV'] === 'development' && { stack: err.stack }),
  });
});

// Start server
const startServer = async () => {
  try {
    console.log('🚀 Starting Blue Video API server in LOCAL DEVELOPMENT mode...');
    console.log('📊 Using real database data with Prisma');
    console.log('🔧 Redis disabled for local testing');
    
    server.listen(PORT, () => {
      console.log(`🚀 Blue Video API server running on port ${PORT}`);
      console.log(`📊 Health check: http://localhost:${PORT}/health`);
      console.log(`🔗 API Base URL: http://localhost:${PORT}/api/${process.env['API_VERSION'] || 'v1'}`);
      console.log(`🌍 Environment: ${process.env['NODE_ENV'] || 'development'}`);
      console.log(`\n📝 Available endpoints:`);
      console.log(`   GET  /health - Health check`);
      console.log(`   GET  /api/v1/test - Test endpoint`);
      console.log(`   POST /api/v1/auth/login - Mock login`);
      console.log(`   POST /api/v1/auth/register - Mock registration`);
      console.log(`   GET  /api/v1/videos - Real videos from database`);
      console.log(`   POST /api/v1/videos/upload - Mock video upload`);
      console.log(`   GET  /api/v1/community/posts - Real community posts from database`);
      console.log(`\n🔌 WebSocket ready for real-time features`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Start the server
startServer();

export { app, server, io };
