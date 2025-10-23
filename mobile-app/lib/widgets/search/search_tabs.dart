import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_tab_content.dart';

class SearchTabs extends ConsumerStatefulWidget {
  final String query;

  const SearchTabs({
    super.key,
    required this.query,
  });

  @override
  ConsumerState<SearchTabs> createState() => _SearchTabsState();
}

class _SearchTabsState extends ConsumerState<SearchTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Video',
    'Library',
    'Posts',
    'User',
    'Comics',
    'Gallery',
    'Novel',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey[600],
            tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              return SearchTabContent(
                query: widget.query,
                contentType: tab,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
