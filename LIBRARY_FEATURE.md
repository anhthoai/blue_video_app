# Library Feature - Movies, Ebooks, Magazines, Comics

## Overview
A comprehensive library system for movies (focusing on BoyLove/LGBTQ+ content), ebooks, magazines, and comics with external data fetching from IMDb and file hosting via uloz.to.

## Feature Scope

### Phase 1: Movies Library (Current Focus)
- **Primary Focus**: BoyLove/Gay content
- **Data Sources**: IMDb
- **Video Hosting**: uloz.to integration
- **Content Types**: Movies, TV Series, Shorts

### Phase 2: Digital Content (Future)
- Ebooks (epub, mobi, fb2, azw3, txt, pdf)
- Audio books
- Magazines (image galleries)
- Comics (image galleries)

---

## 1. Database Schema

### 1.1 Movies Table
```sql
CREATE TABLE movies (
  id VARCHAR(36) PRIMARY KEY,
  imdb_id VARCHAR(20) UNIQUE,
  tmdb_id VARCHAR(20),
  tvdb_id VARCHAR(20),
  
  -- Basic Info
  title VARCHAR(500) NOT NULL,
  alternate_titles JSON, -- Array of {title, country, language}
  slug VARCHAR(500) UNIQUE,
  overview TEXT,
  tagline TEXT,
  
  -- Media
  poster_url TEXT,
  backdrop_url TEXT,
  photos JSON, -- Array of image URLs
  trailer_url TEXT,
  
  -- Classification
  content_type ENUM('movie', 'tv_series', 'short') DEFAULT 'movie',
  release_date DATE,
  end_date DATE, -- For TV series
  runtime INT, -- In minutes
  
  -- Categories
  genres JSON, -- Array of genre strings
  countries JSON, -- Array of country codes
  languages JSON, -- Array of language codes
  is_adult BOOLEAN DEFAULT false,
  
  -- LGBTQ+ Classification
  lgbtq_type JSON, -- Array: ['gay', 'lesbian', 'bisexual', 'transgender', 'queer']
  
  -- Credits
  directors JSON, -- Array of {id, name}
  writers JSON, -- Array of {id, name}
  producers JSON, -- Array of {id, name}
  actors JSON, -- Array of {id, name, character, order}
  
  -- Statistics
  vote_average DECIMAL(3,1),
  vote_count INT,
  popularity DECIMAL(8,3),
  views INT DEFAULT 0,
  
  -- Status
  status ENUM('rumored', 'planned', 'in_production', 'post_production', 'released', 'canceled') DEFAULT 'released',
  
  -- Metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_by VARCHAR(36),
  
  INDEX idx_imdb_id (imdb_id),
  INDEX idx_tmdb_id (tmdb_id),
  INDEX idx_content_type (content_type),
  INDEX idx_release_date (release_date),
  INDEX idx_status (status),
  FULLTEXT INDEX idx_title (title)
);
```

### 1.2 Movie Episodes Table
```sql
CREATE TABLE movie_episodes (
  id VARCHAR(36) PRIMARY KEY,
  movie_id VARCHAR(36) NOT NULL,
  
  -- Episode Info
  episode_number INT NOT NULL,
  season_number INT DEFAULT 1,
  title VARCHAR(500),
  overview TEXT,
  
  -- Media
  thumbnail_url TEXT,
  duration INT, -- In seconds
  
  -- File Source (uloz.to)
  source ENUM('upload', 'uloz', 'external') DEFAULT 'uloz',
  slug VARCHAR(500), -- uloz.to file slug
  parent_folder_slug VARCHAR(500), -- uloz.to folder slug
  file_url TEXT, -- Direct file URL
  stream_url TEXT, -- Direct stream URL from uloz.to
  content_type VARCHAR(50) DEFAULT 'video',
  extension VARCHAR(10),
  file_size BIGINT,
  
  -- Dates
  air_date DATE,
  
  -- Statistics
  views INT DEFAULT 0,
  
  -- Status
  is_available BOOLEAN DEFAULT true,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (movie_id) REFERENCES movies(id) ON DELETE CASCADE,
  INDEX idx_movie_id (movie_id),
  INDEX idx_season_episode (season_number, episode_number),
  INDEX idx_slug (slug)
);
```

### 1.3 Library Content Table (For Ebooks, Magazines, Comics)
```sql
CREATE TABLE library_content (
  id VARCHAR(36) PRIMARY KEY,
  
  -- Basic Info
  title VARCHAR(500) NOT NULL,
  slug VARCHAR(500) UNIQUE,
  description TEXT,
  
  -- Media
  cover_url TEXT,
  thumbnail_url TEXT,
  
  -- Classification
  content_type ENUM('ebook', 'audiobook', 'magazine', 'comic') NOT NULL,
  extension VARCHAR(10), -- epub, pdf, mp3, jpg, etc.
  file_size BIGINT,
  
  -- Categories
  genres JSON,
  languages JSON,
  is_adult BOOLEAN DEFAULT false,
  
  -- File Source
  source ENUM('upload', 'uloz', 'external') DEFAULT 'upload',
  slug_path VARCHAR(500),
  file_url TEXT,
  parent_folder_slug VARCHAR(500),
  
  -- For Gallery Content (magazines, comics)
  pages_count INT,
  pages_urls JSON, -- Array of image URLs
  
  -- Metadata
  author VARCHAR(500),
  publisher VARCHAR(500),
  published_date DATE,
  isbn VARCHAR(20),
  
  -- Statistics
  views INT DEFAULT 0,
  downloads INT DEFAULT 0,
  
  -- Status
  is_available BOOLEAN DEFAULT true,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_by VARCHAR(36),
  
  INDEX idx_content_type (content_type),
  INDEX idx_slug_path (slug_path),
  FULLTEXT INDEX idx_title (title)
);
```

---

## 2. Backend API Endpoints

### 2.1 Movies Management

#### Import from IMDb
- `POST /api/v1/movies/import/imdb`
  - Body: `{ imdbId: string }` or `{ imdbIds: string[] }`
  - Fetches movie data from IMDb/TMDb API
  - Creates movie record in database

#### Import Episodes from uloz.to
- `POST /api/v1/movies/:movieId/episodes/import/uloz`
  - Body: `{ folderUrl: string }` or `{ fileUrl: string, episodeNumber: int, seasonNumber: int }`
  - Fetches file/folder data from uloz.to API
  - Creates episode records

#### CRUD Operations
- `GET /api/v1/movies` - List movies with filters
- `GET /api/v1/movies/:id` - Get movie details with episodes
- `POST /api/v1/movies` - Create movie manually
- `PUT /api/v1/movies/:id` - Update movie
- `DELETE /api/v1/movies/:id` - Delete movie
- `GET /api/v1/movies/:id/episodes` - Get all episodes
- `GET /api/v1/movies/:id/episodes/:episodeId` - Get episode details
- `POST /api/v1/movies/:id/episodes` - Create episode manually
- `PUT /api/v1/movies/:id/episodes/:episodeId` - Update episode
- `DELETE /api/v1/movies/:id/episodes/:episodeId` - Delete episode

#### Streaming
- `GET /api/v1/movies/:id/episodes/:episodeId/stream` - Get stream URL from uloz.to

### 2.2 Library Content Management

#### CRUD Operations
- `GET /api/v1/library` - List library content with filters
- `GET /api/v1/library/:id` - Get content details
- `POST /api/v1/library` - Create content
- `PUT /api/v1/library/:id` - Update content
- `DELETE /api/v1/library/:id` - Delete content

#### Import from uloz.to
- `POST /api/v1/library/import/uloz`
  - Body: `{ url: string, contentType: string }`

---

## 3. External API Integration

### 3.1 IMDb/TMDb API
- **Base URL**: `https://api.themoviedb.org/3`
- **Required**: TMDb API Key
- **Endpoints Used**:
  - `/movie/{imdb_id}` - Get movie details
  - `/tv/{imdb_id}` - Get TV series details
  - `/tv/{id}/season/{season_number}` - Get season details
  - `/search/movie` - Search movies
  - `/search/tv` - Search TV shows

### 3.2 uloz.to API
- **Base URL**: `https://api.uloz.to`
- **Authentication**: Basic Auth (username + password) + API Key
- **Required ENV Variables**:
  ```env
  ULOZ_USERNAME=your_username
  ULOZ_PASSWORD=your_password
  ULOZ_API_KEY=your_api_key
  ```
- **Endpoints Used**:
  - `/v8/user/{userLogin}/folder/{folderSlug}/file-list` - Get folder contents
  - `/v7/file/{fileSlug}/private` - Get file information
  - `/v5/file/download-link/vipdata` - Get download/stream links

---

## 4. Mobile App UI/UX

### 4.1 Library Screen Navigation
```
Bottom Navigation:
├── Home
├── Library (NEW)
│   ├── Movies
│   ├── Ebooks
│   ├── Magazines
│   └── Comics
├── Discover
├── Community
└── Profile
```

### 4.2 Movies Library Screen

#### Filter Tabs (Horizontal Scroll)
1. **Content Type**: Movie | TV Series | Short
2. **Genre**: Drama | Comedy | Romance | Action | Thriller | Horror
3. **LGBTQ+ Type**: Lesbian | Gay | Bisexual | Transgender | Queer

#### Layout
- Grid view (2 columns on mobile, 3+ on tablet)
- Movie poster as thumbnail
- Title, year, rating overlay
- Play button overlay on hover/tap

### 4.3 Movie Detail Screen

#### For Movies/Shorts
- Movie poster & backdrop
- Title, tagline, overview
- Metadata: Year, runtime, genres, countries
- Cast & crew
- Play button → Opens video player

#### For TV Series
- Series poster & backdrop
- Title, tagline, overview
- Metadata: Years, genres, countries
- Season selector (tabs or dropdown)
- Episode list (scrollable)
  - Episode thumbnail, number, title, duration
  - Tap episode → Opens video player

### 4.4 Enhanced Video Player

#### Current Features
- Play/pause, seek, volume
- Quality selection
- Fullscreen

#### New Features for TV Series
- **Episode Selector**:
  - Bottom sheet with episode list
  - Current episode highlighted
  - Tap to switch episode (continues playback)
- **Auto-play Next Episode**:
  - Countdown timer (10s) at end
  - Skip intro/outro buttons (future)
- **Episode Navigation**:
  - Previous/Next episode buttons
  - Episode number display

### 4.5 Digital Content Viewers (Future)

#### Audiobook Player
- Use existing video player in audio mode
- Show book cover instead of video
- Playback controls, chapters, bookmarks

#### Gallery Viewer (Magazines/Comics)
- Vertical scroll, one image per line
- Tap image → Fullscreen viewer
- Swipe left/right for prev/next page
- Zoom in/out gesture support

#### Ebook Viewer
- Integration: foliate-js library
- Features:
  - Text rendering, pagination
  - Font size, theme controls
  - Bookmarks, highlights
  - Table of contents navigation

#### File Viewer
- Show file icon with metadata
- Download button
- External app open option

---

## 5. Implementation Phases

### Phase 1: Backend Setup ✅ (To Do)
- [ ] Create database migrations for movies tables
- [ ] Set up uloz.to API client
- [ ] Set up TMDb API client
- [ ] Create movie CRUD endpoints
- [ ] Create episode CRUD endpoints
- [ ] Implement IMDb import endpoint
- [ ] Implement uloz.to import endpoints
- [ ] Add streaming endpoint with uloz.to integration

### Phase 2: Mobile App - Movies Library ✅ (To Do)
- [ ] Create Library screen navigation
- [ ] Create Movies library screen with filters
- [ ] Create Movie detail screen
- [ ] Enhance video player with episode support
- [ ] Create episode selector UI
- [ ] Implement auto-play next episode
- [ ] Add loading states and error handling

### Phase 3: Admin Panel (To Do)
- [ ] Create movie management UI
- [ ] IMDb import interface (single/batch)
- [ ] uloz.to import interface
- [ ] Episode management UI
- [ ] Metadata editor

### Phase 4: Digital Content (Future)
- [ ] Database schema for ebooks/magazines/comics
- [ ] Backend endpoints for library content
- [ ] Mobile app library content screens
- [ ] Audiobook player
- [ ] Gallery viewer
- [ ] Ebook viewer (foliate-js)
- [ ] File viewer

---

## 6. Environment Variables

### Add to `.env` files:

```env
# TMDb API (for IMDb data)
TMDB_API_KEY=your_tmdb_api_key
TMDB_BASE_URL=https://api.themoviedb.org/3

# uloz.to API
ULOZ_USERNAME=your_username
ULOZ_PASSWORD=your_password
ULOZ_API_KEY=your_api_key
ULOZ_BASE_URL=https://api.uloz.to
```

---

## 7. Technical Considerations

### 7.1 Performance
- Implement pagination for movie/episode lists
- Cache IMDb/TMDb responses
- Lazy load images
- Prefetch next episode for seamless playback

### 7.2 Security
- Secure uloz.to credentials
- Rate limiting on import endpoints
- Validate IMDb IDs before import
- Access control for adult content

### 7.3 Error Handling
- Handle API failures gracefully
- Retry logic for external APIs
- User-friendly error messages
- Logging for debugging

### 7.4 Future Enhancements
- Watchlist/favorites
- Continue watching feature
- Download for offline viewing
- Subtitle support
- Multiple audio tracks
- Chromecast support
- Smart TV apps

---

## 8. Testing Checklist

### Backend
- [ ] Movie CRUD operations
- [ ] Episode CRUD operations
- [ ] IMDb import (single/batch)
- [ ] uloz.to folder import
- [ ] uloz.to file import
- [ ] Stream URL generation
- [ ] Filtering and search
- [ ] Pagination

### Mobile App
- [ ] Library screen navigation
- [ ] Movie browsing with filters
- [ ] Movie detail display
- [ ] Video playback (movies)
- [ ] Episode selection (TV series)
- [ ] Episode playback (TV series)
- [ ] Auto-play next episode
- [ ] Loading states
- [ ] Error handling
- [ ] Network failure recovery

---

## 9. Success Metrics

### User Engagement
- Number of movies watched
- Average watch time
- Episode completion rate
- Returning user rate

### Content Library
- Number of movies imported
- Content type distribution
- LGBTQ+ content coverage
- Update frequency

### Technical
- API response times
- Streaming quality
- App crash rate
- User retention

---

## Status: Phase 1 - In Progress

**Last Updated**: 2025-11-04
**Current Phase**: Backend Setup
**Next Milestone**: Database migrations and API setup

