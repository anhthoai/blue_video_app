import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import tmdbService from '../services/tmdbService';
import ulozService from '../services/ulozService';

const prisma = new PrismaClient();

/**
 * Generate slug from title
 */
function generateSlug(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/**
 * Map TMDb status to our status enum
 */
function mapTMDbStatus(status: string): 'RUMORED' | 'PLANNED' | 'IN_PRODUCTION' | 'POST_PRODUCTION' | 'RELEASED' | 'CANCELED' {
  const statusMap: { [key: string]: 'RUMORED' | 'PLANNED' | 'IN_PRODUCTION' | 'POST_PRODUCTION' | 'RELEASED' | 'CANCELED' } = {
    'Rumored': 'RUMORED',
    'Planned': 'PLANNED',
    'In Production': 'IN_PRODUCTION',
    'Post Production': 'POST_PRODUCTION',
    'Released': 'RELEASED',
    'Canceled': 'CANCELED',
  };
  return statusMap[status] || 'RELEASED';
}

/**
 * Import movie from IMDb/TMDb
 * POST /api/v1/movies/import/imdb
 */
export async function importFromImdb(req: Request, res: Response): Promise<void> {
  try {
    const { imdbId, imdbIds } = req.body;
    const userId = (req as any).user?.id;

    if (!imdbId && !imdbIds) {
      res.status(400).json({
        success: false,
        message: 'imdbId or imdbIds array is required',
      });
      return;
    }

    const idsToImport = imdbIds || [imdbId];
    const results = [];

    for (const id of idsToImport) {
      try {
        // Check if movie already exists
        const existing = await prisma.movie.findUnique({
          where: { imdbId: id },
        });

        if (existing) {
          results.push({
            imdbId: id,
            success: false,
            message: 'Movie already exists',
            movieId: existing.id,
          });
          continue;
        }

        // Fetch from TMDb
        const tmdbData = await tmdbService.findByImdbId(id);

        if (!tmdbData) {
          results.push({
            imdbId: id,
            success: false,
            message: 'Movie not found in TMDb',
          });
          continue;
        }

        const { type, data } = tmdbData;
        const isMovie = type === 'movie';
        const movieData = data as any;

        // Prepare movie data
        const slug = generateSlug(movieData.title || movieData.name);
        const title = movieData.title || movieData.name;

        const movie = await prisma.movie.create({
          data: {
            imdbId: id,
            tmdbId: movieData.id?.toString(),
            title,
            slug,
            overview: movieData.overview,
            tagline: movieData.tagline,
            posterUrl: tmdbService.getImageUrl(movieData.poster_path, 'w500'),
            backdropUrl: tmdbService.getImageUrl(movieData.backdrop_path, 'original'),
            trailerUrl: tmdbService.getTrailerUrl(movieData.videos),
            contentType: isMovie ? 'MOVIE' : (movieData.number_of_seasons ? 'TV_SERIES' : 'SHORT'),
            releaseDate: movieData.release_date || movieData.first_air_date 
              ? new Date(movieData.release_date || movieData.first_air_date)
              : null,
            endDate: movieData.last_air_date ? new Date(movieData.last_air_date) : null,
            runtime: isMovie 
              ? movieData.runtime 
              : (movieData.episode_run_time && movieData.episode_run_time[0]),
            genres: movieData.genres?.map((g: any) => g.name) || [],
            countries: movieData.production_countries?.map((c: any) => c.iso_3166_1) 
              || movieData.origin_country || [],
            languages: movieData.spoken_languages?.map((l: any) => l.iso_639_1)
              || movieData.languages || [],
            isAdult: movieData.adult || false,
            directors: movieData.credits?.crew
              ?.filter((c: any) => c.job === 'Director')
              .map((c: any) => ({ id: c.id.toString(), name: c.name })) || [],
            writers: movieData.credits?.crew
              ?.filter((c: any) => c.job === 'Writer' || c.job === 'Screenplay')
              .map((c: any) => ({ id: c.id.toString(), name: c.name })) || [],
            producers: movieData.credits?.crew
              ?.filter((c: any) => c.job === 'Producer')
              .map((c: any) => ({ id: c.id.toString(), name: c.name })) || [],
            actors: movieData.credits?.cast
              ?.slice(0, 20)
              .map((a: any) => ({
                id: a.id.toString(),
                name: a.name,
                character: a.character,
                order: a.order,
              })) || [],
            voteAverage: movieData.vote_average,
            voteCount: movieData.vote_count,
            popularity: movieData.popularity,
            status: mapTMDbStatus(movieData.status),
            createdBy: userId,
          },
        });

        results.push({
          imdbId: id,
          success: true,
          message: 'Movie imported successfully',
          movieId: movie.id,
          movie,
        });
      } catch (error: any) {
        console.error(`Error importing movie ${id}:`, error);
        results.push({
          imdbId: id,
          success: false,
          message: error.message || 'Failed to import movie',
        });
      }
    }

    const successCount = results.filter(r => r.success).length;

    res.json({
      success: successCount > 0,
      message: `Imported ${successCount} of ${idsToImport.length} movies`,
      results,
    });
  } catch (error: any) {
    console.error('Error in importFromImdb:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to import movies',
      error: error.message,
    });
  }
}

/**
 * Import episodes from uloz.to
 * POST /api/v1/movies/:movieId/episodes/import/uloz
 */
export async function importEpisodesFromUloz(req: Request, res: Response): Promise<void> {
  try {
    const movieId = req.params['movieId'] as string;
    const { folderUrl, fileUrl, episodeNumber, seasonNumber = 1 } = req.body;

    // Verify movie exists
    const movie = await prisma.movie.findUnique({
      where: { id: movieId },
    });

    if (!movie) {
      res.status(404).json({
        success: false,
        message: 'Movie not found',
      });
      return;
    }

    let episodes = [];

    if (folderUrl) {
      // Import entire folder as episodes
      const files = await ulozService.importFolderAsEpisodes(folderUrl);

      for (const file of files) {
        const episode = await prisma.movieEpisode.create({
          data: {
            movieId: movieId,
            episodeNumber: file.suggestedEpisodeNumber || 1,
            seasonNumber: Number(seasonNumber),
            title: file.name,
            slug: file.slug,
            fileUrl: file.url,
            contentType: file.contentType,
            extension: file.extension,
            fileSize: BigInt(file.size),
            duration: file.duration || null,
            thumbnailUrl: file.thumbnail || null,
            source: 'ULOZ',
          },
        });

        episodes.push(episode);
      }
    } else if (fileUrl) {
      // Import single file
      if (!episodeNumber) {
        res.status(400).json({
          success: false,
          message: 'episodeNumber is required when importing a single file',
        });
        return;
      }

      const fileInfo = await ulozService.getFileInfo(fileUrl);

      const episode = await prisma.movieEpisode.create({
        data: {
          movieId: movieId,
          episodeNumber: Number(episodeNumber),
          seasonNumber: Number(seasonNumber),
          title: fileInfo.name,
          slug: fileInfo.slug,
          fileUrl: fileInfo.url,
          contentType: fileInfo.contentType,
          extension: fileInfo.extension,
          fileSize: BigInt(fileInfo.size),
          duration: fileInfo.duration || null,
          thumbnailUrl: fileInfo.thumbnail || null,
          source: 'ULOZ',
        },
      });

      episodes.push(episode);
    } else {
      res.status(400).json({
        success: false,
        message: 'Either folderUrl or fileUrl is required',
      });
      return;
    }

    res.json({
      success: true,
      message: `Imported ${episodes.length} episode(s)`,
      data: episodes.map(ep => ({
        ...ep,
        fileSize: ep.fileSize?.toString(),
      })),
    });
  } catch (error: any) {
    console.error('Error importing episodes:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to import episodes',
      error: error.message,
    });
  }
}

/**
 * Get movie list with filters
 * GET /api/v1/movies
 */
export async function getMovies(req: Request, res: Response) {
  try {
    const {
      page = 1,
      limit = 20,
      contentType,
      genre,
      lgbtqType,
      search,
      status = 'RELEASED',
    } = req.query;

    const offset = (Number(page) - 1) * Number(limit);

    // Build where clause
    const where: any = {
      status: status as string,
    };

    if (contentType) {
      where.contentType = contentType as string;
    }

    // Note: For JSON array filtering, we'll filter in memory after query
    // since Prisma doesn't support case-insensitive JSON array contains

    if (search) {
      where.OR = [
        { title: { contains: search as string, mode: 'insensitive' } },
        { overview: { contains: search as string, mode: 'insensitive' } },
      ];
    }

    // Fetch all movies matching basic filters (without genre/lgbtq filtering)
    let movies = await prisma.movie.findMany({
      where,
      orderBy: {
        releaseDate: 'desc',
      },
    });

    // Apply genre filter (case-insensitive)
    if (genre) {
      const genreLower = (genre as string).toLowerCase();
      movies = movies.filter(movie => {
        const genres = movie.genres as any;
        if (!genres || !Array.isArray(genres)) return false;
        return genres.some((g: string) => g.toLowerCase() === genreLower);
      });
    }

    // Apply LGBTQ type filter (case-insensitive)
    if (lgbtqType) {
      const typeLower = (lgbtqType as string).toLowerCase();
      movies = movies.filter(movie => {
        const types = movie.lgbtqTypes as any;
        if (!types || !Array.isArray(types)) return false;
        return types.some((t: string) => t.toLowerCase() === typeLower);
      });
    }

    // Apply pagination after filtering
    const total = movies.length;
    const paginatedMovies = movies.slice(offset, offset + Number(limit));

    res.json({
      success: true,
      data: paginatedMovies.map(movie => ({
        ...movie,
        voteAverage: movie.voteAverage ? parseFloat(movie.voteAverage.toString()) : null,
        popularity: movie.popularity ? parseFloat(movie.popularity.toString()) : null,
      })),
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total,
        totalPages: Math.ceil(total / Number(limit)),
      },
    });
  } catch (error: any) {
    console.error('Error getting movies:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch movies',
      error: error.message,
    });
  }
}

/**
 * Get movie by ID
 * GET /api/v1/movies/:id
 */
export async function getMovieById(req: Request, res: Response): Promise<void> {
  try {
    const id = req.params['id'] as string;

    const movie = await prisma.movie.findUnique({
      where: { id },
      include: {
        episodes: {
          orderBy: [
            { seasonNumber: 'asc' },
            { episodeNumber: 'asc' },
          ],
        },
      },
    });

    if (!movie) {
      res.status(404).json({
        success: false,
        message: 'Movie not found',
      });
      return;
    }

    res.json({
      success: true,
      data: {
        ...movie,
        voteAverage: movie.voteAverage ? parseFloat(movie.voteAverage.toString()) : null,
        popularity: movie.popularity ? parseFloat(movie.popularity.toString()) : null,
        episodes: movie.episodes.map((ep: any) => ({
          ...ep,
          fileSize: ep.fileSize?.toString(),
        })),
      },
    });
  } catch (error: any) {
    console.error('Error getting movie:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch movie',
      error: error.message,
    });
  }
}

/**
 * Get stream URL for episode
 * GET /api/v1/movies/:movieId/episodes/:episodeId/stream
 */
export async function getEpisodeStream(req: Request, res: Response): Promise<void> {
  try {
    const movieId = req.params['movieId'] as string;
    const episodeId = req.params['episodeId'] as string;

    const episode = await prisma.movieEpisode.findFirst({
      where: {
        id: episodeId,
        movieId: movieId,
      },
    });

    if (!episode) {
      res.status(404).json({
        success: false,
        message: 'Episode not found',
      });
      return;
    }

    if (episode.source === 'ULOZ' && episode.fileUrl) {
      const streamUrl = await ulozService.getStreamUrl(episode.fileUrl);

      if (!streamUrl) {
        res.status(404).json({
          success: false,
          message: 'Stream URL not available',
        });
        return;
      }

      // Update stream URL in database for caching
      await prisma.movieEpisode.update({
        where: { id: episodeId },
        data: { streamUrl },
      });

      res.json({
        success: true,
        data: {
          streamUrl,
          episode: {
            ...episode,
            fileSize: episode.fileSize?.toString(),
          },
        },
      });
    } else {
      res.json({
        success: true,
        data: {
          streamUrl: episode.streamUrl || episode.fileUrl,
          episode: {
            ...episode,
            fileSize: episode.fileSize?.toString(),
          },
        },
      });
    }
  } catch (error: any) {
    console.error('Error getting episode stream:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get stream URL',
      error: error.message,
    });
  }
}

/**
 * Get available filter options
 * GET /api/v1/movies/filters/options
 */
export async function getFilterOptions(_req: Request, res: Response): Promise<void> {
  try {
    const movies = await prisma.movie.findMany({
      select: {
        genres: true,
        lgbtqTypes: true,
        contentType: true,
      },
    });

    // Extract unique genres
    const genresSet = new Set<string>();
    const lgbtqTypesSet = new Set<string>();
    const contentTypesSet = new Set<string>();

    movies.forEach(movie => {
      // Add genres
      if (movie.genres && Array.isArray(movie.genres)) {
        (movie.genres as string[]).forEach(genre => genresSet.add(genre));
      }

      // Add LGBTQ types
      if (movie.lgbtqTypes && Array.isArray(movie.lgbtqTypes)) {
        (movie.lgbtqTypes as string[]).forEach(type => lgbtqTypesSet.add(type));
      }

      // Add content type
      contentTypesSet.add(movie.contentType);
    });

    res.json({
      success: true,
      data: {
        genres: Array.from(genresSet).sort(),
        lgbtqTypes: Array.from(lgbtqTypesSet).sort(),
        contentTypes: Array.from(contentTypesSet).sort(),
      },
    });
  } catch (error: any) {
    console.error('Error getting filter options:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch filter options',
      error: error.message,
    });
  }
}

/**
 * Update movie metadata (including LGBTQ+ tags)
 * PATCH /api/v1/movies/:id
 */
export async function updateMovie(req: Request, res: Response): Promise<void> {
  try {
    const id = req.params['id'] as string;
    const { lgbtqTypes, genres } = req.body;

    const updateData: any = {};

    if (lgbtqTypes !== undefined) {
      updateData.lgbtqTypes = lgbtqTypes;
    }

    if (genres !== undefined) {
      updateData.genres = genres;
    }

    const movie = await prisma.movie.update({
      where: { id },
      data: updateData,
    });

    res.json({
      success: true,
      message: 'Movie updated successfully',
      data: {
        ...movie,
        voteAverage: movie.voteAverage ? parseFloat(movie.voteAverage.toString()) : null,
        popularity: movie.popularity ? parseFloat(movie.popularity.toString()) : null,
      },
    });
  } catch (error: any) {
    console.error('Error updating movie:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update movie',
      error: error.message,
    });
  }
}

/**
 * Delete movie
 * DELETE /api/v1/movies/:id
 */
export async function deleteMovie(req: Request, res: Response): Promise<void> {
  try {
    const id = req.params['id'] as string;

    await prisma.movie.delete({
      where: { id },
    });

    res.json({
      success: true,
      message: 'Movie deleted successfully',
    });
  } catch (error: any) {
    console.error('Error deleting movie:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete movie',
      error: error.message,
    });
  }
}

