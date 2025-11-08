import axios, { AxiosInstance } from 'axios';

interface TMDbConfig {
  apiKey: string;
  baseUrl: string;
  imageBaseUrl: string;
}

interface TMDbMovie {
  id: number;
  imdb_id?: string;
  external_ids?: {
    imdb_id?: string;
  };
  alternative_titles?: {
    titles: Array<{
      iso_3166_1?: string;
      iso_639_1?: string;
      title: string;
      type?: string;
    }>;
  };
  title: string;
  original_title: string;
  overview: string;
  tagline?: string;
  poster_path?: string;
  backdrop_path?: string;
  release_date?: string;
  runtime?: number;
  genres?: Array<{ id: number; name: string }>;
  production_countries?: Array<{ iso_3166_1: string; name: string }>;
  spoken_languages?: Array<{ iso_639_1: string; name: string }>;
  adult: boolean;
  vote_average: number;
  vote_count: number;
  popularity: number;
  status: string;
  videos?: {
    results: Array<{
      key: string;
      site: string;
      type: string;
    }>;
  };
  credits?: {
    cast: Array<{
      id: number;
      name: string;
      character: string;
      order: number;
      profile_path?: string;
    }>;
    crew: Array<{
      id: number;
      name: string;
      job: string;
      department: string;
      profile_path?: string;
    }>;
  };
  images?: {
    backdrops: Array<{ file_path: string }>;
    posters: Array<{ file_path: string }>;
  };
}

interface TMDbTVShow {
  id: number;
  imdb_id?: string;
  external_ids?: {
    imdb_id?: string;
  };
  alternative_titles?: {
    results: Array<{
      iso_3166_1?: string;
      title: string;
      type?: string;
    }>;
  };
  name: string;
  original_name: string;
  overview: string;
  tagline?: string;
  poster_path?: string;
  backdrop_path?: string;
  first_air_date?: string;
  last_air_date?: string;
  number_of_seasons: number;
  number_of_episodes: number;
  episode_run_time?: number[];
  genres?: Array<{ id: number; name: string }>;
  origin_country?: string[];
  languages?: string[];
  adult: boolean;
  vote_average: number;
  vote_count: number;
  popularity: number;
  status: string;
  videos?: {
    results: Array<{
      key: string;
      site: string;
      type: string;
    }>;
  };
  credits?: {
    cast: Array<{
      id: number;
      name: string;
      character: string;
      order: number;
      profile_path?: string;
    }>;
    crew: Array<{
      id: number;
      name: string;
      job: string;
      department: string;
      profile_path?: string;
    }>;
  };
  images?: {
    backdrops: Array<{ file_path: string }>;
    posters: Array<{ file_path: string }>;
  };
  seasons?: Array<{
    season_number: number;
    episode_count: number;
    name: string;
    overview: string;
    poster_path?: string;
    air_date?: string;
  }>;
}

interface TMDbSeason {
  id: number;
  season_number: number;
  name: string;
  overview: string;
  air_date?: string;
  poster_path?: string;
  episodes: Array<{
    id: number;
    episode_number: number;
    season_number: number;
    name: string;
    overview: string;
    air_date?: string;
    still_path?: string;
    runtime?: number;
  }>;
}

export class TMDbService {
  private client: AxiosInstance;
  private config: TMDbConfig;

  constructor() {
    this.config = {
      apiKey: process.env['TMDB_API_KEY'] || '',
      baseUrl: process.env['TMDB_BASE_URL'] || 'https://api.themoviedb.org/3',
      imageBaseUrl: process.env['TMDB_IMAGE_BASE_URL'] || 'https://image.tmdb.org/t/p',
    };

    // Check if API key looks like a JWT (Bearer token) or simple API key
    const isBearer = this.config.apiKey.startsWith('eyJ');

    if (isBearer) {
      // Use Bearer authentication (v4 Read Access Token)
      this.client = axios.create({
        baseURL: this.config.baseUrl,
        headers: {
          'Authorization': `Bearer ${this.config.apiKey}`,
          'Content-Type': 'application/json',
        },
      });
    } else {
      // Use API key as query parameter (v3 API key)
      this.client = axios.create({
        baseURL: this.config.baseUrl,
        params: {
          api_key: this.config.apiKey,
        },
      });
    }
  }

  /**
   * Find movie or TV show by IMDb ID
   */
  async findByImdbId(imdbId: string): Promise<{ type: 'movie' | 'tv'; data: TMDbMovie | TMDbTVShow } | null> {
    try {
      const response = await this.client.get(`/find/${imdbId}`, {
        params: {
          external_source: 'imdb_id',
        },
      });

      if (response.data.movie_results && response.data.movie_results.length > 0) {
        const movieId = response.data.movie_results[0].id;
        const movieData = await this.getMovie(movieId);
        return { type: 'movie', data: movieData };
      }

      if (response.data.tv_results && response.data.tv_results.length > 0) {
        const tvId = response.data.tv_results[0].id;
        const tvData = await this.getTVShow(tvId);
        return { type: 'tv', data: tvData };
      }

      return null;
    } catch (error) {
      console.error('Error finding by IMDb ID:', error);
      throw error;
    }
  }

  /**
   * Get movie details
   */
  async getMovie(movieId: number): Promise<TMDbMovie> {
    try {
      const response = await this.client.get(`/movie/${movieId}`, {
        params: {
          append_to_response: 'credits,videos,images,external_ids,alternative_titles',
        },
      });

      return response.data;
    } catch (error) {
      console.error('Error getting movie:', error);
      throw error;
    }
  }

  /**
   * Get TV show details
   */
  async getTVShow(tvId: number): Promise<TMDbTVShow> {
    try {
      const response = await this.client.get(`/tv/${tvId}`, {
        params: {
          append_to_response: 'credits,videos,images,external_ids,alternative_titles',
        },
      });

      return response.data;
    } catch (error) {
      console.error('Error getting TV show:', error);
      throw error;
    }
  }

  /**
   * Get season details with episodes
   */
  async getSeason(tvId: number, seasonNumber: number): Promise<TMDbSeason> {
    try {
      const response = await this.client.get(`/tv/${tvId}/season/${seasonNumber}`);
      return response.data;
    } catch (error) {
      console.error('Error getting season:', error);
      throw error;
    }
  }

  /**
   * Search movies
   */
  async searchMovies(query: string, page: number = 1): Promise<{ results: TMDbMovie[]; total_pages: number }> {
    try {
      const response = await this.client.get('/search/movie', {
        params: {
          query,
          page,
        },
      });

      return {
        results: response.data.results,
        total_pages: response.data.total_pages,
      };
    } catch (error) {
      console.error('Error searching movies:', error);
      throw error;
    }
  }

  /**
   * Search TV shows
   */
  async searchTVShows(query: string, page: number = 1): Promise<{ results: TMDbTVShow[]; total_pages: number }> {
    try {
      const response = await this.client.get('/search/tv', {
        params: {
          query,
          page,
        },
      });

      return {
        results: response.data.results,
        total_pages: response.data.total_pages,
      };
    } catch (error) {
      console.error('Error searching TV shows:', error);
      throw error;
    }
  }

  /**
   * Get full image URL
   */
  getImageUrl(path: string | null | undefined, size: string = 'original'): string | null {
    if (!path) return null;
    return `${this.config.imageBaseUrl}/${size}${path}`;
  }

  /**
   * Get YouTube trailer URL
   */
  getTrailerUrl(videos?: { results: Array<{ key: string; site: string; type: string }> }): string | null {
    if (!videos || !videos.results) return null;

    const trailer = videos.results.find(
      (video) => video.site === 'YouTube' && (video.type === 'Trailer' || video.type === 'Teaser')
    );

    return trailer ? `https://www.youtube.com/watch?v=${trailer.key}` : null;
  }

  async findByTmdbId(
    tmdbId: string | number,
    preferredType?: 'movie' | 'tv'
  ): Promise<{ type: 'movie' | 'tv'; data: TMDbMovie | TMDbTVShow } | null> {
    const id = typeof tmdbId === 'string' ? parseInt(tmdbId, 10) : tmdbId;

    if (Number.isNaN(id)) {
      throw new Error('Invalid TMDb ID');
    }

    const attemptOrder: Array<'movie' | 'tv'> = preferredType
      ? preferredType === 'tv'
        ? ['tv', 'movie']
        : ['movie', 'tv']
      : ['movie', 'tv'];

    for (const type of attemptOrder) {
      try {
        if (type === 'movie') {
          const movieData = await this.getMovie(id);
          return { type: 'movie', data: movieData };
        } else {
          const tvData = await this.getTVShow(id);
          return { type: 'tv', data: tvData };
        }
      } catch (error: any) {
        const status = error?.response?.status;
        if (status && status !== 404) {
          throw error;
        }
        // If 404, continue to next attempt
      }
    }

    return null;
  }
}

export default new TMDbService();

