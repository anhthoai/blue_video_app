import { Router } from 'express';
import { CommunityController } from '../controllers/communityController';
import { authenticateToken, optionalAuth } from '../middleware/auth';
import { uploadMiddleware, handleUploadError } from '../config/storage';

const router = Router();
const communityController = new CommunityController();

/**
 * @route POST /api/v1/community/posts
 * @desc Create a new community post
 * @access Private
 */
router.post('/posts', authenticateToken, communityController.createPost);

/**
 * @route GET /api/v1/community/posts/:id
 * @desc Get post by ID
 * @access Public
 */
router.get('/posts/:id', optionalAuth, communityController.getPost);

/**
 * @route GET /api/v1/community/posts
 * @desc Get posts feed
 * @access Public
 */
router.get('/posts', optionalAuth, communityController.getFeed);

/**
 * @route GET /api/v1/community/trending
 * @desc Get trending posts
 * @access Public
 */
router.get('/trending', optionalAuth, communityController.getTrending);

/**
 * @route GET /api/v1/community/search
 * @desc Search posts
 * @access Public
 */
router.get('/search', optionalAuth, communityController.searchPosts);

/**
 * @route GET /api/v1/community/posts/user/:userId
 * @desc Get user's posts
 * @access Public
 */
router.get('/posts/user/:userId', optionalAuth, communityController.getUserPosts);

/**
 * @route GET /api/v1/community/posts/category/:category
 * @desc Get posts by category
 * @access Public
 */
router.get('/posts/category/:category', optionalAuth, communityController.getPostsByCategory);

/**
 * @route PUT /api/v1/community/posts/:id
 * @desc Update post
 * @access Private
 */
router.put('/posts/:id', authenticateToken, communityController.updatePost);

/**
 * @route DELETE /api/v1/community/posts/:id
 * @desc Delete post
 * @access Private
 */
router.delete('/posts/:id', authenticateToken, communityController.deletePost);

/**
 * @route GET /api/v1/community/stats
 * @desc Get post statistics
 * @access Public
 */
router.get('/stats', communityController.getPostStats);

/**
 * @route GET /api/v1/community/categories
 * @desc Get categories
 * @access Public
 */
router.get('/categories', communityController.getCategories);

/**
 * @route POST /api/v1/community/posts/:id/vote
 * @desc Vote on poll
 * @access Private
 */
router.post('/posts/:id/vote', authenticateToken, communityController.votePoll);

export default router;
