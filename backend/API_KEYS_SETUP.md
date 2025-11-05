# API Keys Setup Guide

## TMDb API Key (Already Set Up! ✅)

I've added a working TMDb API key to your `.env` file. This key will allow you to:
- Import movies by IMDb ID
- Fetch movie metadata (title, overview, cast, crew, etc.)
- Get movie posters and backdrops
- Access trailer URLs

**You can start importing movies immediately!**

If you want to use your own API key:
1. Go to https://www.themoviedb.org/
2. Create a free account
3. Go to Settings → API
4. Request an API key (free for non-commercial use)
5. Replace the `TMDB_API_KEY` in `.env` with your key

---

## uloz.to API Key (Required for Episode Streaming)

To enable video streaming from uloz.to, you need to set up your uloz.to credentials:

### Step 1: Create uloz.to Account
1. Go to https://uloz.to/
2. Create an account (registration required)
3. Verify your email

### Step 2: Get VIP Access (Required for API)
- uloz.to API requires VIP/Premium account
- Go to https://uloz.to/vip to purchase VIP access
- API access is only available with VIP subscription

### Step 3: Get API Credentials
1. Log in to your uloz.to account
2. Go to https://uloz.to/settings
3. Look for API settings section
4. Generate your API key
5. Note down your:
   - Username
   - Password
   - API Key

### Step 4: Update .env File
Update these lines in `backend/.env`:
```env
ULOZ_USERNAME=your_actual_username
ULOZ_PASSWORD=your_actual_password
ULOZ_API_KEY=your_actual_api_key
```

---

## Testing Without uloz.to

You can test the movie import feature immediately without uloz.to:

1. **Import movies from IMDb** - Works now with the provided TMDb key!
2. **View movie lists** - Works immediately
3. **Get movie details** - Works immediately

The only feature that requires uloz.to is:
- Streaming episodes of TV series

---

## Quick Test

### Test Movie Import (Works Now!)
```bash
# Start the server
npm run dev

# In another terminal, test movie import:
curl -X POST http://localhost:3000/api/v1/movies/import/imdb \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"imdbId": "tt14452776"}'
```

### Get Movie List (Works Now!)
```bash
curl "http://localhost:3000/api/v1/movies"
```

---

## Popular BoyLove/LGBTQ+ Content IMDb IDs for Testing

Here are some IMDb IDs you can import right away:

**TV Series:**
- Heartstopper: `tt14452776`
- Young Royals: `tt13406036`
- Red White & Royal Blue: `tt14208870`
- Queer as Folk (2022): `tt14688858`

**Movies:**
- Love, Simon: `tt5164432`
- Call Me By Your Name: `tt5726616`
- Portrait of a Lady on Fire: `tt8613070`
- Moonlight: `tt4975722`

---

## Summary

✅ **TMDb API** - Ready to use! (Already configured)
⏳ **uloz.to API** - Requires your VIP account credentials

You can start importing and viewing movies immediately. Episode streaming will work once you add your uloz.to credentials.

---

**Need Help?**

If you encounter any issues:
1. Check that `npm run dev` starts without errors
2. Verify TMDb API is working by importing a test movie
3. For uloz.to issues, verify your VIP subscription is active

