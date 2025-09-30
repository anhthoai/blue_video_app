import { Router } from 'express';
import { UserController } from '../controllers/userController';
import { authenticateToken, optionalAuth } from '../middleware/auth';
import { uploadMiddleware, handleUploadError } from '../config/storage';

const router = Router();
const userController = new UserController();

/**
 * @route GET /api/v1/users/:userId
 * @desc Get user profile
 * @access Public
 */
router.get('/:userId', optionalAuth, userController.getProfile);

/**
 * @route PUT /api/v1/users/profile
 * @desc Update user profile
 * @access Private
 */
router.put('/profile', authenticateToken, userController.updateProfile);

/**
 * @route POST /api/v1/users/avatar
 * @desc Upload profile picture
 * @access Private
 */
router.post(
  '/avatar',
  authenticateToken,
  uploadMiddleware.single('avatar'),
  handleUploadError,
  userController.uploadAvatar
);

/**
 * @route GET /api/v1/users/search
 * @desc Search users
 * @access Public
 */
router.get('/search', userController.searchUsers);

/**
 * @route GET /api/v1/users/:userId/followers
 * @desc Get user's followers
 * @access Public
 */
router.get('/:userId/followers', userController.getFollowers);

/**
 * @route GET /api/v1/users/:userId/following
 * @desc Get user's following
 * @access Public
 */
router.get('/:userId/following', userController.getFollowing);

/**
 * @route POST /api/v1/users/:userId/follow
 * @desc Follow user
 * @access Private
 */
router.post('/:userId/follow', authenticateToken, userController.followUser);

/**
 * @route DELETE /api/v1/users/:userId/follow
 * @desc Unfollow user
 * @access Private
 */
router.delete('/:userId/follow', authenticateToken, userController.unfollowUser);

/**
 * @route GET /api/v1/users/:userId/following/check
 * @desc Check if following user
 * @access Private
 */
router.get('/:userId/following/check', authenticateToken, userController.isFollowing);

/**
 * @route GET /api/v1/users/:userId/stats
 * @desc Get user stats
 * @access Public
 */
router.get('/:userId/stats', userController.getUserStats);

/**
 * @route GET /api/v1/users/suggested
 * @desc Get suggested users
 * @access Private
 */
router.get('/suggested', authenticateToken, userController.getSuggestedUsers);

/**
 * @route DELETE /api/v1/users/account
 * @desc Delete user account
 * @access Private
 */
router.delete('/account', authenticateToken, userController.deleteAccount);

export default router;
