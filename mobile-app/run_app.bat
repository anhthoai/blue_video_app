@echo off
echo 🚀 Starting Blue Video App Testing...
echo.
echo 📱 This will run the Flutter app with mock data for testing
echo.
echo 🔧 Prerequisites:
echo    - Flutter SDK installed
echo    - Android Studio or VS Code with Flutter extension
echo    - Android device/emulator or iOS simulator
echo.
echo 📋 Testing Features Available:
echo    ✅ Home screen with video feed
echo    ✅ Community posts and interactions
echo    ✅ Chat system with real-time messaging
echo    ✅ User profiles and authentication
echo    ✅ Video upload and playback
echo    ✅ Social features (like, comment, share)
echo    ✅ Content moderation tools
echo.
echo 🎯 Mock Data Included:
echo    • 20 sample users
echo    • 50 sample videos
echo    • 30 community posts
echo    • 10 chat rooms with messages
echo.
echo ⚠️  Note: All data is mock data - no real API connections
echo.
echo Press any key to start the app...
pause > nul
echo.
echo 🔄 Running flutter pub get...
flutter pub get
echo.
echo 🏃 Starting the app...
flutter run
echo.
echo 📱 App launched! Check your device/emulator.
echo.
echo 🧪 To access test instructions:
echo    1. Open the app
echo    2. Go to Settings (bottom navigation)
echo    3. Tap "Test Instructions"
echo.
echo Press any key to exit...
pause > nul
