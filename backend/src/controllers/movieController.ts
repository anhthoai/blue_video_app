import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import tmdbService from '../services/tmdbService';
import ulozService from '../services/ulozService';

const prisma = new PrismaClient();

const regionDisplay = new Intl.DisplayNames(['en'], { type: 'region' });

async function generateUniqueSlug(title: string): Promise<string> {
  const baseSlug = generateSlug(title);
  let candidate = baseSlug;
  let counter = 1;

  while (true) {
    const existing = await prisma.movie.findUnique({ where: { slug: candidate } });
    if (!existing) {
      return candidate;
    }
    counter += 1;
    candidate = `${baseSlug}-${counter}`;
  }
}

function getCountryName(code?: string | null): string | null {
  if (!code) return null;
  try {
    return regionDisplay.of(code.toUpperCase()) || code.toUpperCase();
  } catch {
    return code.toUpperCase();
  }
}

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
    const {
      imdbId,
      imdbIds,
      tmdbId,
      tmdbIds,
      ids,
      identifiers,
      preferredType,
    } = req.body;
    const userId = (req as any).user?.id;

    const idsToImport: string[] = (
      identifiers ||
      ids ||
      imdbIds ||
      tmdbIds ||
      (imdbId ? [imdbId] : undefined) ||
      (tmdbId ? [tmdbId] : undefined)
    )
      ?.map((value: string | number) => value?.toString().trim())
      .filter((value: string | undefined) => !!value) as string[];

    if (!idsToImport || idsToImport.length === 0) {
      res.status(400).json({
        success: false,
        message: 'At least one IMDb or TMDb identifier is required',
      });
      return;
    }
    const results = [];

    for (const id of idsToImport) {
      try {
        const rawInput = `${id}`.trim();
        let identifier = rawInput;
        let tmdbTypeHint: 'movie' | 'tv' | undefined;

        const tmdbUrlMatch = identifier.match(/themoviedb\.org\/(movie|tv)\/(\d+)/i);
        const tmdbUrlType = tmdbUrlMatch?.[1];
        const tmdbUrlId = tmdbUrlMatch?.[2];
        if (tmdbUrlType && tmdbUrlId) {
          tmdbTypeHint = tmdbUrlType.toLowerCase() as 'movie' | 'tv';
          identifier = tmdbUrlId;
        }

        const tmdbPrefixMatch = identifier.match(/^(movie|tv)[/:](\d+)$/i);
        const tmdbPrefixType = tmdbPrefixMatch?.[1];
        const tmdbPrefixId = tmdbPrefixMatch?.[2];
        if (tmdbPrefixType && tmdbPrefixId) {
          tmdbTypeHint = tmdbPrefixType.toLowerCase() as 'movie' | 'tv';
          identifier = tmdbPrefixId;
        }

        if (!identifier) {
          continue;
        }

        const isImdb = /^tt\d+$/i.test(identifier);
        const isTmdb = /^\d+$/.test(identifier);

        if (!isImdb && !isTmdb) {
          results.push({
            identifier: rawInput,
            success: false,
            message: 'Identifier must be an IMDb (ttxxxxxx) or TMDb (numeric) ID',
          });
          continue;
        }

        if (tmdbTypeHint) {
          console.log(`🎬 Import request -> Identifier: ${identifier} (${tmdbTypeHint.toUpperCase()} ID)`);
        } else {
          console.log(`🎬 Import request -> Identifier: ${identifier} (${isImdb ? 'IMDb' : 'TMDb'})`);
        }

        const preferredKind = preferredType === 'TV_SERIES'
          ? 'tv'
          : preferredType === 'MOVIE'
              ? 'movie'
              : undefined;

        if (!tmdbTypeHint && isTmdb && preferredKind) {
          tmdbTypeHint = preferredKind as 'movie' | 'tv';
        }

        const tmdbData = isImdb
          ? await tmdbService.findByImdbId(identifier)
          : await tmdbService.findByTmdbId(identifier, tmdbTypeHint);

        if (!tmdbData) {
          console.warn(`⚠️ TMDb lookup failed for identifier ${identifier}`);
          results.push({
            identifier: rawInput,
            success: false,
            message: 'Title not found in TMDb',
          });
          continue;
        }

        const { type, data } = tmdbData;
        const isMovie = type === 'movie';
        const movieData = data as any;
        const tmdbIdValue = movieData.id?.toString();
        const imdbIdValue = (
          (isImdb ? identifier : null) ||
          movieData.imdb_id ||
          movieData.external_ids?.imdb_id ||
          null
        )?.toString() || null;

        let existing = null;

        if (imdbIdValue) {
          existing = await prisma.movie.findFirst({
            where: {
              imdbId: imdbIdValue,
            },
          });
        }

        if (!existing && tmdbIdValue) {
          existing = await prisma.movie.findFirst({
            where: {
              tmdbId: tmdbIdValue,
              contentType: isMovie ? 'MOVIE' : 'TV_SERIES',
            },
          });
        }

        if (existing) {
          console.warn(
            `⚠️ Duplicate detected for identifier ${rawInput} (contentType=${existing.contentType})`,
          );
          results.push({
            identifier: rawInput,
            success: false,
            message: 'Movie already exists',
            movieId: existing.id,
          });
          continue;
        }

        console.log(
          `✅ TMDb lookup success -> ${tmdbIdValue || 'unknown TMDb id'} (${movieData.title || movieData.name}) [${tmdbData.type.toUpperCase()}]`
        );

        // Prepare movie data
        const slug = generateSlug(movieData.title || movieData.name);
        const title = movieData.title || movieData.name;
        const resolvedCountries =
          (movieData.production_countries?.map((c: any) =>
            c?.name || getCountryName(c?.iso_3166_1)
          ) ?? [])
            .filter((value: string | null) => !!value)
            .map((value: string | null) => value as string);
        const originCountries = Array.isArray(movieData.origin_country)
          ? movieData.origin_country
              .map((code: string) => getCountryName(code))
              .filter((value: string | null) => !!value)
              .map((value: string | null) => value as string)
          : [];

        const alternativeTitles: Array<{ title: string; country?: string | null; language?: string | null; type?: string | null }> = [];
        const primaryTitle = title;
        const originalTitle = isMovie ? movieData.original_title : movieData.original_name;
        const originalLanguage = movieData.original_language || movieData.languages?.[0];
        const originalCountry = resolvedCountries[0] || originCountries[0] || null;

        const addAlternativeTitle = (
          altTitle?: string | null,
          country?: string | null,
          language?: string | null,
          type?: string | null
        ) => {
          if (!altTitle) return;
          if (altTitle.trim() === '') return;
          if (altTitle.trim() === primaryTitle?.trim()) return;

          const key = `${altTitle.trim().toLowerCase()}__${country ?? ''}__${language ?? ''}`;
          if (!alternativeTitles.some((item) => `${item.title.trim().toLowerCase()}__${item.country ?? ''}__${item.language ?? ''}` === key)) {
            alternativeTitles.push({
              title: altTitle.trim(),
              country: country ?? null,
              language: language ?? null,
              type: type ?? null,
            });
          }
        };

        addAlternativeTitle(originalTitle, originalCountry, originalLanguage, 'original');

        if (isMovie) {
          const altTitles = movieData.alternative_titles?.titles || [];
          altTitles.forEach((item: any) => {
            addAlternativeTitle(
              item?.title,
              item?.iso_3166_1 ? getCountryName(item.iso_3166_1) : null,
              item?.iso_639_1 || null,
              item?.type || null,
            );
          });
        } else {
          const altTitles = movieData.alternative_titles?.results || [];
          altTitles.forEach((item: any) => {
            addAlternativeTitle(
              item?.title,
              item?.iso_3166_1 ? getCountryName(item.iso_3166_1) : null,
              null,
              item?.type || null,
            );
          });
        }

        const movie = await prisma.movie.create({
          data: {
            imdbId: imdbIdValue,
            tmdbId: tmdbIdValue,
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
            countries: resolvedCountries.length > 0 ? resolvedCountries : originCountries,
            languages: movieData.spoken_languages?.map((l: any) => l.iso_639_1)
              || movieData.languages || [],
            isAdult: movieData.adult || false,
            alternativeTitles: alternativeTitles,
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
                id: a.id?.toString(),
                name: a.name,
                character: a.character,
                order: a.order,
                profileUrl: tmdbService.getImageUrl(a.profile_path, 'w185'),
              })) || [],
            voteAverage: movieData.vote_average,
            voteCount: movieData.vote_count,
            popularity: movieData.popularity,
            status: mapTMDbStatus(movieData.status),
            createdBy: userId,
          },
        });

        results.push({
          identifier: rawInput,
          imdbId: imdbIdValue,
          tmdbId: tmdbIdValue,
          type: tmdbData.type,
          success: true,
          message: 'Movie imported successfully',
          movieId: movie.id,
          movie,
        });

        console.log(`🎉 Created movie ${movie.title} (${movie.id})`);
      } catch (error: any) {
        console.error(`Error importing movie ${id}:`, error);
        results.push({
          identifier: `${id}`,
          success: false,
          message: error.message || 'Failed to import movie',
        });
      }
    }

    const successCount = results.filter(r => r.success).length;

    res.json({
      success: successCount > 0,
      message: `Imported ${successCount} of ${idsToImport.length} title(s)`,
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

export async function createMovieManual(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.id;
    const {
      contentType = 'MOVIE',
      title,
      alternativeTitles,
      imdbId,
      tmdbId,
      tvdbId,
      plot,
      releaseDate,
      runtime,
      genres,
      countries,
      languages,
      posterUrl,
      trailerUrl,
      sourceUrl,
      isAdult = false,
    } = req.body;

    if (!title || typeof title !== 'string' || title.trim() === '') {
      res.status(400).json({
        success: false,
        message: 'Title is required',
      });
      return;
    }

    if (imdbId) {
      const duplicateImdb = await prisma.movie.findFirst({
        where: { imdbId: imdbId as string },
      });

      if (duplicateImdb) {
        res.status(409).json({
          success: false,
          message: 'Movie with the same IMDb ID already exists',
          movieId: duplicateImdb.id,
        });
        return;
      }
    }

    if (tmdbId) {
      const duplicateTmdb = await prisma.movie.findFirst({
        where: {
          tmdbId: tmdbId as string,
          contentType: contentType === 'TV_SERIES' ? 'TV_SERIES' : 'MOVIE',
        },
      });

      if (duplicateTmdb) {
        console.warn(
          `⚠️ Manual create rejected: TMDb ${tmdbId as string} already exists for ${duplicateTmdb.contentType}`,
        );
        res.status(409).json({
          success: false,
          message: 'Movie with the same TMDb ID already exists',
          movieId: duplicateTmdb.id,
        });
        return;
      }
    }

    const slug = await generateUniqueSlug(title);

    const parsedAlternativeTitles = Array.isArray(alternativeTitles)
      ? alternativeTitles
          .filter((item: any) => item && item.title)
          .map((item: any) => ({
            title: item.title,
            country: item.country || null,
            language: item.language || null,
            type: item.type || null,
          }))
      : [];

    const movie = await prisma.movie.create({
      data: {
        title: title.trim(),
        slug,
        contentType: contentType === 'TV_SERIES' ? 'TV_SERIES' : 'MOVIE',
        overview: plot || null,
        alternativeTitles: parsedAlternativeTitles,
        imdbId: imdbId || null,
        tmdbId: tmdbId || null,
        tvdbId: tvdbId || null,
        releaseDate: releaseDate ? new Date(releaseDate) : null,
        runtime: runtime ? Number(runtime) : null,
        genres: Array.isArray(genres) ? genres : [],
        countries: Array.isArray(countries) ? countries : [],
        languages: Array.isArray(languages) ? languages : [],
        posterUrl: posterUrl || null,
        trailerUrl: trailerUrl || null,
        sourceUrl: sourceUrl || null,
        isAdult: Boolean(isAdult),
        status: 'RELEASED',
        createdBy: userId || null,
      },
    });

    res.status(201).json({
      success: true,
      message: 'Movie created successfully',
      data: movie,
    });
  } catch (error: any) {
    console.error('Error creating manual movie:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create movie manually',
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
    const { url, folderUrl, fileUrl, episodeNumber, seasonNumber = 1 } = req.body;

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
    let skippedCount = 0;

    // Support both 'url' and specific 'folderUrl'/'fileUrl'
    const targetUrl = url || folderUrl || fileUrl;

    if (!targetUrl) {
      res.status(400).json({
        success: false,
        message: 'url, folderUrl, or fileUrl is required',
      });
      return;
    }

    // Auto-detect if it's a folder or file
    console.log('🔍 Auto-detecting type for:', targetUrl);
    const detectedType = await ulozService.detectType(targetUrl);
    console.log('   ✅ Detected as:', detectedType.toUpperCase());

    if (detectedType === 'folder') {
      // Import entire folder as episodes
      try {
        console.log('📁 Importing folder as episodes...');
        const files = await ulozService.importFolderAsEpisodes(targetUrl);

        if (files.length === 0) {
          res.status(404).json({
            success: false,
            message: 'No video files found in folder',
          });
          return;
        }

        console.log(`   Found ${files.length} video files in folder`);

        for (let i = 0; i < files.length; i++) {
          const file = files[i];
          if (!file) continue; // Skip if file is undefined

          // Use suggested episode number or calculate from existing episodes
          const existingEpisodes = await prisma.movieEpisode.findMany({
            where: { movieId },
            orderBy: [{ seasonNumber: 'asc' }, { episodeNumber: 'asc' }],
          });

          const lastEpisode = existingEpisodes
            .filter(ep => ep.seasonNumber === Number(seasonNumber))
            .sort((a, b) => b.episodeNumber - a.episodeNumber)[0];

          // Check if episode already exists (by movieId + slug)
          const existingEpisode = await prisma.movieEpisode.findFirst({
            where: {
              movieId: movieId,
              slug: file.slug,
            },
            include: {
              subtitles: true,
            },
          });

          if (existingEpisode) {
            console.log(`   ⏭️  Episode already exists: ${file.name} (slug: ${file.slug})`);

            // Check if we need to add missing subtitles
            if (file.subtitles && file.subtitles.length > 0) {
              let addedSubtitles = 0;

              for (const sub of file.subtitles) {
                // Check if this subtitle already exists
                const hasSubtitle = existingEpisode.subtitles.some(
                  existing => existing.slug === sub.slug
                );

                if (!hasSubtitle) {
                  await prisma.subtitle.create({
                    data: {
                      episodeId: existingEpisode.id,
                      language: sub.language,
                      label: sub.label,
                      slug: sub.slug,
                      fileUrl: sub.url,
                      source: 'ULOZ',
                    },
                  });
                  addedSubtitles++;
                }
              }

              if (addedSubtitles > 0) {
                console.log(`      📝 Added ${addedSubtitles} new subtitle(s) to existing episode`);
              }
            }

            skippedCount++;
            continue;
          }

          const epNum = file.suggestedEpisodeNumber ||
            (lastEpisode ? lastEpisode.episodeNumber + 1 : i + 1);

          console.log(`   ✅ Creating episode ${epNum}: ${file.name}`);

          // Create the episode first
          const newEpisode = await prisma.movieEpisode.create({
            data: {
              movieId: movieId,
              episodeNumber: epNum,
              seasonNumber: Number(seasonNumber),
              title: file.name, // Keep full filename
              slug: file.slug,
              fileUrl: file.url,
              contentType: file.contentType,
              extension: file.extension,
              fileSize: BigInt(file.size),
              duration: file.duration || null,
              thumbnailUrl: file.thumbnail || null,
              videoPreviewUrl: file.videoPreview || null,
              folderSlug: file.folderSlug || null,
              source: 'ULOZ',
            },
          });

          // Add subtitles with duplicate checking
          if (file.subtitles && file.subtitles.length > 0) {
            let addedSubtitles = 0;
            let skippedSubtitles = 0;

            for (const sub of file.subtitles) {
              // Check if subtitle already exists for this episode (by episodeId + slug)
              const existingSubtitle = await prisma.subtitle.findFirst({
                where: {
                  episodeId: newEpisode.id,
                  slug: sub.slug,
                },
              });

              if (existingSubtitle) {
                skippedSubtitles++;
                continue;
              }

              // Create the subtitle
              await prisma.subtitle.create({
                data: {
                  episodeId: newEpisode.id,
                  language: sub.language,
                  label: sub.label,
                  slug: sub.slug,
                  fileUrl: sub.url,
                  source: 'ULOZ',
                },
              });

              addedSubtitles++;
            }

            if (addedSubtitles > 0) {
              console.log(`      📝 Added ${addedSubtitles} subtitle(s)`);
            }
            if (skippedSubtitles > 0) {
              console.log(`      ⏭️  Skipped ${skippedSubtitles} duplicate subtitle(s)`);
            }
          }

          episodes.push(newEpisode);
        }

        console.log(`✅ Successfully imported ${episodes.length} new episode(s) from folder`);
        if (skippedCount > 0) {
          console.log(`   ⏭️  Skipped ${skippedCount} duplicate(s)`);
        }
      } catch (error: any) {
        console.error('❌ Error importing folder:', error);
        res.status(500).json({
          success: false,
          message: 'Failed to import episodes',
          error: error.message,
        });
        return;
      }
    } else {
      // Import single file
      try {
        console.log('📄 Importing single file...');
        const fileInfo = await ulozService.getFileInfo(targetUrl);

        // Check if episode already exists (by movieId + slug)
        const existingEpisode = await prisma.movieEpisode.findFirst({
          where: {
            movieId: movieId,
            slug: fileInfo.slug,
          },
        });

        if (existingEpisode) {
          console.log(`   ⏭️  File already exists: ${fileInfo.name} (slug: ${fileInfo.slug})`);
          skippedCount++;
          // Don't add to episodes array, just skip
        } else {
          // Calculate episode number if not provided
          const existingEpisodes = await prisma.movieEpisode.findMany({
            where: { movieId },
            orderBy: [{ seasonNumber: 'asc' }, { episodeNumber: 'asc' }],
          });

          const lastEpisode = existingEpisodes
            .filter(ep => ep.seasonNumber === Number(seasonNumber))
            .sort((a, b) => b.episodeNumber - a.episodeNumber)[0];

          const epNum = episodeNumber
            ? Number(episodeNumber)
            : (lastEpisode ? lastEpisode.episodeNumber + 1 : 1);

          console.log(`   ✅ Creating episode ${epNum}: ${fileInfo.name}`);

          const newEpisode = await prisma.movieEpisode.create({
            data: {
              movieId: movieId,
              episodeNumber: epNum,
              seasonNumber: Number(seasonNumber),
              title: fileInfo.name, // Use full filename as title
              slug: fileInfo.slug,
              fileUrl: fileInfo.url || targetUrl,
              contentType: fileInfo.contentType,
              extension: fileInfo.extension,
              fileSize: BigInt(fileInfo.size),
              duration: fileInfo.duration || null,
              thumbnailUrl: fileInfo.thumbnail || null,
              videoPreviewUrl: fileInfo.videoPreview || null,
              folderSlug: fileInfo.folderSlug || null,
              source: 'ULOZ',
            },
          });

          episodes.push(newEpisode);
          console.log(`✅ Successfully imported episode: ${fileInfo.name}`);
        }
      } catch (error: any) {
        console.error('❌ Error importing file:', error);
        res.status(500).json({
          success: false,
          message: 'Failed to import episodes',
          error: error.message,
        });
        return;
      }
    }

    const message = skippedCount > 0
      ? `Imported ${episodes.length} new episode(s), skipped ${skippedCount} duplicate(s)`
      : `Imported ${episodes.length} episode(s)`;

    res.json({
      success: true,
      message,
      data: episodes.map(ep => ({
        ...ep,
        fileSize: ep.fileSize?.toString(),
      })),
      skipped: skippedCount,
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
      sourceUrl,
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

    // Search by sourceUrl (exact match)
    if (sourceUrl) {
      where.sourceUrl = sourceUrl as string;
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

export async function findMoviesByIdentifiers(req: Request, res: Response): Promise<void> {
  try {
    const { imdbId, tmdbId, tvdbId, contentType } = req.query;

    const filters: any[] = [];

    if (imdbId) {
      filters.push({ imdbId: imdbId as string });
    }

    if (tmdbId) {
      filters.push({
        tmdbId: tmdbId as string,
        ...(contentType ? { contentType: contentType as string } : {}),
      });
    }

    if (tvdbId) {
      filters.push({ tvdbId: tvdbId as string });
    }

    if (filters.length === 0) {
      res.status(400).json({
        success: false,
        message: 'Please provide at least one identifier (imdbId, tmdbId, tvdbId)',
      });
      return;
    }

    const movies = await prisma.movie.findMany({
      where: {
        OR: filters,
      },
      orderBy: {
        title: 'asc',
      },
    });

    res.json({
      success: true,
      data: movies,
    });
  } catch (error: any) {
    console.error('Error finding movies by identifiers:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to find movies by identifiers',
      error: error.message,
    });
  }
}

export async function searchTmdbTitles(req: Request, res: Response): Promise<void> {
  try {
    const { query, type = 'MOVIE', page = '1' } = req.query;

    if (!query || typeof query !== 'string' || !query.trim()) {
      res.status(400).json({
        success: false,
        message: 'Query parameter "query" is required',
      });
      return;
    }

    const trimmedQuery = query.trim();
    const pageNumber = Number(page) || 1;
    const normalizedType =
      typeof type === 'string' && type.toUpperCase() === 'TV_SERIES'
        ? 'TV_SERIES'
        : 'MOVIE';

    const tmdbResponse =
      normalizedType === 'TV_SERIES'
        ? await tmdbService.searchTVShows(trimmedQuery, pageNumber)
        : await tmdbService.searchMovies(trimmedQuery, pageNumber);

    const results = (tmdbResponse?.results || []).map((item: any) => ({
      tmdbId: item?.id ? item.id.toString() : null,
      title: item?.title || item?.name || '',
      originalTitle: item?.original_title || item?.original_name || null,
      overview: item?.overview || '',
      releaseDate: item?.release_date || item?.first_air_date || null,
      posterUrl: tmdbService.getImageUrl(item?.poster_path, 'w342'),
      backdropUrl: tmdbService.getImageUrl(item?.backdrop_path, 'w780'),
      voteAverage: item?.vote_average ?? null,
      popularity: item?.popularity ?? null,
      contentType: normalizedType,
      originCountry: item?.origin_country || [],
      originalLanguage: item?.original_language || null,
    }));

    res.json({
      success: true,
      data: results,
      totalPages: tmdbResponse?.total_pages ?? 1,
    });
  } catch (error: any) {
    console.error('Error searching TMDb titles:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to search TMDb titles',
      error: error?.message || 'Unknown error',
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
          include: {
            subtitles: true,
          },
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
 * Get subtitle stream URL
 * GET /api/v1/movies/:movieId/episodes/:episodeId/subtitles/:subtitleId/stream
 */
export async function getSubtitleStream(req: Request, res: Response): Promise<void> {
  try {
    const subtitleId = req.params['subtitleId'] as string;

    console.log(`📝 Getting subtitle stream for ID: ${subtitleId}`);

    const subtitle = await prisma.subtitle.findUnique({
      where: { id: subtitleId },
    });

    if (!subtitle) {
      res.status(404).json({
        success: false,
        message: 'Subtitle not found',
      });
      return;
    }

    console.log(`   Subtitle: ${subtitle.label} (${subtitle.language})`);
    console.log(`   Slug: ${subtitle.slug}`);

    if (subtitle.source === 'ULOZ' && subtitle.slug) {
      console.log('   Getting stream URL from uloz.to...');

      // Use slug to get stream URL
      const streamUrl = await ulozService.getStreamUrl(subtitle.slug);

      console.log(`   Stream URL: ${streamUrl || 'NULL'}`);

      if (!streamUrl) {
        res.status(404).json({
          success: false,
          message: 'Subtitle stream URL not available',
        });
        return;
      }

      res.json({
        success: true,
        data: {
          streamUrl,
          subtitle: {
            id: subtitle.id,
            language: subtitle.language,
            label: subtitle.label,
          },
        },
      });
    } else {
      // For non-ULOZ subtitles, use fileUrl directly
      res.json({
        success: true,
        data: {
          streamUrl: subtitle.fileUrl,
          subtitle: {
            id: subtitle.id,
            language: subtitle.language,
            label: subtitle.label,
          },
        },
      });
    }
  } catch (error: any) {
    console.error('Error getting subtitle stream:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get subtitle stream URL',
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

