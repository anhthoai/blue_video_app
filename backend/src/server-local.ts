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

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const JWT_SECRET = process.env['JWT_SECRET'] || 'your_super_secret_jwt_key_here';
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    
    // Attach user info to request
    req.user = {
      id: decoded.userId,
      email: decoded.email,
    };
    
    next();
  } catch (error) {
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
    
    if (!email || !password) {
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
      res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
      return;
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);

    if (!isPasswordValid) {
      res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
      return;
    }

    // Check if user is active
    if (!user.isActive) {
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
          createdAt: user.createdAt.toISOString(),
        },
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

    // Use manual counts as they are more reliable
    const serializedUser = {
      id: user.id,
      username: user.username,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      bio: user.bio,
      avatarUrl: buildAvatarUrl(user) || user.avatarUrl || null,
      isVerified: user.isVerified,
      role: user.role,
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
    
    // Get comments from database using Prisma
    const comments = await prisma.comment.findMany({
      where: {
        contentId: String(contentId),
        contentType: String(contentType).toUpperCase() as any,
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
    
    const serializedComments = parentComments.map(comment => {
      const replies = childComments
        .filter(c => c.parentId === comment.id)
        .map(reply => ({
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
          userAvatar: buildAvatarUrl(reply.user) || reply.user.avatarUrl || null,
          isVerified: reply.user.isVerified,
        }));

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
        userAvatar: buildAvatarUrl(comment.user) || comment.user.avatarUrl || null,
        isVerified: comment.user.isVerified,
        replies: replies,
      };
    });

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

    // Create comment in database
    const comment = await prisma.comment.create({
      data: {
        userId: currentUserId,
        contentId: String(contentId),
        contentType: String(contentType).toUpperCase() as any,
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

    // Update comment count on the video
    await prisma.video.update({
      where: { id: contentId },
      data: {
        comments: {
          increment: 1,
        },
      },
    });

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
      userAvatar: buildAvatarUrl(comment.user) || comment.user.avatarUrl || null,
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
          contentId: comment.contentId,
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

// Community posts endpoint using real database data
app.get('/api/v1/community/posts', async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    
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

    // Add file URLs to posts
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

        // Build avatar URL (async)
        const avatarUrl = post.user.avatar && post.user.fileDirectory
          ? await buildFileUrl(post.user.fileDirectory, post.user.avatar, 'avatars')
          : post.user.avatarUrl;

        return {
          ...post,
          username: post.user.username,
          firstName: post.user.firstName,
          lastName: post.user.lastName,
          isVerified: post.user.isVerified,
          userAvatar: avatarUrl,
          imageUrls: imageUrls.filter((url) => url != null),
          videoUrls: videoUrls.filter((url) => url != null),
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

    if (uploadedFiles.length > 0) {
      try {
        const uploadResult = await uploadCommunityPostFiles(uploadedFiles, newPost.id);
        fileDirectory = uploadResult.fileDirectory;
        images = uploadResult.images;
        videos = uploadResult.videos;

        // Update the post with file information
        await prisma.communityPost.update({
          where: { id: newPost.id },
          data: {
            fileDirectory,
            images,
            videos,
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
