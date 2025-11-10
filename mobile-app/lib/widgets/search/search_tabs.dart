import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_tab_content.dart';

class SearchTabs extends ConsumerStatefulWidget {
  final String query;
  final String? initialTab;

  const SearchTabs({
    super.key,
    required this.query,
    this.initialTab,
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
    final initialIndex = _resolveInitialIndex(widget.initialTab);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void didUpdateWidget(covariant SearchTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab &&
        widget.initialTab != null) {
      final newIndex = _resolveInitialIndex(widget.initialTab);
      if (newIndex != _tabController.index && newIndex < _tabs.length) {
        _tabController.animateTo(newIndex);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _resolveInitialIndex(String? initialTab) {
    if (initialTab == null) return 0;
    final index = _tabs.indexWhere(
      (tab) => tab.toLowerCase() == initialTab.toLowerCase(),
    );
    return index >= 0 ? index : 0;
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
