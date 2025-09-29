# Blue Video App - Multi-Platform Project

A comprehensive video streaming and social platform with multiple components for different platforms and purposes.

## 📁 Project Structure

```
blue_video_app/
├── mobile-app/          # Flutter mobile application
├── landing-page/        # Web landing page (future)
├── docs/               # Project documentation
├── .gitignore          # Git ignore rules
└── README.md           # This file
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

**Tech Stack:**
- Flutter 3.10+
- Dart 3.0+
- Firebase (Auth, Messaging, Analytics)
- Riverpod (State Management)
- GoRouter (Navigation)
- SQLite (Local Storage)

**Getting Started:**
```bash
cd mobile-app
flutter pub get
flutter run
```

### 🌐 Landing Page (`landing-page/`)
Web landing page for marketing and app promotion (future implementation).

### 📚 Documentation (`docs/`)
Project documentation, API specs, and development guides.

## 🛠️ Development Setup

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK
- Android Studio / VS Code
- Git

### Mobile App Development
1. Navigate to the mobile app directory:
   ```bash
   cd mobile-app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

4. Build for production:
   ```bash
   flutter build apk    # Android
   flutter build ios    # iOS
   ```

## 📱 Mobile App Features

### Core Features
- ✅ **Authentication**: Firebase Auth with email/phone
- ✅ **Video Streaming**: Complete video player integration
- ✅ **Social Features**: Follow, like, comment, share
- ✅ **User Profiles**: Complete profile management
- ✅ **Navigation**: Deep linking and route management
- ✅ **Theming**: Material Design 3 with dark mode
- ✅ **Storage**: Local SQLite database
- ✅ **Notifications**: Firebase push notifications

### Screens
- **Splash Screen**: Animated loading with auth check
- **Authentication**: Login & Register with validation
- **Home**: Video feed with stories and trending
- **Discover**: Categories, trending, and live content
- **Community**: Social feed with posts and interactions
- **Profile**: User profiles with stats and content tabs
- **Video**: Video player, upload, and management
- **Chat**: Messaging system
- **Settings**: App configuration

### Architecture
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Database**: SQLite with Hive
- **Authentication**: Firebase Auth
- **Storage**: SharedPreferences
- **UI**: Material Design 3

## 🎯 Roadmap

### Phase 1: Mobile App (Current)
- [x] Core Flutter app structure
- [x] Authentication system
- [x] Video streaming
- [x] Social features
- [x] User profiles
- [ ] Real API integration
- [ ] Video upload functionality
- [ ] Advanced features

### Phase 2: Web Landing Page
- [ ] Marketing website
- [ ] App download links
- [ ] Feature showcase
- [ ] Contact information

### Phase 3: Backend Services
- [ ] REST API
- [ ] Video processing
- [ ] User management
- [ ] Analytics

### Phase 4: Additional Platforms
- [ ] Desktop app (Windows, macOS, Linux)
- [ ] Web app (PWA)
- [ ] TV app (Android TV, Apple TV)

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