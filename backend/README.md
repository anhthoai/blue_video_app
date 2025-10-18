# Blue Video Backend API

A comprehensive backend API for the Blue Video social media application, built with Node.js, Express, TypeScript, PostgreSQL, and Redis.

## 🚀 Features

- **Authentication & Authorization**: JWT-based auth with refresh tokens
- **Video Management**: Upload, stream, and manage videos with thumbnails
- **Community Posts**: Text, media, link, and poll posts
- **Real-time Chat**: Socket.io powered messaging
- **File Storage**: S3-compatible storage with Cloudflare CDN
- **Database**: PostgreSQL with Redis for caching
- **Security**: Rate limiting, CORS, helmet, input validation
- **💰 Coin System**: Complete coin-based monetization system
- **💳 Payment Gateway**: USDT (TRC20) and Credit Card payment processing
- **📊 Transaction Tracking**: Complete coin transaction history with Order IDs
- **🔔 IPN Processing**: Real-time payment confirmation system

## 🛠 Tech Stack

- **Backend**: Node.js + Express + TypeScript
- **Database**: PostgreSQL + Redis
- **Storage**: S3-compatible storage + Cloudflare CDN
- **Real-time**: Socket.io
- **Video Processing**: FFmpeg
- **Authentication**: JWT + Refresh Tokens
- **Security**: Helmet, CORS, Rate Limiting
- **Payment Processing**: mypremium.store API integration
- **Cryptocurrency**: USDT (TRC20) support
- **IPN Handling**: Real-time payment notifications

## 📋 Prerequisites

- Node.js 18+
- PostgreSQL 13+
- Redis 6+
- FFmpeg
- S3-compatible storage account
- Cloudflare account (for CDN)

## 🚀 Quick Start

### 1. Clone and Install

```bash
cd blue_video_app/backend
npm install
```

### 2. Environment Setup

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
# Server Configuration
NODE_ENV=development
PORT=3000
API_VERSION=v1

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=blue_video_db
DB_USER=blue_video_user
DB_PASSWORD=your_db_password

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key_here
JWT_REFRESH_SECRET=your_super_secret_refresh_key_here
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# S3 Compatible Storage Configuration
S3_ENDPOINT=https://your-s3-endpoint.com
S3_ACCESS_KEY_ID=your_s3_access_key
S3_SECRET_ACCESS_KEY=your_s3_secret_key
S3_BUCKET_NAME=blue-video-storage
S3_REGION=us-east-1

# Cloudflare CDN Configuration
CDN_URL=https://your-cdn-domain.com
CDN_CACHE_TTL=31536000

# Payment Gateway Configuration
PAYMENT_API_KEY=your_payment_api_key
PAYMENT_API_URL=https://api.mypremium.store
PAYMENT_IPN_URL=https://your-domain.com/api/v1/payment/ipn
```

### 3. Database Setup

```bash
# Create PostgreSQL database
createdb blue_video_db

# Create Redis instance (if not using cloud)
redis-server
```

### 4. Install FFmpeg

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ffmpeg
```

**macOS:**
```bash
brew install ffmpeg
```

**Windows:**
Download from https://ffmpeg.org/download.html

### 5. Run the Server

```bash
# Development
npm run dev

# Production
npm run build
npm start
```

## 📚 API Documentation

### Base URL
```
http://localhost:3000/api/v1
```

### Authentication Endpoints

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

### Video Endpoints

#### Upload Video
```http
POST /api/v1/videos/upload
Authorization: Bearer your_access_token
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

### Coin System Endpoints

#### Get Coin Packages
```http
GET /api/v1/coin-packages
```

#### Create USDT Payment Invoice
```http
POST /api/v1/payment/usdt/invoice
Authorization: Bearer your_access_token
Content-Type: application/json

{
  "coins": 100
}
```

#### Create Credit Card Payment Invoice
```http
POST /api/v1/payment/credit-card/invoice
Authorization: Bearer your_access_token
Content-Type: application/json

{
  "coins": 100
}
```

#### Check Payment Status
```http
GET /api/v1/payment/status/:orderId
Authorization: Bearer your_access_token
```

#### IPN Notification Endpoint
```http
POST /api/v1/payment/ipn
Content-Type: application/x-www-form-urlencoded

extOrderId=order_123&status=OK&sbpayMethod=cryptocurrency&...
```

#### Get Coin Transaction History
```http
GET /api/v1/users/coin-transactions?type=RECHARGE&page=1&limit=20
Authorization: Bearer your_access_token
```

#### Simulate IPN (Development Only)
```http
POST /api/v1/payment/simulate-ipn/:orderId
Authorization: Bearer your_access_token
```

## 🔧 Configuration

### S3-Compatible Storage Setup

1. **Choose your S3-compatible provider:**
   - AWS S3
   - DigitalOcean Spaces
   - MinIO
   - Wasabi
   - Backblaze B2

2. **Configure your provider:**
   ```env
   S3_ENDPOINT=https://your-provider-endpoint.com
   S3_ACCESS_KEY_ID=your_access_key
   S3_SECRET_ACCESS_KEY=your_secret_key
   S3_BUCKET_NAME=blue-video-storage
   S3_REGION=us-east-1
   ```

### Cloudflare CDN Setup

1. **Add your domain to Cloudflare**
2. **Create a CNAME record pointing to your S3 bucket**
3. **Configure CDN URL:**
   ```env
   CDN_URL=https://your-cdn-domain.com
   ```

### Payment Gateway Setup

1. **Register with mypremium.store:**
   - Create an account at https://mypremium.store
   - Get your API key from the dashboard
   - Configure your IPN URL: `https://your-domain.com/api/v1/payment/ipn`

2. **Configure environment variables:**
   ```env
   PAYMENT_API_KEY=your_payment_api_key
   PAYMENT_API_URL=https://api.mypremium.store
   PAYMENT_IPN_URL=https://your-domain.com/api/v1/payment/ipn
   ```

3. **Supported Payment Methods:**
   - **USDT (TRC20)**: Cryptocurrency payments
   - **Credit Card**: Traditional card payments

4. **IPN (Instant Payment Notification):**
   - Payment gateway sends notifications to your IPN endpoint
   - Backend processes payments and updates user coin balance
   - Frontend polls payment status until completion

### OVH VPS Setup

1. **Install Node.js 18+:**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

2. **Install PostgreSQL:**
   ```bash
   sudo apt install postgresql postgresql-contrib
   ```

3. **Install Redis:**
   ```bash
   sudo apt install redis-server
   ```

4. **Install FFmpeg:**
   ```bash
   sudo apt install ffmpeg
   ```

5. **Configure firewall:**
   ```bash
   sudo ufw allow 3000
   sudo ufw allow 5432
   sudo ufw allow 6379
   ```

## 🚀 Deployment

### Using PM2 (Recommended)

```bash
# Install PM2
npm install -g pm2

# Start application
pm2 start dist/server.js --name blue-video-api

# Save PM2 configuration
pm2 save
pm2 startup
```

### Using Docker

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY dist/ ./dist/

EXPOSE 3000

CMD ["node", "dist/server.js"]
```

### Using Nginx (Reverse Proxy)

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 🔒 Security Features

- **JWT Authentication** with refresh tokens
- **Rate Limiting** to prevent abuse
- **CORS** protection
- **Helmet** security headers
- **Input Validation** with Joi
- **Password Hashing** with bcrypt
- **SQL Injection** protection with parameterized queries
- **Payment Security** with IPN signature verification
- **Order ID Validation** to prevent duplicate payments
- **Transaction Logging** for complete audit trail

## 💰 Coin System Architecture

### Database Schema
- **Users**: `coinBalance` field for current coin balance
- **Posts**: `cost` and `requiresVip` fields for monetization
- **Payments**: Complete payment tracking with Order IDs
- **CoinTransactions**: Full transaction history (RECHARGE, EARNED, USED)

### Payment Flow
1. **Invoice Creation**: Generate payment invoice with unique Order ID
2. **Payment Processing**: User pays via USDT or Credit Card
3. **IPN Notification**: Payment gateway sends confirmation
4. **Balance Update**: Backend updates user coin balance
5. **Transaction Logging**: Record transaction in database
6. **Frontend Sync**: Real-time balance updates via polling

### Transaction Types
- **RECHARGE**: User purchases coins
- **EARNED**: Author receives coins from content sales
- **USED**: User spends coins on content or subscriptions

## 📊 Monitoring

### Health Check
```http
GET /health
```

### Logs
```bash
# View logs
pm2 logs blue-video-api

# View specific log
pm2 logs blue-video-api --lines 100
```

## 🧪 Testing

```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage
```

## 📈 Performance

- **Database Indexing** for optimal queries
- **Redis Caching** for frequently accessed data
- **CDN Integration** for fast file delivery
- **Compression** middleware for responses
- **Connection Pooling** for database connections

## 🔧 Development

```bash
# Development mode with hot reload
npm run dev

# Build for production
npm run build

# Lint code
npm run lint

# Fix linting issues
npm run lint:fix
```

## 📝 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment | `development` |
| `PORT` | Server port | `3000` |
| `DB_HOST` | PostgreSQL host | `localhost` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_NAME` | Database name | `blue_video_db` |
| `REDIS_HOST` | Redis host | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `JWT_SECRET` | JWT secret key | Required |
| `S3_ENDPOINT` | S3 endpoint | Required |
| `CDN_URL` | CDN URL | Required |
| `PAYMENT_API_KEY` | Payment gateway API key | Required |
| `PAYMENT_API_URL` | Payment gateway API URL | Required |
| `PAYMENT_IPN_URL` | IPN callback URL | Required |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support, email support@bluevideo.com or create an issue on GitHub.

---

**Built with ❤️ for the Blue Video community**
