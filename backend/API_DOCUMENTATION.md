# Blue Video API Documentation

## Base URL
```
http://localhost:3000/api/v1
```

## Authentication
All protected endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <access_token>
```

## API Endpoints

### Authentication

#### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "password123",
  "first_name": "John",
  "last_name": "Doe",
  "bio": "Video creator"
}
```

#### Login
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "password123"
}
```

#### Refresh Token
```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "refreshToken": "your_refresh_token"
}
```

#### Logout
```http
POST /api/v1/auth/logout
Content-Type: application/json

{
  "refreshToken": "your_refresh_token"
}
```

#### Get Profile
```http
GET /api/v1/auth/profile
Authorization: Bearer <access_token>
```

#### Change Password
```http
PUT /api/v1/auth/change-password
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "currentPassword": "old_password",
  "newPassword": "new_password"
}
```

### Videos

#### Upload Video
```http
POST /api/v1/videos/upload
Authorization: Bearer <access_token>
Content-Type: multipart/form-data

video: [file]
title: "My Video"
description: "Video description"
```

#### Get Video
```http
GET /api/v1/videos/:id
```

#### Get Videos Feed
```http
GET /api/v1/videos?page=1&limit=20
```

#### Get Trending Videos
```http
GET /api/v1/videos/trending?page=1&limit=20
```

#### Search Videos
```http
GET /api/v1/videos/search?q=search_term&page=1&limit=20
```

#### Get User's Videos
```http
GET /api/v1/videos/user/:userId?page=1&limit=20
```

#### Update Video
```http
PUT /api/v1/videos/:id
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "Updated Title",
  "description": "Updated description",
  "is_public": true
}
```

#### Delete Video
```http
DELETE /api/v1/videos/:id
Authorization: Bearer <access_token>
```

#### Get Video Stats
```http
GET /api/v1/videos/stats?userId=user_id
```

### Community Posts

#### Create Post
```http
POST /api/v1/community/posts
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "Post Title",
  "content": "Post content",
  "type": "text",
  "tags": ["tag1", "tag2"],
  "category": "general"
}
```

#### Create Media Post
```http
POST /api/v1/community/posts
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "Media Post",
  "content": "Check out these images and videos!",
  "type": "media",
  "images": ["https://example.com/image1.jpg", "https://example.com/image2.jpg"],
  "videos": ["https://example.com/video1.mp4"],
  "tags": ["media", "photos"],
  "category": "lifestyle"
}
```

#### Create Link Post
```http
POST /api/v1/community/posts
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "Interesting Article",
  "content": "Check out this article!",
  "type": "link",
  "link_url": "https://example.com/article",
  "link_title": "Article Title",
  "link_description": "Article description",
  "tags": ["article", "news"],
  "category": "news"
}
```

#### Create Poll Post
```http
POST /api/v1/community/posts
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "What's your favorite color?",
  "content": "Let me know your preference!",
  "type": "poll",
  "poll_options": ["Red", "Blue", "Green", "Yellow"],
  "tags": ["poll", "fun"],
  "category": "entertainment"
}
```

#### Get Post
```http
GET /api/v1/community/posts/:id
```

#### Get Posts Feed
```http
GET /api/v1/community/posts?page=1&limit=20
```

#### Get Trending Posts
```http
GET /api/v1/community/trending?page=1&limit=20
```

#### Search Posts
```http
GET /api/v1/community/search?q=search_term&page=1&limit=20
```

#### Get User's Posts
```http
GET /api/v1/community/posts/user/:userId?page=1&limit=20
```

#### Get Posts by Category
```http
GET /api/v1/community/posts/category/:category?page=1&limit=20
```

#### Update Post
```http
PUT /api/v1/community/posts/:id
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "title": "Updated Title",
  "content": "Updated content",
  "is_public": true
}
```

#### Delete Post
```http
DELETE /api/v1/community/posts/:id
Authorization: Bearer <access_token>
```

#### Vote on Poll
```http
POST /api/v1/community/posts/:id/vote
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "option": "Red"
}
```

#### Get Categories
```http
GET /api/v1/community/categories
```

#### Get Post Stats
```http
GET /api/v1/community/stats?userId=user_id
```

### Users

#### Get User Profile
```http
GET /api/v1/users/:userId
```

#### Update Profile
```http
PUT /api/v1/users/profile
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "first_name": "John",
  "last_name": "Doe",
  "bio": "Updated bio"
}
```

#### Upload Avatar
```http
POST /api/v1/users/avatar
Authorization: Bearer <access_token>
Content-Type: multipart/form-data

avatar: [file]
```

#### Search Users
```http
GET /api/v1/users/search?q=search_term&page=1&limit=20
```

#### Get User's Followers
```http
GET /api/v1/users/:userId/followers?page=1&limit=20
```

#### Get User's Following
```http
GET /api/v1/users/:userId/following?page=1&limit=20
```

#### Follow User
```http
POST /api/v1/users/:userId/follow
Authorization: Bearer <access_token>
```

#### Unfollow User
```http
DELETE /api/v1/users/:userId/follow
Authorization: Bearer <access_token>
```

#### Check Following Status
```http
GET /api/v1/users/:userId/following/check
Authorization: Bearer <access_token>
```

#### Get User Stats
```http
GET /api/v1/users/:userId/stats
```

#### Get Suggested Users
```http
GET /api/v1/users/suggested?limit=10
Authorization: Bearer <access_token>
```

#### Delete Account
```http
DELETE /api/v1/users/account
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "password": "current_password"
}
```

### Chat

#### Create Chat Room
```http
POST /api/v1/chat/rooms
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "name": "Group Chat",
  "type": "group",
  "participantIds": ["user1", "user2", "user3"]
}
```

#### Get Chat Rooms
```http
GET /api/v1/chat/rooms?page=1&limit=20
Authorization: Bearer <access_token>
```

#### Get Room Details
```http
GET /api/v1/chat/rooms/:roomId
Authorization: Bearer <access_token>
```

#### Get Room Messages
```http
GET /api/v1/chat/rooms/:roomId/messages?page=1&limit=50
Authorization: Bearer <access_token>
```

#### Send Message
```http
POST /api/v1/chat/rooms/:roomId/messages
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "Hello everyone!",
  "message_type": "text"
}
```

#### Edit Message
```http
PUT /api/v1/chat/messages/:messageId
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "Updated message"
}
```

#### Delete Message
```http
DELETE /api/v1/chat/messages/:messageId
Authorization: Bearer <access_token>
```

#### Add Participant
```http
POST /api/v1/chat/rooms/:roomId/participants
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "userId": "user_id"
}
```

#### Remove Participant
```http
DELETE /api/v1/chat/rooms/:roomId/participants/:userId
Authorization: Bearer <access_token>
```

#### Leave Room
```http
DELETE /api/v1/chat/rooms/:roomId/leave
Authorization: Bearer <access_token>
```

### Social Interactions

#### Like Content
```http
POST /api/v1/social/:contentType/:contentId/like
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "type": "like"
}
```

#### Get Content Likes
```http
GET /api/v1/social/:contentType/:contentId/likes?page=1&limit=20
```

#### Create Comment
```http
POST /api/v1/social/:contentType/:contentId/comments
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "Great post!",
  "parentId": "parent_comment_id"
}
```

#### Get Content Comments
```http
GET /api/v1/social/:contentType/:contentId/comments?page=1&limit=20
```

#### Get Comment Replies
```http
GET /api/v1/social/comments/:commentId/replies?page=1&limit=20
```

#### Update Comment
```http
PUT /api/v1/social/comments/:commentId
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "content": "Updated comment"
}
```

#### Delete Comment
```http
DELETE /api/v1/social/comments/:commentId
Authorization: Bearer <access_token>
```

#### Share Content
```http
POST /api/v1/social/:contentType/:contentId/share
Authorization: Bearer <access_token>
```

#### Get User's Liked Content
```http
GET /api/v1/social/liked/:contentType?page=1&limit=20
Authorization: Bearer <access_token>
```

## Response Format

### Success Response
```json
{
  "success": true,
  "message": "Operation successful",
  "data": { ... },
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

### Error Response
```json
{
  "success": false,
  "message": "Error message",
  "errors": [
    {
      "field": "email",
      "message": "Email is required"
    }
  ]
}
```

## Status Codes

- `200` - OK
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `409` - Conflict
- `429` - Too Many Requests
- `500` - Internal Server Error

## Rate Limiting

- **Authentication endpoints**: 5 requests per 15 minutes
- **General API**: 100 requests per 15 minutes
- **File uploads**: 10 requests per hour

## WebSocket Events

### Connection
```javascript
const socket = io('http://localhost:3000');

// Join user room
socket.emit('join-user-room', userId);

// Join chat room
socket.emit('join-chat-room', roomId);

// Leave chat room
socket.emit('leave-chat-room', roomId);
```

### Chat Events
```javascript
// Send message
socket.emit('send-message', {
  roomId: 'room_id',
  message: 'Hello!',
  userId: 'user_id',
  username: 'username'
});

// Typing indicators
socket.emit('typing-start', { roomId, userId, username });
socket.emit('typing-stop', { roomId, userId });

// Listen for messages
socket.on('new-message', (data) => {
  console.log('New message:', data);
});

// Listen for typing
socket.on('user-typing', (data) => {
  console.log('User typing:', data);
});
```

### Video Events
```javascript
// Video interactions
socket.emit('video-like', { videoId, userId, username });
socket.emit('video-comment', { videoId, userId, username, comment });

// Listen for video events
socket.on('video-liked', (data) => {
  console.log('Video liked:', data);
});

socket.on('video-commented', (data) => {
  console.log('Video commented:', data);
});
```

### Notifications
```javascript
// Subscribe to notifications
socket.emit('subscribe-notifications', userId);

// Listen for notifications
socket.on('notification', (data) => {
  console.log('Notification:', data);
});
```

## File Upload

### Video Upload
- **Max file size**: 100MB
- **Allowed formats**: MP4, WebM, QuickTime
- **Max duration**: 5 minutes
- **Auto-generated**: Thumbnails, multiple qualities

### Image Upload
- **Max file size**: 10MB
- **Allowed formats**: JPEG, PNG, WebP, GIF
- **Auto-optimization**: Sharp library

### Avatar Upload
- **Max file size**: 5MB
- **Allowed formats**: JPEG, PNG, WebP
- **Auto-resize**: 200x200px

## CDN Integration

All uploaded files are served through Cloudflare CDN:
- **Images**: `https://your-cdn-domain.com/images/...`
- **Videos**: `https://your-cdn-domain.com/videos/...`
- **Thumbnails**: `https://your-cdn-domain.com/thumbnails/...`
- **Avatars**: `https://your-cdn-domain.com/avatars/...`

## Error Handling

The API uses consistent error responses with appropriate HTTP status codes. All errors include a descriptive message and may include additional error details for validation failures.

## Pagination

Most list endpoints support pagination:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)

## Search

Search endpoints support:
- `q`: Search query (required)
- `page`: Page number
- `limit`: Results per page

## Filtering

Some endpoints support filtering:
- **Videos**: By user, category, date range
- **Posts**: By type, category, tags, date range
- **Users**: By verification status, activity

## Sorting

List endpoints support sorting:
- **Videos**: By date, views, likes, trending score
- **Posts**: By date, likes, comments, trending score
- **Users**: By followers, activity, join date
