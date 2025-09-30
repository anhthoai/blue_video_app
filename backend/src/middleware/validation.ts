import { Request, Response, NextFunction } from 'express';
import Joi from 'joi';

// Validation schemas
export const registerSchema = Joi.object({
  username: Joi.string().alphanum().min(3).max(30).required(),
  email: Joi.string().email().required(),
  password: Joi.string().min(6).required(),
  first_name: Joi.string().max(100).optional(),
  last_name: Joi.string().max(100).optional(),
  bio: Joi.string().max(500).optional(),
});

export const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().required(),
});

export const refreshTokenSchema = Joi.object({
  refreshToken: Joi.string().required(),
});

export const changePasswordSchema = Joi.object({
  currentPassword: Joi.string().required(),
  newPassword: Joi.string().min(6).required(),
});

export const updateProfileSchema = Joi.object({
  first_name: Joi.string().max(100).optional(),
  last_name: Joi.string().max(100).optional(),
  bio: Joi.string().max(500).optional(),
});

export const createPostSchema = Joi.object({
  title: Joi.string().max(255).optional(),
  content: Joi.string().max(5000).optional(),
  type: Joi.string().valid('text', 'link', 'poll', 'media').required(),
  images: Joi.array().items(Joi.string().uri()).optional(),
  videos: Joi.array().items(Joi.string().uri()).optional(),
  link_url: Joi.string().uri().optional(),
  link_title: Joi.string().max(255).optional(),
  link_description: Joi.string().max(500).optional(),
  poll_options: Joi.array().items(Joi.string().max(100)).min(2).max(10).optional(),
  tags: Joi.array().items(Joi.string().max(50)).max(10).optional(),
  category: Joi.string().max(50).optional(),
});

export const updatePostSchema = Joi.object({
  title: Joi.string().max(255).optional(),
  content: Joi.string().max(5000).optional(),
  images: Joi.array().items(Joi.string().uri()).optional(),
  videos: Joi.array().items(Joi.string().uri()).optional(),
  link_url: Joi.string().uri().optional(),
  link_title: Joi.string().max(255).optional(),
  link_description: Joi.string().max(500).optional(),
  poll_options: Joi.array().items(Joi.string().max(100)).min(2).max(10).optional(),
  poll_votes: Joi.object().optional(),
  tags: Joi.array().items(Joi.string().max(50)).max(10).optional(),
  category: Joi.string().max(50).optional(),
  is_public: Joi.boolean().optional(),
});

export const createCommentSchema = Joi.object({
  content: Joi.string().max(1000).required(),
  parentId: Joi.string().uuid().optional(),
});

export const updateCommentSchema = Joi.object({
  content: Joi.string().max(1000).required(),
});

export const createRoomSchema = Joi.object({
  name: Joi.string().max(255).optional(),
  type: Joi.string().valid('private', 'group').default('private'),
  participantIds: Joi.array().items(Joi.string().uuid()).min(1).required(),
});

export const sendMessageSchema = Joi.object({
  content: Joi.string().max(2000).optional(),
  message_type: Joi.string().valid('text', 'image', 'video', 'file').default('text'),
  file_url: Joi.string().uri().optional(),
});

export const votePollSchema = Joi.object({
  option: Joi.string().max(100).required(),
});

// Validation middleware
export const validate = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error } = schema.validate(req.body);
    
    if (error) {
      res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
        })),
      });
      return;
    }
    
    next();
  };
};

// Query validation middleware
export const validateQuery = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error } = schema.validate(req.query);
    
    if (error) {
      res.status(400).json({
        success: false,
        message: 'Query validation error',
        errors: error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
        })),
      });
      return;
    }
    
    next();
  };
};

// Params validation middleware
export const validateParams = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error } = schema.validate(req.params);
    
    if (error) {
      res.status(400).json({
        success: false,
        message: 'Parameter validation error',
        errors: error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
        })),
      });
      return;
    }
    
    next();
  };
};

// Common query schemas
export const paginationSchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

export const searchSchema = Joi.object({
  q: Joi.string().min(1).max(100).required(),
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

export const userIdSchema = Joi.object({
  userId: Joi.string().uuid().required(),
});

export const contentIdSchema = Joi.object({
  contentId: Joi.string().uuid().required(),
});

export const contentTypeSchema = Joi.object({
  contentType: Joi.string().valid('video', 'post', 'comment').required(),
});
