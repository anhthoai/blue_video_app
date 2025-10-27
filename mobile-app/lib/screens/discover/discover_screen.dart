import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../models/category_model.dart';
import '../../models/video_model.dart';
import '../../widgets/common/presigned_image.dart';
import '../../l10n/app_localizations.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final ScrollController _trendingScrollController = ScrollController();

  List<VideoModel> _trendingVideos = [];
  List<CategoryModel> _categories = [];
  bool _isLoadingTrending = false;
  bool _isLoadingMoreTrending = false;
  bool _isLoadingCategories = false;
  int _trendingPage = 1;
  bool _hasMoreTrending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTrendingVideos();
    _loadCategories();
    _trendingScrollController.addListener(_onTrendingScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _trendingScrollController.dispose();
    super.dispose();
  }

  void _onTrendingScroll() {
    if (_trendingScrollController.position.pixels >=
            _trendingScrollController.position.maxScrollExtent - 500 &&
        !_isLoadingMoreTrending &&
        _hasMoreTrending) {
      _loadMoreTrendingVideos();
    }
  }

  Future<void> _loadTrendingVideos() async {
    setState(() {
      _isLoadingTrending = true;
      _trendingPage = 1;
      _trendingVideos = [];
      _hasMoreTrending = true;
    });

    try {
      print('🔍 Loading trending videos page $_trendingPage...');
      final videos =
          await _apiService.getTrendingVideos(page: _trendingPage, limit: 20);
      print('✅ Received ${videos.length} trending videos');
      setState(() {
        _trendingVideos =
            videos.map((json) => VideoModel.fromJson(json)).toList();
        _hasMoreTrending = videos.length >= 20;
      });
      print('✅ Parsed ${_trendingVideos.length} video models');
    } catch (e) {
      print('❌ Error loading trending videos: $e');
    } finally {
      setState(() {
        _isLoadingTrending = false;
      });
    }
  }

  Future<void> _loadMoreTrendingVideos() async {
    if (_isLoadingMoreTrending || !_hasMoreTrending) return;

    setState(() {
      _isLoadingMoreTrending = true;
      _trendingPage++;
    });

    try {
      final videos =
          await _apiService.getTrendingVideos(page: _trendingPage, limit: 20);
      setState(() {
        _trendingVideos
            .addAll(videos.map((json) => VideoModel.fromJson(json)).toList());
        _hasMoreTrending = videos.length >= 20;
      });
    } catch (e) {
      print('Error loading more trending videos: $e');
      setState(() {
        _trendingPage--; // Revert page increment on error
      });
    } finally {
      setState(() {
        _isLoadingMoreTrending = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories =
            categories.map((json) => CategoryModel.fromJson(json)).toList();
      });
    } catch (e) {
      print('Error loading categories: $e');
    } finally {
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.discover),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.push('/main/search');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorWeight: 3,
          tabs: [
            Tab(text: l10n.trending),
            Tab(text: l10n.category),
            Tab(text: l10n.live),
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
    final l10n = AppLocalizations.of(context);

    if (_isLoadingTrending) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trendingVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noTrendingVideos,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _trendingScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _trendingVideos.length,
            itemBuilder: (context, index) {
              final video = _trendingVideos[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        if (video.calculatedThumbnailUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: PresignedImage(
                              imageUrl: video.calculatedThumbnailUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF757575),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  title: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${video.formattedViewCount} • ${video.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'add_to_playlist') {
                            _showAddToPlaylistDialog(video.id, video.title);
                          }
                        },
                        itemBuilder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return [
                            PopupMenuItem(
                              value: 'add_to_playlist',
                              child: Row(
                                children: [
                                  const Icon(Icons.playlist_add, size: 20),
                                  const SizedBox(width: 8),
                                  Text(l10n.addToPlaylist),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                      const Icon(Icons.trending_up, color: Colors.orange),
                    ],
                  ),
                  onTap: () {
                    context.push('/main/video/${video.id}/player');
                  },
                ),
              );
            },
          ),
        ),
        if (_isLoadingMoreTrending)
          Container(
            padding: const EdgeInsets.all(16),
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    final l10n = AppLocalizations.of(context);

    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noCategories,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Icon mapping for categories
    final iconMap = {
      'Members': Icons.people,
      'Music': Icons.music_note,
      'Gaming': Icons.games,
      'Sports': Icons.sports_soccer,
      'Education': Icons.school,
      'Comedy': Icons.emoji_emotions,
      'Technology': Icons.computer,
    };

    final colorMap = {
      'Members': Colors.deepOrange,
      'Music': Colors.purple,
      'Gaming': Colors.green,
      'Sports': Colors.blue,
      'Education': Colors.orange,
      'Comedy': Colors.yellow,
      'Technology': Colors.cyan,
    };

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final icon = iconMap[category.categoryName] ?? Icons.category;
        final color = colorMap[category.categoryName] ?? Colors.grey;

        return Card(
          child: InkWell(
            onTap: () {
              context.push('/main/category/${category.id}', extra: category);
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Category thumbnail or icon
                if (category.categoryThumb != null)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PresignedImage(
                        imageUrl: category.categoryThumb!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: Icon(icon, size: 48, color: color),
                      ),
                    ),
                  )
                else
                  Icon(icon, size: 48, color: color),
                const SizedBox(height: 12),
                Text(
                  category.categoryName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (category.videoCount > 0) ...[
                  const SizedBox(height: 4),
                  Builder(builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      '${category.videoCount} ${l10n.videos}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    );
                  }),
                ],
                // Show subcategories count if any
                if (category.children.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Builder(builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return Text(
                      '${category.children.length} ${l10n.subcategories}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveTab() {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.live_tv, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            l10n.liveStreaming,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.comingSoon,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              l10n.liveStreamingDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(String videoId, String videoTitle) async {
    final l10n = AppLocalizations.of(context);

    try {
      // Fetch user's playlists
      final response = await _apiService.getUserPlaylists(page: 1, limit: 100);

      if (response['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(response['message'] ?? l10n.errorLoadingPlaylists)),
          );
        }
        return;
      }

      final playlists = response['data'] as List<dynamic>;

      if (!mounted) return;

      if (playlists.isEmpty) {
        // Show dialog to create a new playlist
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.noPlaylistsFound),
            content: Text(l10n.createPlaylistPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showCreatePlaylistDialog(context);
                },
                child: Text(l10n.createPlaylist),
              ),
            ],
          ),
        );
        return;
      }

      // Show playlist selection dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.addToPlaylist),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length + 1,
              itemBuilder: (context, index) {
                final l10n = AppLocalizations.of(context);

                if (index == playlists.length) {
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(l10n.createNewPlaylist),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlaylistDialog(context);
                    },
                  );
                }

                final playlist = playlists[index] as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(playlist['name'] ?? l10n.untitled),
                  subtitle:
                      Text('${playlist['videoCount'] ?? 0} ${l10n.videos}'),
                  trailing: playlist['isPublic'] == false
                      ? const Icon(Icons.lock, size: 16)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await _addVideoToPlaylist(
                        videoId, playlist['id'], playlist['name']);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorLoadingPlaylists}: $e')),
        );
      }
    }
  }

  Future<void> _addVideoToPlaylist(
      String videoId, String playlistId, String playlistName) async {
    final l10n = AppLocalizations.of(context);

    try {
      final response = await _apiService.addVideoToPlaylist(
        playlistId: playlistId,
        videoId: videoId,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.addedToPlaylist} "$playlistName"')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(response['message'] ?? l10n.failedToAddVideo)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final dialogL10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(dialogL10n.createNewPlaylist),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: dialogL10n.playlistName,
                    hintText: dialogL10n.enterPlaylistName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: dialogL10n.descriptionOptional,
                    hintText: dialogL10n.enterPlaylistDescription,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isPublic,
                      onChanged: (value) {
                        setState(() {
                          isPublic = value ?? true;
                        });
                      },
                    ),
                    Text(dialogL10n.publicPlaylist),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(dialogL10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(dialogL10n.pleaseEnterPlaylistName)),
                    );
                    return;
                  }

                  try {
                    final response = await _apiService.createPlaylist(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      isPublic: isPublic,
                    );

                    if (response['success'] == true) {
                      Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(dialogL10n.playlistCreatedSuccessfully)),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(response['message'] ??
                                  dialogL10n.failedToCreatePlaylist)),
                        );
                      }
                    }
                  } catch (e) {
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${dialogL10n.error}: $e')),
                      );
                    }
                  }
                },
                child: Text(dialogL10n.create),
              ),
            ],
          );
        },
      ),
    );
  }
}
