import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/search/search_tabs.dart';
import '../../widgets/search/search_bar.dart' as custom;
import '../../l10n/app_localizations.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialTab;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialTab,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _currentQuery = widget.initialQuery!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _currentQuery = query;
    });
  }

  void _onClear() {
    setState(() {
      _searchController.clear();
      _currentQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(l10n.search),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: custom.SearchBar(
              controller: _searchController,
              onSearch: _onSearch,
              onClear: _onClear,
            ),
          ),

          // Search Results with Tabs
          Expanded(
            child: _currentQuery.isEmpty
                ? _buildEmptyState()
                : SearchTabs(
                    query: _currentQuery,
                    initialTab: widget.initialTab,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.searchHint,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
