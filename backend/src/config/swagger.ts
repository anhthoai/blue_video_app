import swaggerJsdoc from 'swagger-jsdoc';

const swaggerOptions: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Blue Video API',
      version: '1.0.0',
      description: 'Blue Video Platform API - A comprehensive video sharing and social media platform',
      contact: {
        name: 'Blue Video Team',
        email: 'support@bluevideo.com',
      },
      license: {
        name: 'MIT',
        url: 'https://opensource.org/licenses/MIT',
      },
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: 'Development server',
      },
      {
        url: 'https://api.onlybl.com',
        description: 'Production server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Enter your JWT token',
        },
      },
      schemas: {
        Error: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean',
              example: false,
            },
            message: {
              type: 'string',
              example: 'Error message',
            },
          },
        },
        User: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: 'user-123',
            },
            username: {
              type: 'string',
              example: 'johndoe',
            },
            email: {
              type: 'string',
              example: 'john@example.com',
            },
            displayName: {
              type: 'string',
              example: 'John Doe',
            },
            avatarUrl: {
              type: 'string',
              nullable: true,
              example: 'https://cdn.example.com/avatar.jpg',
            },
            bio: {
              type: 'string',
              nullable: true,
              example: 'Video creator and enthusiast',
            },
            isVerified: {
              type: 'boolean',
              example: false,
            },
            coinBalance: {
              type: 'number',
              example: 1000,
            },
            followersCount: {
              type: 'number',
              example: 100,
            },
            followingCount: {
              type: 'number',
              example: 50,
            },
          },
        },
        Video: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: 'video-123',
            },
            title: {
              type: 'string',
              example: 'Amazing Video Title',
            },
            description: {
              type: 'string',
              nullable: true,
              example: 'This is an amazing video description',
            },
            videoUrl: {
              type: 'string',
              example: 'https://cdn.example.com/video.mp4',
            },
            thumbnailUrl: {
              type: 'string',
              nullable: true,
              example: 'https://cdn.example.com/thumbnail.jpg',
            },
            duration: {
              type: 'string',
              example: '5:30',
            },
            views: {
              type: 'number',
              example: 1000,
            },
            likes: {
              type: 'number',
              example: 50,
            },
            categoryId: {
              type: 'string',
              example: 'cat-entertainment',
            },
            userId: {
              type: 'string',
              example: 'user-123',
            },
            status: {
              type: 'string',
              enum: ['draft', 'published', 'private'],
              example: 'published',
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
            },
          },
        },
        Post: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: 'post-123',
            },
            content: {
              type: 'string',
              example: 'This is a post content',
            },
            imageUrls: {
              type: 'array',
              items: {
                type: 'string',
              },
              example: ['https://cdn.example.com/image1.jpg'],
            },
            videoUrls: {
              type: 'array',
              items: {
                type: 'string',
              },
              example: [],
            },
            userId: {
              type: 'string',
              example: 'user-123',
            },
            likes: {
              type: 'number',
              example: 10,
            },
            comments: {
              type: 'number',
              example: 5,
            },
            shares: {
              type: 'number',
              example: 2,
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
            },
          },
        },
        Category: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: 'cat-entertainment',
            },
            categoryName: {
              type: 'string',
              example: 'Entertainment',
            },
            categoryDesc: {
              type: 'string',
              nullable: true,
              example: 'Entertainment videos',
            },
            categoryThumb: {
              type: 'string',
              nullable: true,
              example: 'https://cdn.example.com/category.jpg',
            },
            videoCount: {
              type: 'number',
              example: 100,
            },
          },
        },
        Comment: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: 'comment-123',
            },
            content: {
              type: 'string',
              example: 'Great video!',
            },
            userId: {
              type: 'string',
              example: 'user-123',
            },
            videoId: {
              type: 'string',
              nullable: true,
              example: 'video-123',
            },
            postId: {
              type: 'string',
              nullable: true,
              example: 'post-123',
            },
            likes: {
              type: 'number',
              example: 5,
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
            },
          },
        },
        ChatRoom: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: 'room-123',
            },
            name: {
              type: 'string',
              nullable: true,
              example: 'Chat Room',
            },
            isGroup: {
              type: 'boolean',
              example: false,
            },
            participants: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/User',
              },
            },
            lastMessage: {
              type: 'object',
              nullable: true,
            },
            unreadCount: {
              type: 'number',
              example: 0,
            },
          },
        },
        CoinPackage: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: 'pkg-1',
            },
            name: {
              type: 'string',
              example: 'Starter Pack',
            },
            coins: {
              type: 'number',
              example: 100,
            },
            price: {
              type: 'number',
              example: 0.99,
            },
            currency: {
              type: 'string',
              example: 'USD',
            },
            popular: {
              type: 'boolean',
              example: false,
            },
          },
        },
      },
    },
    tags: [
      {
        name: 'Health',
        description: 'Health check endpoints',
      },
      {
        name: 'Authentication',
        description: 'User authentication and authorization',
      },
      {
        name: 'Users',
        description: 'User management and profiles',
      },
      {
        name: 'Videos',
        description: 'Video upload, management, and discovery',
      },
      {
        name: 'Categories',
        description: 'Video categories management',
      },
      {
        name: 'Community',
        description: 'Community posts and social features',
      },
      {
        name: 'Comments',
        description: 'Comment management for videos and posts',
      },
      {
        name: 'Search',
        description: 'Search for videos, posts, and users',
      },
      {
        name: 'Chat',
        description: 'Real-time messaging and chat rooms',
      },
      {
        name: 'Social',
        description: 'Social interactions (follow, like, share)',
      },
      {
        name: 'Payment',
        description: 'Payment and coin transactions',
      },
      {
        name: 'Playlists',
        description: 'Video playlists management',
      },
      {
        name: 'Files',
        description: 'File upload and management',
      },
      {
        name: 'VIP',
        description: 'VIP subscriptions and packages',
      },
    ],
  },
  apis: ['./src/server.ts', './src/routes/*.ts'], // Path to files with JSDoc comments
};

export const swaggerSpec = swaggerJsdoc(swaggerOptions);

