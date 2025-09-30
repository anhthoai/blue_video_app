import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/mock_data_generator.dart';
import '../../models/community_post.dart';
import '../../models/user_model.dart';
import '../../models/video_model.dart';
import '../../models/chat_room.dart';
import '../../models/chat_message.dart';

class TestDataService {
  static void populateMockData(WidgetRef ref) {
    print('🎯 Populating mock data for testing...');

    // Generate mock data
    final users = MockDataGenerator.generateUsers(20);
    final videos = MockDataGenerator.generateVideos(50);
    final communityPosts = MockDataGenerator.generateCommunityPosts(30);
    final chatRooms = MockDataGenerator.generateChatRooms(10);

    print('✅ Generated ${users.length} users');
    print('✅ Generated ${videos.length} videos');
    print('✅ Generated ${communityPosts.length} community posts');
    print('✅ Generated ${chatRooms.length} chat rooms');

    // Store mock data in providers (this would be done automatically by the services)
    print('📊 Mock data ready for testing!');
  }

  static void printTestInstructions() {
    print('\n🧪 TESTING INSTRUCTIONS:');
    print('═══════════════════════════════════════════════════════════════');
    print('');
    print('1. 🏠 HOME SCREEN:');
    print('   • Scroll through video feed');
    print('   • Tap on videos to play');
    print('   • Use like, comment, share buttons');
    print('   • Pull to refresh');
    print('');
    print('2. 🔍 DISCOVER SCREEN:');
    print('   • Browse trending content');
    print('   • Filter by categories');
    print('   • Search for content');
    print('');
    print('3. 💬 COMMUNITY SCREEN:');
    print('   • View community posts');
    print('   • Switch between Posts/Trending/Videos tabs');
    print('   • Tap + button to create post');
    print('   • Interact with posts (like, comment, share)');
    print('');
    print('4. 👤 PROFILE SCREEN:');
    print('   • View user profile');
    print('   • Edit profile information');
    print('   • Upload profile picture');
    print('   • View user stats');
    print('');
    print('5. 💭 CHAT FEATURES:');
    print('   • Navigate to chat list');
    print('   • Open individual chats');
    print('   • Send messages');
    print('   • See typing indicators');
    print('');
    print('6. 🔐 AUTHENTICATION:');
    print('   • Login with any email/password');
    print('   • Register new account');
    print('   • Test social login buttons');
    print('');
    print('7. 🎬 VIDEO FEATURES:');
    print('   • Upload videos');
    print('   • Play videos with quality selection');
    print('   • View video details');
    print('');
    print('8. 🛡️ MODERATION (Admin):');
    print('   • Navigate to moderation screen');
    print('   • Review reported content');
    print('   • Take moderation actions');
    print('');
    print('═══════════════════════════════════════════════════════════════');
    print('💡 TIP: All data is mock data - changes will reset on app restart');
    print('💡 TIP: Use different tabs and screens to test all features');
    print('💡 TIP: Try different user interactions to test the UI');
    print('');
  }
}

// Provider for test data service
final testDataServiceProvider = Provider<TestDataService>((ref) {
  return TestDataService();
});
