import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

final libraryItemsProvider =
    FutureProvider.family<List<LibraryItemModel>, LibraryItemsRequest>(
        (ref, request) async {
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
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.redAccent),
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

  final ScrollController _scrollController = ScrollController();
  List<LibraryItemModel> _items = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Trigger at 70% to prefetch before user reaches the end
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.7 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreItems();
    }
  }

  Future<void> _loadItems() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isInitialLoad = true;
      _currentPage = 1;
      _items = [];
      _hasMore = true;
      _error = null;
    });

    try {
      final request = LibraryItemsRequest(
        section: widget.section,
        parentId: widget.parentId,
        includeStreams: false,
        page: 1,
        limit: 40,
      );
      final items = await LibraryService().fetchItems(request);

      if (mounted) {
        setState(() {
          _items = items;
          _hasMore = items.length >= 40;
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final request = LibraryItemsRequest(
        section: widget.section,
        parentId: widget.parentId,
        includeStreams: false,
        page: _currentPage + 1,
        limit: 40,
      );
      final items = await LibraryService().fetchItems(request);

      if (mounted) {
        setState(() {
          _currentPage++;
          _items.addAll(items);
          _hasMore = items.length >= 40;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(context, _error!);
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: _items.isEmpty
          ? _buildEmptyState(context)
          : Stack(
              children: [
                GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final item = _items[index];
                    final showDownload =
                        !item.isFolder && (_isDocument(item) || _isEbook(item));
                    return LibraryContentCard(
                      item: item,
                      onTap: () => _handleItemTap(context, item, _items),
                      onDownload: showDownload
                          ? () => _handleDownloadFromCard(context, item)
                          : null,
                    );
                  },
                ),
              ],
            ),
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

  Widget _buildErrorState(BuildContext context, Object error) {
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
            onPressed: _loadItems,
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

    if (_isEbook(item)) {
      _openEbook(context, section, folderTitle, item);
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

  bool _isEbook(LibraryItemModel item) {
    final content = item.contentType.toLowerCase();
    final mime = item.mimeType?.toLowerCase() ?? '';
    final extension = (item.extension ?? item.filePath ?? item.fileUrl ?? '')
        .split('.')
        .last
        .toLowerCase();

    const ebookExtensions = {
      'epub',
      'mobi',
      'azw',
      'azw3',
      'fb2',
      'txt',
      'pdf',
    };

    return content == 'ebook' ||
        ebookExtensions.contains(extension) ||
        mime.contains('epub') ||
        mime.contains('mobi') ||
        mime.contains('fb2') ||
        mime.contains('pdf') ||
        mime.contains('text/plain');
  }

  bool _isDocument(LibraryItemModel item) {
    if (item.isFolder) return false;
    if (_isImage(item)) return false;
    if (_isAudio(item)) return false;
    if (_isVideo(item)) return false;
    if (_isEbook(item)) return false;
    if (_isSubtitle(item)) return false;
    return true;
  }

  bool _isSubtitle(LibraryItemModel item) {
    final content = item.contentType.toLowerCase();
    final mime = item.mimeType?.toLowerCase() ?? '';
    final extension =
        (item.extension ?? item.filePath?.split('/').last ?? item.fileUrl ?? '')
            .split('.')
            .last
            .toLowerCase();
    return content.contains('subtitle') ||
        content.contains('caption') ||
        mime.startsWith('text/') ||
        ['srt', 'vtt', 'ass', 'ssa', 'sub', 'sbv', 'dfxp'].contains(extension);
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
    final subtitleCandidates = siblings.where(_isSubtitle).toList();
    try {
      final combined = <LibraryItemModel>[
        ...videos,
        ...subtitleCandidates,
      ];
      final detailedCombined = await _loadItemsWithProgress(combined);
      if (!mounted) return;

      final detailedMap = {
        for (final item in detailedCombined) item.id: item,
      };

      final detailedVideos = videos
          .map((video) => detailedMap[video.id] ?? video)
          .toList(growable: false);
      final detailedSubtitles = subtitleCandidates
          .map((subtitle) => detailedMap[subtitle.id] ?? subtitle)
          .toList(growable: false);

      final initialId = tapped.id;
      final initialIndex =
          detailedVideos.indexWhere((element) => element.id == initialId);

      context.push(
        '/main/library/section/${Uri.encodeComponent(section)}/video-player',
        extra: LibraryVideoPlayerArgs(
          section: section,
          videos: detailedVideos,
          subtitles: detailedSubtitles,
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

  Future<void> _openEbook(
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
        '/main/library/section/${Uri.encodeComponent(section)}/ebook',
        extra: LibraryEbookReaderArgs(
          section: section,
          item: item,
          folderTitle: folderTitle,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load ebook: $error'),
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

  Future<void> _handleDownloadFromCard(
    BuildContext context,
    LibraryItemModel item,
  ) async {
    final downloadUrl = item.streamUrl ?? item.fileUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No download URL available.')),
      );
      return;
    }

    try {
      final detailed = await _loadItemsWithProgress([item]);
      if (!mounted) return;
      final detailedItem = detailed.isNotEmpty ? detailed.first : item;
      final finalUrl = detailedItem.streamUrl ?? detailedItem.fileUrl;

      if (finalUrl == null || finalUrl.isEmpty) {
        throw Exception('No download URL available.');
      }

      final uri = Uri.tryParse(finalUrl);
      if (uri == null) {
        throw Exception('Invalid download URL.');
      }

      if (uri.scheme.startsWith('http')) {
        await _ensureStoragePermission();
        await _downloadToDevice(context, uri, item.displayTitle);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Direct download not available for this file.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  Future<void> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return;

    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      return;
    }

    if (manageStatus.isPermanentlyDenied) {
      throw Exception(
          'Storage permission denied. Please enable access in settings.');
    }

    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      return;
    }

    status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception('Storage permission denied.');
    }
  }

  Future<void> _downloadToDevice(
    BuildContext context,
    Uri url,
    String suggestedName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final dio = Dio();
    final progressNotifier = ValueNotifier<double?>(null);
    final cancelToken = CancelToken();

    final downloadsDir = await _resolveDownloadDirectory();
    final sanitized = _sanitizeFileName(suggestedName);
    final targetPath = await _uniqueFilePath(downloadsDir, sanitized);

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadProgressDialog(
        progressNotifier: progressNotifier,
        cancelToken: cancelToken,
      ),
    );

    try {
      await dio.download(
        url.toString(),
        targetPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            progressNotifier.value = null;
          } else {
            progressNotifier.value = received / total;
          }
        },
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved to ${p.basename(targetPath)}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              try {
                final result = await OpenFile.open(targetPath);
                if (result.type != ResultType.done) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to open file: ${result.message}'),
                    ),
                  );
                }
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to open file: $error'),
                  ),
                );
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Download cancelled.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Download failed: ${error.message}')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    } finally {
      progressNotifier.dispose();
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (publicDownloads.existsSync()) {
        return publicDownloads;
      }
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      return downloadsDir;
    }
    return await getTemporaryDirectory();
  }

  Future<String> _uniqueFilePath(Directory directory, String fileName) async {
    final base = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var candidate = p.join(directory.path, fileName);
    var counter = 1;

    while (File(candidate).existsSync()) {
      candidate = p.join(directory.path, '$base($counter)$extension');
      counter += 1;
    }
    return candidate;
  }

  String _sanitizeFileName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      return 'document';
    }
    return sanitized;
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog({
    required this.progressNotifier,
    required this.cancelToken,
  });

  final ValueNotifier<double?> progressNotifier;
  final CancelToken cancelToken;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progressNotifier,
        builder: (context, progress, _) {
          final percent =
              progress != null ? (progress * 100).clamp(0, 100) : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Text(
                percent == null
                    ? 'Downloading...'
                    : '${percent.toStringAsFixed(0)}%',
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (!cancelToken.isCancelled) {
              cancelToken.cancel('cancelled');
            }
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class LibraryContentCard extends StatelessWidget {
  const LibraryContentCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDownload,
  });

  final LibraryItemModel item;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                  if (onDownload != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            onDownload?.call();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.download,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    if (content == 'subtitle') return Icons.subtitles;
    if (content == 'document' || content == 'pdf') {
      return Icons.description;
    }
    return Icons.insert_drive_file;
  }
}
