import 'package:flutter/material.dart';

import '../../core/models/library_navigation.dart';
import '../../core/models/library_item_model.dart';

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
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
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

