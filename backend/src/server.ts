import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';

// Import database and storage
import { connectDatabase, initializeDatabase } from './config/database';
import { redisClient } from './config/database';

// Import routes
import authRoutes from './routes/auth';
import videoRoutes from './routes/videos';
import communityRoutes from './routes/community';
import userRoutes from './routes/users';
import chatRoutes from './routes/chat';
import socialRoutes from './routes/social';

// Load environment variables
dotenv.config();

const app = express();
const server = createServer(app);
const io = new SocketIOServer(server, {
  cors: {
    origin: process.env.SOCKET_CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
    methods: ['GET', 'POST'],
  },
});

const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'), // limit each IP to 100 requests per windowMs
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
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Blue Video API is running',
    timestamp: new Date().toISOString(),
    version: process.env.API_VERSION || 'v1',
  });
});

// API routes
app.use(`/api/${process.env.API_VERSION || 'v1'}/auth`, authRoutes);
app.use(`/api/${process.env.API_VERSION || 'v1'}/videos`, videoRoutes);
app.use(`/api/${process.env.API_VERSION || 'v1'}/community`, communityRoutes);
app.use(`/api/${process.env.API_VERSION || 'v1'}/users`, userRoutes);
app.use(`/api/${process.env.API_VERSION || 'v1'}/chat`, chatRoutes);
app.use(`/api/${process.env.API_VERSION || 'v1'}/social`, socialRoutes);

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
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
});

// Global error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Global error handler:', err);
  
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

// Graceful shutdown
const gracefulShutdown = async (signal: string) => {
  console.log(`\n${signal} received. Starting graceful shutdown...`);
  
  try {
    // Close HTTP server
    server.close(() => {
      console.log('HTTP server closed');
    });

    // Close Socket.IO server
    io.close(() => {
      console.log('Socket.IO server closed');
    });

    // Close database connections
    await redisClient.quit();
    console.log('Redis connection closed');
    
    console.log('Graceful shutdown completed');
    process.exit(0);
  } catch (error) {
    console.error('Error during graceful shutdown:', error);
    process.exit(1);
  }
};

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Start server
const startServer = async () => {
  try {
    // Connect to database
    await connectDatabase();
    
    // Initialize database tables
    await initializeDatabase();
    
    // Start HTTP server
    server.listen(PORT, () => {
      console.log(`🚀 Blue Video API server running on port ${PORT}`);
      console.log(`📊 Health check: http://localhost:${PORT}/health`);
      console.log(`🔗 API Base URL: http://localhost:${PORT}/api/${process.env.API_VERSION || 'v1'}`);
      console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Start the server
startServer();

export { app, server, io };
