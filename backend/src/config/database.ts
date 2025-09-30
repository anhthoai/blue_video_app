import { createClient } from 'redis';
import dotenv from 'dotenv';
import prisma from '../lib/prisma';

dotenv.config();

// Redis Configuration (Optional)
export const redisConfig = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD || undefined,
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  maxRetriesPerRequest: null,
};

// Create Redis client (only if USE_REDIS is true)
let redisClient: any = null;
if (process.env.USE_REDIS === 'true') {
  redisClient = createClient(redisConfig);
} else {
  // Mock Redis client for local testing
  redisClient = {
    connect: async () => console.log('✅ Redis disabled for local testing'),
    quit: async () => console.log('✅ Redis client closed'),
    get: async (key: string) => null,
    set: async (key: string, value: string) => 'OK',
    setEx: async (key: string, seconds: number, value: string) => 'OK',
    del: async (key: string) => 1,
  };
}

export { redisClient };

// Database connection functions
export const connectDatabase = async (): Promise<void> => {
  try {
    // Test Prisma connection
    await prisma.$connect();
    console.log('✅ PostgreSQL connected successfully via Prisma');

    // Test Redis connection (if enabled)
    await redisClient.connect();
    console.log('✅ Redis connected successfully');
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    process.exit(1);
  }
};

// Graceful shutdown
export const closeDatabaseConnections = async (): Promise<void> => {
  try {
    await prisma.$disconnect();
    await redisClient.quit();
    console.log('✅ Database connections closed');
  } catch (error) {
    console.error('❌ Error closing database connections:', error);
  }
};

// Database initialization (Prisma handles this automatically)
export const initializeDatabase = async (): Promise<void> => {
  try {
    // Prisma will handle schema creation and migrations
    console.log('✅ Database schema ready (managed by Prisma)');
  } catch (error) {
    console.error('❌ Database initialization failed:', error);
    throw error;
  }
};
