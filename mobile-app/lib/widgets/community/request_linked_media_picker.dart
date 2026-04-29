import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/library_item_model.dart';
import '../../core/models/library_navigation.dart';
import '../../core/services/library_service.dart';
import '../../models/community_hub_models.dart';

Future<RequestLinkedMediaSelection?> showRequestLinkedMediaPicker(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showModalBottomSheet<RequestLinkedMediaSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: _RequestLinkedMediaPickerSheet(initialQuery: initialQuery),
      );
    },
  );
}

class RequestLinkedMediaSelection {
  final CommunityLinkedMedia media;
  final String searchQuery;

  const RequestLinkedMediaSelection({
    required this.media,
    required this.searchQuery,
  });
}

CommunityLinkedMedia buildCommunityLinkedMediaFromLibraryItem(
  LibraryItemModel item,
) {
  final extension = _normalizedExtension(
    item.extension ?? item.filePath ?? item.fileUrl,
  );

  return CommunityLinkedMedia(
    sourceType: 'libraryItem',
    previewKind: _previewKindForLibraryItem(item),
    itemId: item.id,
    section: item.section,
    title: item.displayTitle,
    subtitle: item.description,
    contentType: item.contentType,
    thumbnailUrl: item.imageUrl,
    streamUrl: _cleanString(item.streamUrl),
    fileUrl: _cleanString(item.fileUrl),
    mimeType: _cleanString(item.mimeType),
    extension: extension,
  );
}

CommunityLinkedMedia buildCommunityLinkedMediaFromExternalUrl(
  String url, {
  String? title,
}) {
  final normalizedUrl = url.trim();
  final extension = _normalizedExtension(normalizedUrl);

  return CommunityLinkedMedia(
    sourceType: 'externalLink',
    previewKind: _previewKindForExtension(extension),
    title: _cleanString(title),
    externalUrl: normalizedUrl,
    extension: extension,
  );
}

Future<bool> openCommunityLinkedMedia(
  BuildContext context,
  CommunityLinkedMedia linkedMedia,
) async {
  if (!linkedMedia.isLibraryItem ||
      linkedMedia.itemId == null ||
      linkedMedia.itemId!.trim().isEmpty) {
    return false;
  }

  final libraryService = LibraryService();

  try {
    final detailed = await libraryService.fetchItemById(
      linkedMedia.itemId!,
      includeStreams: true,
    );
    if (!context.mounted || detailed == null) {
      return false;
    }

    return _openLibraryItem(context, detailed, fallbackSection: linkedMedia.section);
  } catch (_) {
    if (!context.mounted) {
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open this catalog item right now.')),
    );
    return false;
  }
}

IconData communityLinkedMediaPreviewIcon(CommunityLinkedMedia linkedMedia) {
  switch (linkedMedia.previewKind) {
    case CommunityLinkedMediaPreviewKind.image:
      return Icons.image_rounded;
    case CommunityLinkedMediaPreviewKind.video:
      return Icons.play_circle_outline_rounded;
    case CommunityLinkedMediaPreviewKind.audio:
      return Icons.audiotrack_rounded;
    case CommunityLinkedMediaPreviewKind.file:
      return Icons.insert_drive_file_rounded;
    case CommunityLinkedMediaPreviewKind.external:
      return Icons.link_rounded;
  }
}

String communityLinkedMediaPreviewLabel(CommunityLinkedMedia linkedMedia) {
  switch (linkedMedia.previewKind) {
    case CommunityLinkedMediaPreviewKind.image:
      return 'Image';
    case CommunityLinkedMediaPreviewKind.video:
      return 'Video';
    case CommunityLinkedMediaPreviewKind.audio:
      return 'Audio';
    case CommunityLinkedMediaPreviewKind.file:
      return 'File';
    case CommunityLinkedMediaPreviewKind.external:
      return 'Link';
  }
}

String communityLinkedMediaSourceLabel(CommunityLinkedMedia linkedMedia) {
  if (linkedMedia.isLibraryItem) {
    final section = linkedMedia.section?.trim();
    if (section != null && section.isNotEmpty) {
      return _humanizeToken(section);
    }
    return 'App library';
  }

  final externalUrl = linkedMedia.externalUrl?.trim();
  if (externalUrl != null && externalUrl.isNotEmpty) {
    final host = Uri.tryParse(externalUrl)?.host;
    if (host != null && host.isNotEmpty) {
      return host;
    }
  }

  return 'External source';
}

class _RequestLinkedMediaPickerSheet extends StatefulWidget {
  final String initialQuery;

  const _RequestLinkedMediaPickerSheet({
    required this.initialQuery,
  });

  @override
  State<_RequestLinkedMediaPickerSheet> createState() =>
      _RequestLinkedMediaPickerSheetState();
}

class _RequestLinkedMediaPickerSheetState
    extends State<_RequestLinkedMediaPickerSheet> {
  final LibraryService _libraryService = LibraryService();
  late final TextEditingController _queryController;
  List<LibraryItemModel> _results = const <LibraryItemModel>[];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) {
      _search();
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DFED),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Search app library',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick an existing image, video, audio file, or document and attach it to this request.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Search the library',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _isLoading ? null : _search,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(92, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                    ),
                  ),
                )
              else if (_queryController.text.trim().isEmpty)
                _buildIdleState()
              else if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_results.isEmpty)
                _buildEmptyState()
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return _buildResultTile(item);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 48,
              color: Color(0xFFB4BFCE),
            ),
            SizedBox(height: 12),
            Text(
              'Search to find a matching catalog item.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Color(0xFFB4BFCE),
            ),
            SizedBox(height: 12),
            Text(
              'No matching library items found.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(LibraryItemModel item) {
    final linkedMedia = buildCommunityLinkedMediaFromLibraryItem(item);
    final thumbnailUrl = linkedMedia.previewImageUrl;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop(
          RequestLinkedMediaSelection(
            media: linkedMedia,
            searchQuery: _queryController.text.trim(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCE5F6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: thumbnailUrl != null
                  ? Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Icon(
                          communityLinkedMediaPreviewIcon(linkedMedia),
                          color: const Color(0xFF2D67F6),
                        );
                      },
                    )
                  : Icon(
                      communityLinkedMediaPreviewIcon(linkedMedia),
                      color: const Color(0xFF2D67F6),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PickerChip(label: communityLinkedMediaPreviewLabel(linkedMedia)),
                      _PickerChip(label: communityLinkedMediaSourceLabel(linkedMedia)),
                    ],
                  ),
                  if (item.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <LibraryItemModel>[];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sections = await _libraryService.fetchSections();
      final sectionResults = await Future.wait(
        sections.map((section) async {
          try {
            return await _libraryService.fetchItems(
              LibraryItemsRequest(
                section: section.section,
                search: query,
                limit: 40,
                includeStreams: false,
              ),
            );
          } catch (_) {
            return const <LibraryItemModel>[];
          }
        }),
      );

      final deduped = <String, LibraryItemModel>{};
      for (final item in sectionResults.expand((items) => items)) {
        if (item.isFolder) {
          continue;
        }
        deduped[item.id] = item;
      }

      final results = deduped.values.toList(growable: false)
        ..sort((left, right) => left.displayTitle.compareTo(right.displayTitle));

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (searchError) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = 'Library search failed. Try again.';
      });
    }
  }
}

class _PickerChip extends StatelessWidget {
  final String label;

  const _PickerChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

bool _isImage(LibraryItemModel item) {
  final content = item.contentType.toLowerCase();
  final mime = item.mimeType?.toLowerCase() ?? '';
  return content == 'image' ||
      mime.startsWith('image/') ||
      _imageExtensions.any(
        (ext) => item.filePath?.toLowerCase().endsWith(ext) ?? false,
      );
}

bool _isAudio(LibraryItemModel item) {
  final content = item.contentType.toLowerCase();
  final mime = item.mimeType?.toLowerCase() ?? '';
  return content == 'audio' ||
      mime.startsWith('audio/') ||
      _audioExtensions.any(
        (ext) => item.filePath?.toLowerCase().endsWith(ext) ?? false,
      );
}

bool _isVideo(LibraryItemModel item) {
  final content = item.contentType.toLowerCase();
  final mime = item.mimeType?.toLowerCase() ?? '';
  return content == 'video' ||
      mime.startsWith('video/') ||
      _videoExtensions.any(
        (ext) => item.filePath?.toLowerCase().endsWith(ext) ?? false,
      );
}

bool _isEbook(LibraryItemModel item) {
  final extension = item.filePath?.split('.').last.toLowerCase() ??
      item.fileUrl?.split('.').last.toLowerCase() ??
      '';
  final mime = item.mimeType?.toLowerCase() ?? '';
  return extension == 'epub' ||
      extension == 'mobi' ||
      extension == 'azw3' ||
      extension == 'fb2' ||
      extension == 'txt' ||
      mime.contains('epub') ||
      mime.contains('mobi') ||
      mime.contains('azw') ||
      mime.contains('kindle') ||
      mime.contains('fb2') ||
      mime.contains('text/plain');
}

bool _isPdf(LibraryItemModel item) {
  final extension = item.filePath?.split('.').last.toLowerCase() ??
      item.fileUrl?.split('.').last.toLowerCase() ??
      '';
  final mime = item.mimeType?.toLowerCase() ?? '';
  return extension == 'pdf' || mime.contains('pdf');
}

CommunityLinkedMediaPreviewKind _previewKindForLibraryItem(
  LibraryItemModel item,
) {
  if (_isImage(item)) {
    return CommunityLinkedMediaPreviewKind.image;
  }
  if (_isVideo(item)) {
    return CommunityLinkedMediaPreviewKind.video;
  }
  if (_isAudio(item)) {
    return CommunityLinkedMediaPreviewKind.audio;
  }
  return CommunityLinkedMediaPreviewKind.file;
}

CommunityLinkedMediaPreviewKind _previewKindForExtension(String? extension) {
  final normalized = extension?.toLowerCase() ?? '';
  if (_imageExtensions.contains(normalized)) {
    return CommunityLinkedMediaPreviewKind.image;
  }
  if (_videoExtensions.contains(normalized)) {
    return CommunityLinkedMediaPreviewKind.video;
  }
  if (_audioExtensions.contains(normalized)) {
    return CommunityLinkedMediaPreviewKind.audio;
  }
  if (_documentExtensions.contains(normalized)) {
    return CommunityLinkedMediaPreviewKind.file;
  }
  return CommunityLinkedMediaPreviewKind.external;
}

Future<bool> _openLibraryItem(
  BuildContext context,
  LibraryItemModel item, {
  String? fallbackSection,
}) async {
  final section = item.section.isNotEmpty
      ? item.section
      : (fallbackSection?.trim().isNotEmpty == true ? fallbackSection!.trim() : '');
  if (section.isEmpty) {
    return false;
  }

  if (item.isFolder) {
    context.push(
      '/main/library/section/${Uri.encodeComponent(section)}/folder',
      extra: LibraryFolderArgs(
        section: section,
        parentId: item.id,
        title: item.displayTitle,
      ),
    );
    return true;
  }

  if (_isImage(item)) {
    context.push(
      '/main/library/section/${Uri.encodeComponent(section)}/image-viewer',
      extra: LibraryImageViewerArgs(
        section: section,
        images: [item],
        initialIndex: 0,
        folderTitle: null,
      ),
    );
    return true;
  }

  if (_isAudio(item)) {
    context.push(
      '/main/library/section/${Uri.encodeComponent(section)}/audio-player',
      extra: LibraryAudioPlayerArgs(
        section: section,
        tracks: [item],
        initialIndex: 0,
        folderTitle: null,
      ),
    );
    return true;
  }

  if (_isVideo(item)) {
    context.push(
      '/main/library/section/${Uri.encodeComponent(section)}/video-player',
      extra: LibraryVideoPlayerArgs(
        section: section,
        videos: [item],
        subtitles: const [],
        initialIndex: 0,
        folderTitle: null,
      ),
    );
    return true;
  }

  if (_isPdf(item) || _isEbook(item)) {
    context.push(
      '/main/library/section/${Uri.encodeComponent(section)}/ebook',
      extra: LibraryEbookReaderArgs(
        section: section,
        item: item,
        folderTitle: null,
      ),
    );
    return true;
  }

  context.push(
    '/main/library/section/${Uri.encodeComponent(section)}/document',
    extra: LibraryDocumentArgs(
      section: section,
      item: item,
      folderTitle: null,
    ),
  );
  return true;
}

String? _cleanString(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String? _normalizedExtension(String? source) {
  final trimmed = source?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final parsedPath = Uri.tryParse(trimmed)?.path ?? trimmed;
  final dotIndex = parsedPath.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex >= parsedPath.length - 1) {
    return null;
  }

  return parsedPath.substring(dotIndex + 1).toLowerCase();
}

String _humanizeToken(String value) {
  return value
      .split(RegExp(r'[_\-\s]+'))
      .where((segment) => segment.isNotEmpty)
      .map((segment) {
        final lower = segment.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

const Set<String> _imageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
  'heic',
};

const Set<String> _videoExtensions = <String>{
  'mp4',
  'mov',
  'm4v',
  'webm',
  'mkv',
  'avi',
  'wmv',
  'flv',
};

const Set<String> _audioExtensions = <String>{
  'mp3',
  'aac',
  'wav',
  'm4a',
  'flac',
  'ogg',
};

const Set<String> _documentExtensions = <String>{
  'pdf',
  'doc',
  'docx',
  'txt',
  'epub',
  'mobi',
  'azw3',
  'fb2',
  'ppt',
  'pptx',
  'xls',
  'xlsx',
};