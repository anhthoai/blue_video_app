# API Endpoints Guide

## Base URL

- **Production**: `https://api.onlybl.com`
- **Local**: `http://localhost:3000`

## Important Notes

- ✅ Health check is at `/health` (NOT `/v1/health`)
- ✅ All other endpoints are prefixed with `/api/v1/`

## Health Check

```bash
# Test the health endpoint
curl http://localhost:3000/health

# Or from external
curl https://api.onlybl.com/health
```

Expected response:
```json
{
  "success": true,
  "message": "Blue Video API is running (Local Development Mode)",
  "timestamp": "2025-10-26T01:51:39.000Z",
  "version": "v1",
  "mode": "development",
  "database": "Mock (Prisma ready)",
  "redis": "Disabled"
}
```

## API Endpoints (with /api/v1 prefix)

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user
- `POST /api/v1/auth/refresh` - Refresh access token
- `GET /api/v1/auth/me` - Get current user info

### Videos
- `GET /api/v1/videos` - Get all videos
- `GET /api/v1/videos/:id` - Get video by ID
- `POST /api/v1/videos/upload` - Upload video
- `GET /api/v1/search/videos?q=query` - Search videos

### Community Posts
- `GET /api/v1/community/posts` - Get all community posts
- `GET /api/v1/community/posts/:id` - Get post by ID
- `POST /api/v1/community/posts` - Create new post
- `GET /api/v1/community/posts/search?q=query` - Search posts

### Search
- `GET /api/v1/search/videos?q=query` - Search videos
- `GET /api/v1/search/posts?q=query` - Search posts
- `GET /api/v1/search/users?q=query` - Search users

### Users
- `GET /api/v1/users/:id` - Get user profile
- `PUT /api/v1/users/profile` - Update user profile
- `POST /api/v1/users/avatar` - Upload avatar
- `POST /api/v1/users/banner` - Upload banner

### Payment
- `GET /api/v1/payment/packages` - Get coin packages
- `POST /api/v1/payment/create-invoice` - Create payment invoice
- `GET /api/v1/payment/status/:orderId` - Check payment status
- `GET /api/v1/payment/history` - Get payment history

### Chat
- `GET /api/v1/chat/rooms` - Get user's chat rooms
- `POST /api/v1/chat/rooms` - Create new chat room
- `GET /api/v1/chat/rooms/:roomId/messages` - Get messages
- `POST /api/v1/chat/rooms/:roomId/messages` - Send message

## Testing Endpoints

### Test Health Check
```bash
curl http://localhost:3000/health
```

### Test Authentication
```bash
# Register
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'

# Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### Test Videos
```bash
# Get all videos
curl http://localhost:3000/api/v1/videos

# Search videos
curl "http://localhost:3000/api/v1/search/videos?q=test"
```

### Test Community Posts
```bash
# Get all posts
curl http://localhost:3000/api/v1/community/posts

# Search posts
curl "http://localhost:3000/api/v1/search/posts?q=test"
```

## Common Issues

### 404 Not Found

**Problem**: Accessing `/v1/health` returns 404

**Solution**: Use `/health` instead (no `/v1` prefix for health check)

### Rate Limit Errors

**Problem**: Getting "Too many requests" error

**Cause**: Express rate limiter not configured for proxy

**Solution**: Already fixed with `app.set('trust proxy', true)`

### CORS Errors

**Problem**: CORS errors in browser

**Solution**: Configure `CORS_ORIGIN` in `.env`:
```env
CORS_ORIGIN=https://your-frontend-domain.com,http://localhost:3000
```

## WebSocket Connection

Connect to Socket.IO:
```javascript
import io from 'socket.io-client';

const socket = io('http://localhost:3000', {
  transports: ['websocket', 'polling']
});

socket.on('connect', () => {
  console.log('Connected to server');
});
```

## Production URLs

Once Nginx is configured:

- **Health**: `https://api.onlybl.com/health`
- **API**: `https://api.onlybl.com/api/v1/*`
- **WebSocket**: `wss://api.onlybl.com`

