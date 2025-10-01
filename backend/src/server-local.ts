import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import prisma from './lib/prisma';

// Load environment variables
dotenv.config();

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

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env['RATE_LIMIT_WINDOW_MS'] || '900000'), // 15 minutes
  max: parseInt(process.env['RATE_LIMIT_MAX_REQUESTS'] || '100'), // limit each IP to 100 requests per windowMs
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.',
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

// Mock authentication endpoint
app.post('/api/v1/auth/login', (req, res) => {
  const { email, password } = req.body;
  
  if (!email || !password) {
    res.status(400).json({
      success: false,
      message: 'Email and password are required',
    });
    return;
  }

  // Mock successful login
  res.json({
    success: true,
    message: 'Login successful (Mock)',
    data: {
      user: {
        id: 'mock-user-id',
        username: 'testuser',
        email: email,
        firstName: 'Test',
        lastName: 'User',
        avatarUrl: null,
        isVerified: false,
        createdAt: new Date().toISOString(),
      },
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
    },
  });
});

// Mock user registration
app.post('/api/v1/auth/register', (req, res) => {
  const { username, email, password, firstName, lastName, bio } = req.body;
  
  if (!username || !email || !password) {
    res.status(400).json({
      success: false,
      message: 'Username, email, and password are required',
    });
    return;
  }

  // Mock successful registration
  res.status(201).json({
    success: true,
    message: 'User registered successfully (Mock)',
    data: {
      user: {
        id: 'mock-user-id',
        username,
        email,
        firstName,
        lastName,
        bio,
        avatarUrl: null,
        isVerified: false,
        createdAt: new Date().toISOString(),
      },
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
    },
  });
});

// Mock video upload endpoint
app.post('/api/v1/videos/upload', (req, res) => {
  res.json({
    success: true,
    message: 'Video upload endpoint ready (Mock)',
    data: {
      id: 'mock-video-id',
      title: req.body.title || 'Mock Video',
      description: req.body.description || 'Mock description',
      videoUrl: 'https://example.com/mock-video.mp4',
      thumbnailUrl: 'https://example.com/mock-thumbnail.jpg',
      duration: 120,
      fileSize: 1024000,
      quality: '720p',
      views: 0,
      likes: 0,
      comments: 0,
      shares: 0,
      isPublic: true,
      createdAt: new Date().toISOString(),
    },
  });
});

// Get single video by ID
app.get('/api/v1/videos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
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
      isPublic: video.isPublic,
      createdAt: video.createdAt.toISOString(),
      updatedAt: video.updatedAt.toISOString(),
      user: video.user ? {
        id: video.user.id,
        username: video.user.username,
        firstName: video.user.firstName,
        lastName: video.user.lastName,
        avatarUrl: video.user.avatarUrl,
        isVerified: video.user.isVerified,
      } : null,
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
      isPublic: video.isPublic,
      createdAt: video.createdAt.toISOString(),
      updatedAt: video.updatedAt.toISOString(),
      user: video.user ? {
        id: video.user.id,
        username: video.user.username,
        firstName: video.user.firstName,
        lastName: video.user.lastName,
        avatarUrl: video.user.avatarUrl,
        isVerified: video.user.isVerified,
      } : null,
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
    console.error('Error fetching videos:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch videos',
    });
  }
});

// Get comments for content (video or post)
app.get('/api/v1/social/comments', async (req, res) => {
  try {
    const { contentId, contentType } = req.query;
    
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
            isVerified: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    // Convert to camelCase
    const serializedComments = comments.map(comment => ({
      id: comment.id,
      userId: comment.userId,
      contentId: comment.contentId,
      contentType: comment.contentType,
      content: comment.content,
      likes: comment.likes,
      parentCommentId: comment.parentId,
      createdAt: comment.createdAt.toISOString(),
      updatedAt: comment.updatedAt.toISOString(),
      username: comment.user.firstName && comment.user.lastName 
        ? `${comment.user.firstName} ${comment.user.lastName}`
        : comment.user.username,
      userAvatar: comment.user.avatarUrl,
      isVerified: comment.user.isVerified,
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
    console.error('Error fetching community posts:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch community posts',
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
