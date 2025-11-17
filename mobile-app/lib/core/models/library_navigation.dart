import 'package:flutter/foundation.dart';

import 'library_item_model.dart';

@immutable
class LibraryFolderArgs {
  const LibraryFolderArgs({
    required this.section,
    required this.parentId,
    this.title,
  });

  final String section;
  final String parentId;
  final String? title;
}

@immutable
class LibraryImageViewerArgs {
  const LibraryImageViewerArgs({
    required this.section,
    required this.images,
    required this.initialIndex,
    this.folderTitle,
  });

  final String section;
  final List<LibraryItemModel> images;
  final int initialIndex;
  final String? folderTitle;
}

@immutable
class LibraryAudioPlayerArgs {
  const LibraryAudioPlayerArgs({
    required this.section,
    required this.tracks,
    required this.initialIndex,
    this.folderTitle,
  });

  final String section;
  final List<LibraryItemModel> tracks;
  final int initialIndex;
  final String? folderTitle;
}

@immutable
class LibraryVideoPlayerArgs {
  const LibraryVideoPlayerArgs({
    required this.section,
    required this.videos,
    required this.initialIndex,
    this.folderTitle,
    this.subtitles = const [],
  });

  final String section;
  final List<LibraryItemModel> videos;
  final int initialIndex;
  final String? folderTitle;
  final List<LibraryItemModel> subtitles;
}

@immutable
class LibraryDocumentArgs {
  const LibraryDocumentArgs({
    required this.section,
    required this.item,
    this.folderTitle,
  });

  final String section;
  final LibraryItemModel item;
  final String? folderTitle;
}

@immutable
class LibraryEbookReaderArgs {
  const LibraryEbookReaderArgs({
    required this.section,
    required this.item,
    this.folderTitle,
  });

  final String section;
  final LibraryItemModel item;
  final String? folderTitle;
}
