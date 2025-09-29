import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Navigate to search screen
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Trending'),
            Tab(text: 'Categories'),
            Tab(text: 'Live'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTrendingTab(), _buildCategoriesTab(), _buildLiveTab()],
      ),
    );
  }

  Widget _buildTrendingTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text('${index + 1}'),
            ),
            title: Text('Trending Video ${index + 1}'),
            subtitle: Text('${(index + 1) * 1000}K views • 2h ago'),
            trailing: const Icon(Icons.trending_up, color: Colors.orange),
            onTap: () {
              // Navigate to video detail
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    final categories = [
      {'name': 'Music', 'icon': Icons.music_note, 'color': Colors.purple},
      {'name': 'Gaming', 'icon': Icons.games, 'color': Colors.green},
      {'name': 'Sports', 'icon': Icons.sports, 'color': Colors.blue},
      {'name': 'Education', 'icon': Icons.school, 'color': Colors.orange},
      {'name': 'Comedy', 'icon': Icons.emoji_emotions, 'color': Colors.yellow},
      {'name': 'Technology', 'icon': Icons.computer, 'color': Colors.cyan},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          child: InkWell(
            onTap: () {
              // Navigate to category videos
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category['icon'] as IconData,
                  size: 48,
                  color: category['color'] as Color,
                ),
                const SizedBox(height: 8),
                Text(
                  category['name'] as String,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.person),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.circle,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
              ],
            ),
            title: Text('Live Stream ${index + 1}'),
            subtitle: Text('${index + 1}K viewers • ${index + 1}h ago'),
            trailing: const Icon(Icons.live_tv, color: Colors.red),
            onTap: () {
              // Navigate to live stream
            },
          ),
        );
      },
    );
  }
}
