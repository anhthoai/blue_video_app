import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/movie_service.dart';

class AddMovieMethodScreen extends ConsumerStatefulWidget {
  final String? selectedType;
  final String title;
  final String? imdbId;
  final String? tmdbId;
  final String? tvdbId;

  const AddMovieMethodScreen({
    super.key,
    required this.title,
    this.selectedType,
    this.imdbId,
    this.tmdbId,
    this.tvdbId,
  });

  @override
  ConsumerState<AddMovieMethodScreen> createState() =>
      _AddMovieMethodScreenState();
}

class _AddMovieMethodScreenState extends ConsumerState<AddMovieMethodScreen> {
  bool _isImporting = false;

  Future<void> _handleImport() async {
    final imdbId = widget.imdbId?.trim();
    final tmdbId = widget.tmdbId?.trim();

    if ((imdbId == null || imdbId.isEmpty) &&
        (tmdbId == null || tmdbId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide either an IMDb or TMDb ID to import.'),
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final movieService = ref.read(movieServiceProvider);
      final result = await movieService.importMovieByIdentifiers(
        identifiers: [
          if (imdbId != null && imdbId.isNotEmpty) imdbId,
          if (tmdbId != null && tmdbId.isNotEmpty) tmdbId,
        ],
        preferredType: widget.selectedType,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully imported "${result.movie?.title ?? widget.title}"'),
          ),
        );
        if (result.movie != null) {
          context.go('/main/library/movie/${result.movie!.id}');
        } else {
          context.pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to import movie.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing movie: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _navigateToManual() {
    final uri = Uri(
      path: '/main/library/add/manual',
      queryParameters: {
        if (widget.selectedType != null) 'type': widget.selectedType!,
        'title': widget.title,
        if (widget.imdbId?.isNotEmpty ?? false) 'imdbId': widget.imdbId!,
        if (widget.tmdbId?.isNotEmpty ?? false) 'tmdbId': widget.tmdbId!,
        if (widget.tvdbId?.isNotEmpty ?? false) 'tvdbId': widget.tvdbId!,
      },
    );

    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add "${widget.title}"'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How would you like to add this ${widget.selectedType == 'TV_SERIES' ? 'series' : 'movie'}?',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 24),
              _buildImportCard(),
              const SizedBox(height: 16),
              _buildManualCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildSummaryRow('Title', widget.title),
            _buildSummaryRow('Type',
                widget.selectedType == 'TV_SERIES' ? 'TV Series' : 'Movie'),
            _buildSummaryRow(
                'IMDb ID',
                widget.imdbId?.isNotEmpty == true
                    ? widget.imdbId!
                    : 'Not provided'),
            _buildSummaryRow(
                'TMDb ID',
                widget.tmdbId?.isNotEmpty == true
                    ? widget.tmdbId!
                    : 'Not provided'),
            _buildSummaryRow(
                'TVDb ID',
                widget.tvdbId?.isNotEmpty == true
                    ? widget.tvdbId!
                    : 'Not provided'),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import from External IDs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Automatically fetch movie details from IMDb or TMDb using the provided IDs.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _handleImport,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_download_outlined),
                label: Text(
                    _isImporting ? 'Importing...' : 'Import Automatically'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Entry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter all movie details manually, including alternative titles, release date, runtime, and more.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _navigateToManual,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Enter Details Manually'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                  color: Colors.grey[700], fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
