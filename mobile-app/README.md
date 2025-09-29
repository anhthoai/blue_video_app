# Blue Video App - Mobile Application

A comprehensive video streaming and social platform built with Flutter.

## 📱 Features

### 🎬 Video Features
- Video streaming with custom controls
- Video upload and management
- Video compression and optimization
- Video thumbnail generation
- Video progress tracking
- Video quality selection
- Fullscreen video playback
- Video caching and offline support

### 👤 User Management
- User registration and login
- Phone number verification
- Password reset functionality
- Social login integration
- User profile management
- Account switching

### 💬 Social Features
- Real-time chat functionality
- Private messaging
- Group messaging
- Message history
- Message notifications
- Chat matching system
- Like and dislike system
- Comment system with replies
- Share functionality
- Follow/Unfollow system
- User discovery
- Social feed

### 🎮 Gaming Integration
- Game lobby system
- Game recharge system
- Game withdrawal system
- Game activity tracking
- Game leaderboards
- Game rewards system

### 💰 Monetization
- Coin-based economy
- VIP membership system
- Payment processing
- Withdrawal system
- Income tracking
- Promotional earnings
- Pay-per-view videos
- Subscription content
- Creator earnings
- Ad revenue sharing

## 🛠️ Tech Stack

- **Framework**: Flutter 3.10+
- **Language**: Dart 3.0+
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Database**: SQLite + Hive
- **Authentication**: Firebase Auth
- **Storage**: SharedPreferences
- **Notifications**: Firebase Messaging
- **Analytics**: Firebase Analytics
- **UI**: Material Design 3

## 📁 Project Structure

```
mobile-app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── core/                     # Core functionality
│   │   ├── router/              # Navigation
│   │   ├── services/            # Business logic
│   │   └── theme/               # App theming
│   ├── models/                   # Data models
│   ├── screens/                  # UI screens
│   │   ├── auth/                # Login/Register
│   │   ├── main/                # Main navigation
│   │   ├── home/                # Home feed
│   │   ├── discover/            # Discovery
│   │   ├── community/           # Social features
│   │   ├── profile/             # User profiles
│   │   ├── video/               # Video features
│   │   ├── chat/                # Messaging
│   │   └── settings/            # App settings
│   └── widgets/                  # Reusable components
├── assets/                       # App assets
├── android/                      # Android specific
├── ios/                          # iOS specific
├── web/                          # Web specific
├── windows/                      # Windows specific
├── macos/                        # macOS specific
├── linux/                        # Linux specific
└── pubspec.yaml                  # Dependencies
```

## 🚀 Getting Started

### Prerequisites
   - Flutter SDK (latest stable)
   - Dart SDK
   - Android Studio / VS Code
   - Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd blue_video_app/mobile-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Building for Production

#### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

#### Web
```bash
flutter build web --release
```

## 📱 Screenshots

*Screenshots will be added as development progresses*

## 🔧 Configuration

### Firebase Setup
1. Create a Firebase project
2. Add Android/iOS apps to the project
3. Download configuration files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
4. Enable required services:
   - Authentication
   - Cloud Messaging
   - Analytics
   - Crashlytics

### Environment Variables
Create a `.env` file in the root directory:
```env
API_BASE_URL=https://api.bluevideoapp.com
FIREBASE_PROJECT_ID=your-project-id
```

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

## 📊 Performance

- **App Size**: Optimized for minimal download size
- **Memory Usage**: Efficient memory management
- **Battery Life**: Optimized for extended usage
- **Network**: Smart caching and offline support

## 🔒 Security

- Data encryption in transit and at rest
- Secure authentication
- API security
- Content protection
- Privacy settings
- GDPR compliance

## 🌐 Localization

- English (primary)
- Chinese (original)
- Dynamic language switching
- RTL support

## 📈 Analytics

- User behavior tracking
- Video performance metrics
- Revenue analytics
- Usage statistics
- Crash reporting

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
- Check the documentation

---

**Note**: This is the mobile application component of the Blue Video App project. For the complete project structure, see the main README.md file.