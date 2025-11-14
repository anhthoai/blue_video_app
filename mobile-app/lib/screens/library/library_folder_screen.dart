import 'package:flutter/material.dart';

import '../../core/models/library_navigation.dart';
import 'library_screen.dart';

class LibraryFolderScreen extends StatelessWidget {
  const LibraryFolderScreen({super.key, required this.args});

  final LibraryFolderArgs args;

  @override
  Widget build(BuildContext context) {
    if (args.parentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(args.title ?? 'Folder'),
        ),
        body: const Center(
          child: Text('Folder information is missing.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(args.title ?? 'Folder'),
      ),
      body: LibraryItemsView(
        section: args.section,
        parentId: args.parentId,
        folderTitle: args.title,
      ),
    );
  }
}

