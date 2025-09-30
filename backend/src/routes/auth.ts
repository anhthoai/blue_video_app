import { Router } from 'express';
import { AuthController } from '../controllers/authController';
import { authenticateToken } from '../middleware/auth';
import { rateLimit } from '../middleware/auth';

const router = Router();
const authController = new AuthController();

// Rate limiting for auth endpoints
const authRateLimit = rateLimit(15 * 60 * 1000, 5); // 5 requests per 15 minutes

/**
 * @route POST /api/v1/auth/register
 * @desc Register a new user
 * @access Public
 */
router.post('/register', authRateLimit, authController.register);

/**
 * @route POST /api/v1/auth/login
 * @desc Login user
 * @access Public
 */
router.post('/login', authRateLimit, authController.login);

/**
 * @route POST /api/v1/auth/refresh
 * @desc Refresh access token
 * @access Public
 */
router.post('/refresh', authController.refreshToken);

/**
 * @route POST /api/v1/auth/logout
 * @desc Logout user
 * @access Public
 */
router.post('/logout', authController.logout);

/**
 * @route GET /api/v1/auth/profile
 * @desc Get current user profile
 * @access Private
 */
router.get('/profile', authenticateToken, authController.getProfile);

/**
 * @route PUT /api/v1/auth/change-password
 * @desc Change user password
 * @access Private
 */
router.put('/change-password', authenticateToken, authController.changePassword);

export default router;
