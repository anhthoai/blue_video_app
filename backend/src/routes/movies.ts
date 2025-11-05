import { Router } from 'express';
import * as movieController from '../controllers/movieController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Public routes
router.get('/', movieController.getMovies);
router.get('/filters/options', movieController.getFilterOptions);
router.get('/:id', movieController.getMovieById);
router.get('/:movieId/episodes/:episodeId/stream', movieController.getEpisodeStream);

// Protected routes (require authentication)
router.post('/import/imdb', authenticateToken, movieController.importFromImdb);
router.post('/:movieId/episodes/import/uloz', authenticateToken, movieController.importEpisodesFromUloz);
router.patch('/:id', authenticateToken, movieController.updateMovie);
router.delete('/:id', authenticateToken, movieController.deleteMovie);

export default router;

