# How to Get TMDb API Key (FREE) 🎬

## Quick Setup (5 minutes)

### Step 1: Create TMDb Account
1. Go to: https://www.themoviedb.org/signup
2. Fill in:
   - Username
   - Email
   - Password
3. Click "Sign Up"
4. **Check your email** and verify account

### Step 2: Get API Key
1. Log in to https://www.themoviedb.org
2. Click your **profile icon** (top right)
3. Click **Settings**
4. Click **API** in the left sidebar
5. Click **"Request an API Key"`**
6. Select **"Developer"**
7. Accept the terms
8. Fill in the form:
   - Application Name: "Blue Video App"
   - Application URL: "http://localhost:3000"
   - Application Summary: "Personal video streaming app"
9. Click **Submit**

### Step 3: Copy API Key

You'll get **TWO** types of keys:

#### Option A: API Key (v3 auth)
- Looks like: `f0b65e03cac6ded87caf5b2b7a9b3997`
- Use this with **query parameters**

#### Option B: Read Access Token (v4 auth)  
- Looks like: `eyJhbGciOiJIUzI1NiJ9...` (long JWT)
- Use this with **Bearer authentication**

**We need Option B (Read Access Token)** ⭐

### Step 4: Update .env File

Open `backend/.env` and update line 91:

```env
TMDB_API_KEY=YOUR_READ_ACCESS_TOKEN_HERE
```

Paste the **entire** Read Access Token (the long one starting with `eyJh...`)

### Step 5: Restart Server

In your backend terminal:
- Press `Ctrl+C` to stop
- Run `npm run dev` again

---

## Alternative: Use API Key (v3)

If you prefer to use the simpler API key, update the TMDb service:

### Option 1: Update .env
```env
TMDB_API_KEY=your_api_key_here
```

### Option 2: Update tmdbService.ts

Change lines 142-148 to:

```typescript
this.client = axios.create({
  baseURL: this.config.baseUrl,
  params: {
    api_key: this.config.apiKey,
  },
});
```

(Remove the Bearer header, use params instead)

---

## 🧪 Test After Setup

```powershell
# Test import
$body = '{"imdbId": "tt14452776"}'
Invoke-RestMethod -Uri "http://localhost:3000/api/v1/movies/import/imdb" -Method Post -ContentType "application/json" -Body $body
```

**Expected:** Success message with movie data!

---

## 📌 Quick Reference

**TMDb Website**: https://www.themoviedb.org
**API Settings**: https://www.themoviedb.org/settings/api
**API Docs**: https://developers.themoviedb.org/3

---

**It's completely FREE for personal use!** ✨

