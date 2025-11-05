# Quick Migration & Start Commands

## Run These Commands in Order

### 1. Generate Prisma Client
```bash
npx prisma generate
```

### 2. Create and Apply Migration
```bash
npx prisma migrate dev --name add_library_feature
```

### 3. Start Development Server
```bash
npm run dev
```

---

## Verify Migration Success

### Check Tables
```bash
npx prisma studio
```

### Or use psql
```bash
psql -U blue_video_user -d blue_video_db -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'movie%';"
```

---

## Test API (After Server Starts)

### Import Heartstopper (Gay Teen Drama TV Series)
```bash
# Replace YOUR_TOKEN with actual JWT token from login
curl -X POST http://localhost:3000/api/v1/movies/import/imdb \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"imdbId": "tt14452776"}'
```

### Get Movies List
```bash
curl "http://localhost:3000/api/v1/movies?lgbtqType=gay"
```

---

## All Set! 🎉

Your backend is ready to serve movies to the mobile app.

