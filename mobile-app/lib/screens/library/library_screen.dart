import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/library_item_model.dart';
import '../../core/models/library_navigation.dart';
import '../../core/models/library_section_model.dart';
import '../../core/services/library_service.dart';
import '../../l10n/app_localizations.dart';
import 'movies_screen.dart';

final librarySectionsProvider =
    FutureProvider<List<LibrarySectionModel>>((ref) async {
  return LibraryService().fetchSections();
});

final libraryItemsProvider = FutureProvider.family<List<LibraryItemModel>,
    LibraryItemsRequest>((ref, request) async {
  return LibraryService().fetchItems(request);
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sectionsAsync = ref.watch(librarySectionsProvider);

    return sectionsAsync.when(
      data: (sections) {
        final tabs = <Tab>[
          Tab(text: l10n.movies),
          ...sections.map((section) => Tab(text: section.displayLabel)),
        ];

        final tabViews = <Widget>[
          const MoviesScreen(),
          ...sections.map(
            (section) => LibrarySectionTab(
              section: section,
            ),
          ),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.library),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: l10n.search,
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () => context.push('/main/search?tab=Library'),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/main/library/add'),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
              bottom: TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.6),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                isScrollable: true,
                tabs: tabs,
              ),
            ),
            body: TabBarView(children: tabViews),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(l10n.library),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: Text(l10n.library),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Failed to load library sections',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(librarySectionsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LibrarySectionTab extends StatelessWidget {
  const LibrarySectionTab({super.key, required this.section});

  final LibrarySectionModel section;

  @override
  Widget build(BuildContext context) {
    return LibraryItemsView(
      section: section.section,
      folderTitle: section.displayName,
    );
  }
}

class LibraryItemsView extends ConsumerStatefulWidget {
  const LibraryItemsView({
    super.key,
    required this.section,
    this.parentId,
    this.folderTitle,
  });

  final String section;
  final String? parentId;
  final String? folderTitle;

  @override
  ConsumerState<LibraryItemsView> createState() => _LibraryItemsViewState();
}

class _LibraryItemsViewState extends ConsumerState<LibraryItemsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final request = LibraryItemsRequest(
      section: widget.section,
      parentId: widget.parentId,
      includeStreams: false,
    );
    final itemsAsync = ref.watch(libraryItemsProvider(request));

    return itemsAsync.when(
      data: (items) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(libraryItemsProvider(request));
            await ref.read(libraryItemsProvider(request).future);
          },
          child: items.isEmpty
              ? _buildEmptyState(context)
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return LibraryContentCard(
                      item: item,
                      onTap: () => _handleItemTap(context, item, items),
                    );
                  },
                ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error, request),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.video_library_outlined, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          'No items found in ${widget.folderTitle ?? widget.section}',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Text(
          'If you recently imported content, try refreshing.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildErrorState(
      BuildContext context, Object error, LibraryItemsRequest request) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 48, color: Colors.orangeAccent),
          const SizedBox(height: 12),
          Text(
            'Unable to load ${widget.folderTitle ?? widget.section}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.invalidate(libraryItemsProvider(request)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _handleItemTap(
    BuildContext context,
    LibraryItemModel item,
    List<LibraryItemModel> siblings,
  ) {
    final section = widget.section;
    final folderTitle = widget.folderTitle;

    if (item.isFolder) {
      context.push(
        '/main/library/section/${Uri.encodeComponent(section)}/folder',
        extra: LibraryFolderArgs(
          section: section,
          parentId: item.id,
          title: item.displayTitle,
        ),
      );
      return;
    }

    if (_isImage(item)) {
      _openImages(context, section, folderTitle, item, siblings);
      return;
    }

    if (_isAudio(item)) {
      _openAudio(context, section, folderTitle, item, siblings);
      return;
    }

    if (_isVideo(item)) {
      _openVideo(context, section, folderTitle, item, siblings);
      return;
    }

    _openDocument(context, section, folderTitle, item);
  }

  bool _isImage(LibraryItemModel item) {
    final content = item.contentType.toLowerCase();
    final mime = item.mimeType?.toLowerCase() ?? '';
    return content == 'image' ||
        mime.startsWith('image/') ||
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].any(
          (ext) => item.filePath?.toLowerCase().endsWith(ext) ?? false,
        );
  }

  bool _isAudio(LibraryItemModel item) {
    final content = item.contentType.toLowerCase();
    final mime = item.mimeType?.toLowerCase() ?? '';
    return content == 'audio' ||
        mime.startsWith('audio/') ||
        ['mp3', 'aac', 'wav', 'm4a', 'flac'].any(
          (ext) => item.filePath?.toLowerCase().endsWith(ext) ?? false,
        );
  }

  bool _isVideo(LibraryItemModel item) {
    final content = item.contentType.toLowerCase();
    final mime = item.mimeType?.toLowerCase() ?? '';
    return content == 'video' ||
        mime.startsWith('video/') ||
        ['mp4', 'mkv', 'mov', 'webm'].any(
          (ext) => item.filePath?.toLowerCase().endsWith(ext) ?? false,
        );
  }

  Future<void> _openImages(
    BuildContext context,
    String section,
    String? folderTitle,
    LibraryItemModel tapped,
    List<LibraryItemModel> siblings,
  ) async {
    final images = siblings.where(_isImage).toList();
    try {
      final detailedImages = await _loadItemsWithProgress(images);
      if (!mounted) return;

      final initialId = tapped.id;
      final initialIndex =
          detailedImages.indexWhere((element) => element.id == initialId);

      context.push(
        '/main/library/section/${Uri.encodeComponent(section)}/image-viewer',
        extra: LibraryImageViewerArgs(
          section: section,
          images: detailedImages,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          folderTitle: folderTitle,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load images: $error'),
        ),
      );
    }
  }

  Future<void> _openAudio(
    BuildContext context,
    String section,
    String? folderTitle,
    LibraryItemModel tapped,
    List<LibraryItemModel> siblings,
  ) async {
    final tracks = siblings.where(_isAudio).toList();
    try {
      final detailedTracks = await _loadItemsWithProgress(tracks);
      if (!mounted) return;

      final initialId = tapped.id;
      final initialIndex =
          detailedTracks.indexWhere((element) => element.id == initialId);

      context.push(
        '/main/library/section/${Uri.encodeComponent(section)}/audio-player',
        extra: LibraryAudioPlayerArgs(
          section: section,
          tracks: detailedTracks,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          folderTitle: folderTitle,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load audio files: $error'),
        ),
      );
    }
  }

  Future<void> _openVideo(
    BuildContext context,
    String section,
    String? folderTitle,
    LibraryItemModel tapped,
    List<LibraryItemModel> siblings,
  ) async {
    final videos = siblings.where(_isVideo).toList();
    try {
      final detailedVideos = await _loadItemsWithProgress(videos);
      if (!mounted) return;

      final initialId = tapped.id;
      final initialIndex =
          detailedVideos.indexWhere((element) => element.id == initialId);

      context.push(
        '/main/library/section/${Uri.encodeComponent(section)}/video-player',
        extra: LibraryVideoPlayerArgs(
          section: section,
          videos: detailedVideos,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          folderTitle: folderTitle,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load videos: $error'),
        ),
      );
    }
  }

  Future<void> _openDocument(
    BuildContext context,
    String section,
    String? folderTitle,
    LibraryItemModel tapped,
  ) async {
    try {
      final detailed = await _loadItemsWithProgress([tapped]);
      if (!mounted) return;
      final item = detailed.isNotEmpty ? detailed.first : tapped;

      context.push(
        '/main/library/section/${Uri.encodeComponent(section)}/document',
        extra: LibraryDocumentArgs(
          section: section,
          item: item,
          folderTitle: folderTitle,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load file: $error'),
        ),
      );
    }
  }

  Future<List<LibraryItemModel>> _loadItemsWithProgress(
      List<LibraryItemModel> items) async {
    if (items.isEmpty) {
      return [];
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
    final service = LibraryService();
    final List<LibraryItemModel> detailedItems = [];

    for (final item in items) {
      final detailed =
          await service.fetchItemById(item.id, includeStreams: true);
      detailedItems.add(detailed ?? item);
    }

    return detailedItems;
  } finally {
    if (navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
  }
  }
}

class LibraryContentCard extends StatelessWidget {
  const LibraryContentCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final LibraryItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isFolder
                                ? Icons.folder_open
                                : _iconForContentType(item),
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.isFolder
                                ? 'folder'
                                : item.contentType.isNotEmpty
                                    ? item.contentType
                                    : 'file',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!item.isFolder &&
                      item.mimeType != null &&
                      item.mimeType!.isNotEmpty)
                    Text(
                      item.mimeType!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: Icon(
        item.isFolder ? Icons.folder : Icons.insert_drive_file,
        size: 36,
        color: Colors.grey[600],
      ),
    );
  }

  IconData _iconForContentType(LibraryItemModel item) {
    final content = item.contentType.toLowerCase();
    if (content == 'image') return Icons.image;
    if (content == 'audio') return Icons.audiotrack;
    if (content == 'video') return Icons.play_circle_fill;
    if (content == 'document' || content == 'pdf') {
      return Icons.description;
    }
    return Icons.insert_drive_file;
  }
}
