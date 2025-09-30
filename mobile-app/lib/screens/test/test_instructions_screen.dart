import 'package:flutter/material.dart';

class TestInstructionsScreen extends StatelessWidget {
  const TestInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing Instructions'),
        backgroundColor: Colors.blue[50],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '🏠 Home Screen Testing',
              [
                '• Scroll through video feed to see mock videos',
                '• Tap on videos to open video player',
                '• Use like, comment, share buttons on video cards',
                '• Pull down to refresh the feed',
                '• Navigate to different tabs in bottom navigation',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              '🔍 Discover Screen Testing',
              [
                '• Browse trending content in different categories',
                '• Use the search functionality',
                '• Filter content by categories (Tech, Entertainment, etc.)',
                '• Tap on trending videos to play them',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              '💬 Community Screen Testing',
              [
                '• View community posts in Posts tab',
                '• Switch to Trending tab for trending posts',
                '• Check Videos tab for trending videos',
                '• Tap + button to create new post',
                '• Interact with posts (like, comment, share, bookmark)',
                '• Tap on user avatars to view profiles',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              '👤 Profile Screen Testing',
              [
                '• View user profile information',
                '• Tap edit button to modify profile',
                '• Upload profile picture (mock functionality)',
                '• View user stats (followers, following, videos)',
                '• Browse user\'s videos and liked content',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              '💭 Chat Features Testing',
              [
                '• Navigate to chat list from main screen',
                '• Open individual chat conversations',
                '• Send text messages',
                '• See typing indicators (animated)',
                '• View message timestamps and status',
                '• Test message bubbles and UI',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              '🔐 Authentication Testing',
              [
                '• Login with any email/password combination',
                '• Register new account with form validation',
                '• Test social login buttons (mock)',
                '• Try forgot password functionality',
                '• Test form validation and error messages',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              '🎬 Video Features Testing',
              [
                '• Upload videos using the upload screen',
                '• Play videos with quality selection',
                '• View video details and metadata',
                '• Test video controls and playback',
                '• Try different video formats (mock)',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              '🛡️ Moderation Testing (Admin)',
              [
                '• Navigate to moderation screen',
                '• Review reported content',
                '• Take moderation actions (approve/reject/delete)',
                '• Test report functionality on posts',
                '• View moderation queue and statistics',
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 14),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Important Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• All data shown is mock data generated for testing',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '• No real API connections are active',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '• Changes will reset when the app is restarted',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '• All social interactions are simulated',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Testing Tips',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• Try different user interactions to test the UI',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '• Test both light and dark themes',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '• Rotate device to test responsive design',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '• Test with different screen sizes',
              style: TextStyle(fontSize: 14),
            ),
            const Text(
              '• Check console logs for mock data generation',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
