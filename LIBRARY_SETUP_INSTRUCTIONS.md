# Library Feature Setup Instructions

## Quick Start Guide

### 1. Environment Configuration

Update your `backend/.env` file with the required API keys:

```env
# TMDb API (Get your API key from https://www.themoviedb.org/settings/api)
TMDB_API_KEY=your_tmdb_api_key_here
TMDB_BASE_URL=https://api.themoviedb.org/3
TMDB_IMAGE_BASE_URL=https://image.tmdb.org/t/p

# uloz.to API (Get credentials from https://uloz.to/settings)
ULOZ_USERNAME=your_uloz_username
ULOZ_PASSWORD=your_uloz_password
ULOZ_API_KEY=your_uloz_api_key
ULOZ_BASE_URL=https://api.uloz.to
```

### 2. Database Migration

```bash
cd blue_video_app/backend

# Generate Prisma client
npx prisma generate

# Create and apply migration
npx prisma migrate dev --name add_library_feature

# Or if in production
npx prisma migrate deploy
```

### 3. Install Dependencies (if needed)

```bash
# Backend
cd backend
npm install axios # For API calls to TMDb and uloz.to

# Mobile App
cd mobile-app
flutter pub add http # Already installed
```

### 4. Verify Database Tables

After migration, verify these tables exist:
- `movies`
- `movie_episodes`
- `library_content`

```bash
# Check tables in PostgreSQL
psql -U blue_video_user -d blue_video_db -c "\dt"
```

### 5. Test API Access

Test TMDb API:
```bash
curl "https://api.themoviedb.org/3/search/movie?api_key=YOUR_API_KEY&query=Heartstopper"
```

Test uloz.to API:
```bash
curl -u "username:password" \
  -H "X-Auth-Token: YOUR_API_KEY" \
  "https://api.uloz.to/v6/file/info?url=https://uloz.to/file/xxx"
```

### 6. Start Development

```bash
# Backend
cd backend
npm run dev

# Mobile App
cd mobile-app
flutter run
```

---

## Feature Implementation Status

### ✅ Phase 1: Database Setup (Completed)
- [x] Database schema created
- [x] Enums defined (MovieContentType, MovieStatus, ContentSource, LibraryContentType)
- [x] Movies table
- [x] MovieEpisodes table
- [x] LibraryContent table
- [x] Environment variables configured

### 🚧 Phase 2: Mobile App UI (In Progress)
- [ ] Library screen navigation
- [ ] Movies list screen
- [ ] Movie filters (Type, Genre, LGBTQ+)
- [ ] Movie detail screen
- [ ] Enhanced video player with episodes

### ⏳ Phase 3: Backend API (Pending)
- [ ] TMDb API integration service
- [ ] uloz.to API integration service
- [ ] Movies CRUD endpoints
- [ ] Episodes CRUD endpoints
- [ ] Import endpoints (IMDb, uloz.to)
- [ ] Stream URL generation

### ⏳ Phase 4: Admin Panel (Future)
- [ ] Movie management interface
- [ ] Batch import UI
- [ ] Episode manager
- [ ] Metadata editor

---

## API Integration Details

### TMDb API Usage

```javascript
// Example: Fetch movie by IMDb ID
const tmdbApiKey = process.env.TMDB_API_KEY;
const imdbId = 'tt14452776'; // Heartstopper

const response = await axios.get(
  `https://api.themoviedb.org/3/find/${imdbId}`,
  {
    params: {
      api_key: tmdbApiKey,
      external_source: 'imdb_id'
    }
  }
);

// Fetch movie details
const movieId = response.data.movie_results[0].id;
const movieDetails = await axios.get(
  `https://api.themoviedb.org/3/movie/${movieId}`,
  {
    params: {
      api_key: tmdbApiKey,
      append_to_response: 'credits,videos,images'
    }
  }
);
```

### uloz.to API Usage

```javascript
// Example: Get folder contents
const auth = Buffer.from(`${ULOZ_USERNAME}:${ULOZ_PASSWORD}`).toString('base64');

const response = await axios.get(
  'https://api.uloz.to/v6/folder/content',
  {
    params: {
      url: 'https://uloz.to/folder/xxx'
    },
    headers: {
      'Authorization': `Basic ${auth}`,
      'X-Auth-Token': process.env.ULOZ_API_KEY
    }
  }
);

// Get stream URL
const streamResponse = await axios.get(
  'https://api.uloz.to/v6/file/download-links',
  {
    params: {
      slug: 'file-slug'
    },
    headers: {
      'Authorization': `Basic ${auth}`,
      'X-Auth-Token': process.env.ULOZ_API_KEY
    }
  }
);
```

---

## Database Schema Overview

### Movies Table
Stores movie/TV series metadata from IMDb/TMDb.

### MovieEpisodes Table
Stores episode files with uloz.to links for streaming.

### LibraryContent Table
Stores ebooks, audiobooks, magazines, and comics (future phase).

---

## Troubleshooting

### Migration Fails
```bash
# Reset database (CAUTION: Deletes all data)
npx prisma migrate reset

# Or manually fix
npx prisma db push --force-reset
```

### API Connection Issues
- Check API keys are correct
- Verify network connectivity
- Check rate limits
- Review API documentation

### Mobile App Not Connecting
- Ensure backend is running
- Check API_URL in mobile app config
- Verify CORS settings
- Check network permissions

---

## Next Steps

1. **Implement Backend APIs**: Create service files for TMDb and uloz.to
2. **Build Mobile UI**: Complete Library screen with movie browsing
3. **Test Integration**: Import sample movies and test playback
4. **Add Admin Tools**: Build management interface
5. **Expand to Digital Content**: Add ebooks, magazines, comics support

---

## Support & Resources

- **TMDb API Docs**: https://developers.themoviedb.org/3
- **uloz.to API Docs**: https://uloz.to/apidoc/public
- **Prisma Docs**: https://www.prisma.io/docs
- **Flutter Video Player**: https://pub.dev/packages/video_player

---

**Last Updated**: 2025-11-04
**Status**: Phase 1 Complete, Phase 2 In Progress

