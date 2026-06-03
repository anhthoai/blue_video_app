import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/library_navigation.dart';
import '../../core/models/library_item_model.dart';
import '../../core/services/library_download_service.dart';

class LibraryImageViewerScreen extends StatefulWidget {
  const LibraryImageViewerScreen({super.key, required this.args});

  final LibraryImageViewerArgs args;

  @override
  State<LibraryImageViewerScreen> createState() =>
      _LibraryImageViewerScreenState();
}

class _LibraryImageViewerScreenState extends State<LibraryImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  List<LibraryItemModel> get images => widget.args.images;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.args.initialIndex.clamp(0, images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(
          widget.args.folderTitle ?? images[_currentIndex].displayTitle,
        ),
        actions: [
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download),
            onPressed: () {
              final image = images[_currentIndex];
              LibraryDownloadService.instance.downloadLibraryItem(
                context,
                item: image,
                suggestedName: image.displayTitle,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              physics: images.length > 1
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final image = images[index];
                final url =
                    image.streamUrl ?? image.imageUrl ?? image.fileUrl;
                // Thumbnail from /__ulozthumb__/ is tiny (~30 KB) and served
                // from CDN edge — loads in ~0.3 s. Show it immediately while
                // the full-resolution image (streamUrl) fetches in background.
                final thumbUrl = image.thumbnailUrl ?? image.coverUrl;

                if (url == null || url.isEmpty) {
                  return const Center(
                    child: Text(
                      'Image unavailable',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return InteractiveViewer(
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      // Show thumbnail as placeholder while full image loads.
                      placeholder: (context, _) {
                        if (thumbUrl != null && thumbUrl.isNotEmpty) {
                          return CachedNetworkImage(
                            imageUrl: thumbUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorWidget: (_, __, ___) => const Center(
                        child: Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  images[_currentIndex].displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentIndex + 1} / ${images.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

