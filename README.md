# Blue Video App - Full-Stack Video Streaming Platform

A comprehensive video streaming and social media platform with Flutter mobile app and Node.js backend API.

## ✨ Key Features

- 📱 **Native Mobile App** - Flutter for iOS & Android
- 🎥 **Video Streaming** - Upload, stream, and manage videos
- 💬 **Social Network** - Follow, like, comment, share
- 💰 **Monetization** - Coin system with real payment processing
- 🌍 **Multi-language** - English, Chinese, Japanese
- 🎨 **Themes** - Light, Dark, and System modes
- 📧 **Email Verification** - SMTP-based account verification
- 💳 **Payments** - USDT (TRC20) and Credit Card support
- 🔍 **Search** - Find videos, users, and posts
- 💬 **Real-time Chat** - WebSocket-based messaging
- 📊 **Analytics** - User and content statistics
- 🔐 **Secure** - JWT authentication, rate limiting, encryption

## 📁 Project Structure

```
blue_video_app/
├── mobile-app/                    # Flutter mobile application
│   ├── lib/
│   │   ├── core/                 # Core services and utilities
│   │   │   ├── services/         # API, Auth, Theme, Locale services
│   │   │   ├── router/           # GoRouter configuration
│   │   │   └── theme/            # Theme definitions
│   │   ├── screens/              # All app screens
│   │   │   ├── auth/             # Login, Register, Verify Email
│   │   │   ├── home/             # Home screen
│   │   │   ├── video/            # Video player, Upload
│   │   │   ├── community/        # Community posts
│   │   │   ├── profile/          # User profiles
│   │   │   ├── chat/             # Messaging
│   │   │   ├── coin/             # Coin recharge & history
│   │   │   ├── settings/         # Settings, Theme, Language
│   │   │   └── search/           # Search functionality
│   │   ├── widgets/              # Reusable widgets
│   │   ├── models/               # Data models
│   │   └── l10n/                 # Localization (EN, ZH, JA)
│   └── pubspec.yaml
│
├── backend/                       # Node.js backend API
│   ├── src/
│   │   ├── server.ts             # Main server file with all endpoints
│   │   ├── services/             # Email, S3, Payment, Video processing
│   │   ├── config/               # Swagger, Database config
│   │   ├── middleware/           # Auth, Rate limiting
│   │   └── utils/                # Helper functions
│   ├── prisma/
│   │   ├── schema.prisma         # Database schema
│   │   └── migrations/           # Database migrations
│   ├── package.json
│   └── .env                      # Environment configuration
│
├── .github/
│   └── workflows/
│       └── deploy-backend.yml    # CI/CD deployment workflow
│
├── docs/                          # Project documentation
├── EMAIL_VERIFICATION_GUIDE.md    # Email verification implementation
├── EMAIL_AUTHENTICATION_FIX.md    # SPF/DKIM setup guide
├── TESTING_EMAIL_VERIFICATION.md  # Testing procedures
├── SWAGGER_DOCUMENTATION.md       # API documentation guide
└── README.md                      # This file
```

## 🚀 Components

### 📱 Mobile App (`mobile-app/`)
The main Flutter mobile application for iOS and Android.

**Features:**
- Video streaming and social platform
- User authentication and profiles
- Social features (follow, like, comment, share)
- Video upload and management
- Real-time messaging
- Push notifications
- **Coin/VIP Posts**: Monetized content with coin payments
- **Payment Gateway**: USDT (TRC20) and Credit Card payments
- **Coin System**: Recharge, earn, and spend coins
- **Transaction History**: Complete coin transaction tracking

**Tech Stack:**
- Flutter 3.10+
- Dart 3.0+
- Node.js + Express (Backend)
- PostgreSQL + Prisma ORM (Database)
- Cloudflare R2 (File Storage)
- JWT Authentication
- SMTP Email (Nodemailer)
- Socket.io (Real-time)
- Riverpod (State Management)
- GoRouter (Navigation)
- SharedPreferences + Hive (Local Storage)

**Getting Started:**
```bash
cd mobile-app
flutter pub get
flutter run
```

### 🖥️ Backend API (`backend/`)
Node.js backend API server with PostgreSQL database.

**Features:**
- RESTful API with Express.js
- PostgreSQL database with Prisma ORM
- JWT authentication with email verification
- File upload to Cloudflare R2
- Real-time chat with Socket.io
- Payment processing (USDT TRC20 + Credit Card)
- Email service with SMTP
- API documentation with Swagger
- Rate limiting and security middleware

**Tech Stack:**
- Node.js + TypeScript
- Express.js
- PostgreSQL
- Prisma ORM
- Cloudflare R2 (S3-compatible storage)
- Nodemailer (SMTP)
- Socket.io (WebSocket)
- JWT + bcrypt
- Swagger/OpenAPI 3.0

**Getting Started:**
```bash
cd backend
npm install
npx prisma db push
npm run dev
```

**API Documentation:**
Open http://localhost:3000/api-docs after starting the server.

### 🌐 Landing Page (`landing-page/`)
Web landing page for marketing and app promotion (future implementation).

### 📚 Documentation (`docs/`)
Comprehensive project documentation:
- `EMAIL_VERIFICATION_GUIDE.md` - Email verification system
- `EMAIL_AUTHENTICATION_FIX.md` - SPF/DKIM configuration
- `TESTING_EMAIL_VERIFICATION.md` - Testing guide
- `SWAGGER_DOCUMENTATION.md` - API documentation guide
- `.github/API_ENDPOINTS.md` - Complete API reference
- `.github/POST_DEPLOYMENT.md` - Deployment checklist

## 🛠️ Development Setup

### Prerequisites

**For Mobile App:**
- Flutter SDK 3.10+ (latest stable)
- Dart SDK 3.0+
- Android Studio or VS Code
- Git

**For Backend:**
- Node.js 18+ and npm
- PostgreSQL 14+
- Git

**Optional:**
- Docker (for containerized development)
- Postman (for API testing)

### Full Stack Development Setup

#### 1. Backend Setup

```bash
# Navigate to backend
cd backend

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your database and SMTP credentials

# Setup database
npx prisma db push

# Seed sample data (optional)
npx prisma db seed

# Start development server
npm run dev

# Server runs on http://localhost:3000
# API docs at http://localhost:3000/api-docs
```

#### 2. Mobile App Setup

```bash
# Navigate to mobile app
cd mobile-app

# Install dependencies
flutter pub get

# Configure environment
# Edit .env with your API_BASE_URL

# Run the app
flutter run

# Build for production
flutter build apk     # Android
flutter build ios     # iOS
```

#### 3. Verify Setup

- Backend: Open http://localhost:3000/health
- API Docs: Open http://localhost:3000/api-docs
- Mobile App: Should connect to backend and show content

## 📱 Mobile App Features

### Core Features
- ✅ **Authentication**: Email/password with JWT tokens
- ✅ **Email Verification**: Complete SMTP-based email verification system
- ✅ **Video Streaming**: Complete video player with full layout
- ✅ **Social Features**: Follow, like, comment, share
- ✅ **User Profiles**: Complete profile management (current user and other users)
- ✅ **Navigation**: Deep linking and route management with GoRouter
- ✅ **Theming**: Material Design 3 with light/dark/system theme modes
- ✅ **Multi-language**: English, Chinese (简体), Japanese (日本語) support
- ✅ **Storage**: SharedPreferences for user data and settings
- ✅ **UI/UX**: Responsive design with overflow fixes
- ✅ **Coin/VIP Posts**: Monetized content requiring coin payments
- ✅ **Payment Gateway**: Real payment processing with USDT and Credit Cards
- ✅ **Coin System**: Recharge, earn, and spend coins
- ✅ **Transaction History**: Complete coin transaction tracking with Order IDs
- ✅ **Search**: Videos, users, and posts search functionality
- ✅ **Community**: Posts with media, tags, categories, and filtering

### Screens
- **Splash Screen**: Animated loading with auth check
- **Authentication**: Login & Register with email/password
- **Email Verification**: Verify email addresses via link
- **Home**: Video feed with stories, trending, and search
- **Discover**: Categories, trending, and live content
- **Community**: Social feed with posts, filtering, and search
- **Profile**: User profiles with stats and content tabs (Videos, Posts, Liked, Collections, Analytics)
- **Video Player**: Complete video player with user info, actions, recommendations, and comments
- **Video Upload**: Upload videos with categories, tags, and pricing
- **Chat**: Real-time messaging system with rooms
- **Search**: Dedicated search screen with tabs for videos, users, and posts
- **Settings**: App configuration with theme and language selection
- **Coin Recharge**: Purchase coins with USDT or Credit Card payments
- **Coin History**: Track coin transactions (Used, Earned, Recharge) with Order IDs
- **VIP Subscription**: Subscribe to creators for exclusive content
- **Payment Dialogs**: USDT (TRC20) and Credit Card payment interfaces
- **Playlist Management**: Create and manage video playlists

### Architecture
- **State Management**: Riverpod (StateNotifier, Provider, Consumer)
- **Navigation**: GoRouter with deep linking
- **Local Storage**: SharedPreferences, Hive
- **Backend**: Node.js, Express, PostgreSQL, Prisma ORM
- **File Storage**: Cloudflare R2 (S3-compatible)
- **Authentication**: JWT tokens with email verification
- **Email**: SMTP with Nodemailer
- **Real-time**: Socket.io for chat and notifications
- **API Documentation**: Swagger/OpenAPI 3.0
- **UI**: Material Design 3 with custom themes

## 💰 Coin System & Payment Features

### Coin/VIP Posts
- **Monetized Content**: Posts can require coin payments or VIP subscription
- **Visual Indicators**: Coin/VIP icons displayed on post thumbnails
- **Payment Protection**: Grid layout prevents content preview before payment
- **Author Benefits**: Authors can view their own paid content without payment

### Payment Gateway Integration
- **USDT (TRC20)**: Cryptocurrency payments with QR codes and wallet addresses
- **Credit Card**: Traditional card payments with secure processing
- **Real-time Processing**: IPN (Instant Payment Notification) workflow
- **Order Tracking**: Unique Order IDs for transaction tracking

### Coin Management
- **Recharge System**: Purchase coins with multiple payment methods
- **Transaction History**: Complete tracking of Used, Earned, and Recharge transactions
- **Balance Updates**: Real-time coin balance synchronization
- **Earning System**: Authors earn coins when their content is purchased

### Security Features
- **IPN Verification**: Secure payment confirmation from payment gateway
- **Order Validation**: Unique Order IDs prevent duplicate payments
- **Transaction Logging**: Complete audit trail for all coin transactions
- **Local Development**: Simulate IPN for testing without real payments

## 🎯 Roadmap

### Phase 1: Core Application ✅ COMPLETED
- [x] Core Flutter app structure
- [x] Backend API (Node.js + Express + PostgreSQL)
- [x] Authentication system (JWT + Email verification)
- [x] Email service (SMTP with Nodemailer)
- [x] Video streaming with complete player
- [x] Video upload functionality with categories and tags
- [x] Social features (follow, like, comment, share)
- [x] User profiles (current user and other users)
- [x] Search functionality (videos, users, posts)
- [x] Community posts with media and interactions
- [x] Real-time chat with Socket.io
- [x] Multi-language support (EN, ZH, JA)
- [x] Theme system (Light, Dark, System)
- [x] UI overflow fixes and responsive design
- [x] **Coin/VIP Posts system with payment integration**
- [x] **Real payment gateway (USDT TRC20 + Credit Card)**
- [x] **Coin recharge and transaction history**
- [x] **IPN (Instant Payment Notification) workflow**
- [x] **API Documentation (Swagger/OpenAPI)**
- [x] **Deployment automation (GitHub Actions)**

### Phase 2: Enhancements 🔄 IN PROGRESS
- [x] Email verification system
- [ ] Social login (Google, Apple) - Prepared for future
- [ ] Push notifications (Firebase Cloud Messaging)
- [ ] Video processing pipeline (FFmpeg)
- [ ] Advanced analytics dashboard
- [ ] Content moderation tools
- [ ] Live streaming support
- [ ] Stories feature completion
- [ ] Advanced search filters

### Phase 3: Web & Additional Platforms
- [ ] Web landing page
- [ ] Web app (PWA)
- [ ] Admin dashboard (web)
- [ ] Desktop app (Windows, macOS, Linux)
- [ ] TV app (Android TV, Apple TV)

### Phase 4: Advanced Features
- [ ] AI-powered content recommendations
- [ ] Video transcoding and adaptive bitrate
- [ ] CDN integration
- [ ] Advanced monetization options
- [ ] Creator analytics and insights

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation in `docs/`

---

**Note**: This is a comprehensive multi-platform project. Each component can be developed and deployed independently while sharing common resources and documentation.