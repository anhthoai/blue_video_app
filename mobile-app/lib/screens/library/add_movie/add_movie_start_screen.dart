import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/movie_service.dart';
import '../../../models/movie_model.dart';

class AddMovieStartScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final String? initialTitle;
  final String? initialImdbId;
  final String? initialTmdbId;
  final String? initialTvdbId;

  const AddMovieStartScreen({
    super.key,
    this.initialType,
    this.initialTitle,
    this.initialImdbId,
    this.initialTmdbId,
    this.initialTvdbId,
  });

  @override
  ConsumerState<AddMovieStartScreen> createState() =>
      _AddMovieStartScreenState();
}

class _AddMovieStartScreenState extends ConsumerState<AddMovieStartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _imdbController = TextEditingController();
  final _tmdbController = TextEditingController();
  final _tvdbController = TextEditingController();

  String _selectedType = 'MOVIE';
  bool _isChecking = false;
  bool _hasChecked = false;
  List<MovieModel> _existingTitles = [];
  String? _errorMessage;
  bool _isSearchingTmdb = false;
  bool _tmdbSearched = false;
  String? _tmdbError;
  TmdbSearchResult? _tmdbSuggestion;
  bool _isImportingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType?.toUpperCase() == 'TV_SERIES'
        ? 'TV_SERIES'
        : 'MOVIE';
    _titleController.text = widget.initialTitle ?? '';
    _imdbController.text = widget.initialImdbId ?? '';
    _tmdbController.text = widget.initialTmdbId ?? '';
    _tvdbController.text = widget.initialTvdbId ?? '';
  }

  Widget _buildTmdbSuggestionSection() {
    if (_isSearchingTmdb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_tmdbError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          _tmdbError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_tmdbSuggestion != null) {
      return _buildTmdbSuggestionCard(_tmdbSuggestion!);
    }

    if (_tmdbSearched) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'No matches found on TMDb.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTmdbSuggestionCard(TmdbSearchResult suggestion) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              height: 130,
              child: suggestion.posterUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        suggestion.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.movie),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.movie),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (suggestion.originalTitle != null &&
                      suggestion.originalTitle != suggestion.title)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Original: ${suggestion.originalTitle}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (suggestion.releaseDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Release: ${suggestion.releaseDate}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (suggestion.voteAverage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            suggestion.voteAverage!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  if (suggestion.overview != null &&
                      suggestion.overview!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        suggestion.overview!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isImportingSuggestion ? null : _importTmdbSuggestion,
                      icon: _isImportingSuggestion
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(
                        _isImportingSuggestion
                            ? 'Importing...'
                            : 'Import from TMDb',
                      ),
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

  @override
  void dispose() {
    _titleController.dispose();
    _imdbController.dispose();
    _tmdbController.dispose();
    _tvdbController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingTitles() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final hasTitle = _titleController.text.trim().isNotEmpty;
      final hasImdb = _imdbController.text.trim().isNotEmpty;
      final hasTmdb = _tmdbController.text.trim().isNotEmpty;
      final hasTvdb = _tvdbController.text.trim().isNotEmpty;

      if (!hasTitle && !hasImdb && !hasTmdb && !hasTvdb) {
        setState(() {
          _isChecking = false;
          _hasChecked = false;
          _errorMessage =
              'Please enter a title or at least one external ID to search.';
        });
        return;
      }

      final movieService = ref.read(movieServiceProvider);
      List<MovieModel> movies = [];

      if (hasTitle) {
        movies = await movieService.getMovies(
          limit: 20,
          search: _titleController.text.trim(),
          contentType: _selectedType,
        );
      } else {
        final searchResults = await movieService.findMoviesByIdentifiers(
          imdbId: hasImdb ? _imdbController.text.trim() : null,
          tmdbId: hasTmdb ? _tmdbController.text.trim() : null,
          tvdbId: hasTvdb ? _tvdbController.text.trim() : null,
          contentType: _selectedType,
        );
        movies = searchResults;
      }

      setState(() {
        _existingTitles = movies;
        _hasChecked = true;
      });

      if (mounted) {
        if (movies.isEmpty && hasTitle) {
          await _fetchTmdbSuggestion(_titleController.text.trim());
        } else {
          setState(() {
            _tmdbSuggestion = null;
            _tmdbError = null;
            _tmdbSearched = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to search existing titles: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _openMethodSelection() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final queryParams = <String, String>{
      'type': _selectedType,
    };

    if (_titleController.text.trim().isEmpty &&
        _imdbController.text.trim().isEmpty &&
        _tmdbController.text.trim().isEmpty &&
        _tvdbController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please enter a title or at least one external ID to continue.'),
        ),
      );
      return;
    }

    if (_titleController.text.trim().isNotEmpty) {
      queryParams['title'] = _titleController.text.trim();
    }
    if (_imdbController.text.trim().isNotEmpty) {
      queryParams['imdbId'] = _imdbController.text.trim();
    }
    if (_tmdbController.text.trim().isNotEmpty) {
      queryParams['tmdbId'] = _tmdbController.text.trim();
    }
    if (_tvdbController.text.trim().isNotEmpty) {
      queryParams['tvdbId'] = _tvdbController.text.trim();
    }

    final uri =
        Uri(path: '/main/library/add/manual', queryParameters: queryParams);
    context.push(uri.toString());
  }

  Future<void> _fetchTmdbSuggestion(String query) async {
    setState(() {
      _isSearchingTmdb = true;
      _tmdbError = null;
      _tmdbSuggestion = null;
      _tmdbSearched = false;
    });

    try {
      final movieService = ref.read(movieServiceProvider);
      final results = await movieService.searchTmdbTitles(
        query: query,
        contentType: _selectedType,
      );

      if (!mounted) return;

      setState(() {
        _tmdbSuggestion = results.isNotEmpty ? results.first : null;
        _tmdbSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tmdbError = 'Failed to search TMDb: $e';
        _tmdbSearched = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingTmdb = false;
        });
      }
    }
  }

  Future<void> _importTmdbSuggestion() async {
    final suggestion = _tmdbSuggestion;
    if (suggestion == null || suggestion.tmdbId == null) return;

    setState(() {
      _isImportingSuggestion = true;
    });

    try {
      final movieService = ref.read(movieServiceProvider);
      final result = await movieService.importMovieByIdentifiers(
        identifiers: [suggestion.tmdbId!],
        preferredType: _selectedType,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _tmdbSuggestion = null;
        });

        if (_titleController.text.trim().isEmpty) {
          _titleController.text = suggestion.title;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Movie imported successfully'),
          ),
        );

        if (result.movie != null) {
          context.push('/main/library/movie/${result.movie!.id}');
        }

        // Refresh existing titles from database so the new import shows up
        await _checkExistingTitles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Failed to import movie'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import movie: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportingSuggestion = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Movie'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title (optional)',
                      helperText:
                          'Provide a title to search existing entries. You can leave this blank if using external IDs.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildExternalIdFields(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkExistingTitles,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isChecking ? 'Checking...' : 'Next'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_hasChecked) _buildResultsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          isSelected: [
            _selectedType == 'MOVIE',
            _selectedType == 'TV_SERIES',
          ],
          onPressed: (index) {
            setState(() {
              _selectedType = index == 0 ? 'MOVIE' : 'TV_SERIES';
            });
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Movie'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('TV Series'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExternalIdFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'External IDs (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _imdbController,
                decoration: const InputDecoration(
                  labelText: 'IMDb ID',
                  hintText: 'e.g., tt1234567',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _tmdbController,
                decoration: const InputDecoration(
                  labelText: 'TMDb ID',
                  hintText: 'e.g., 123456',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _tvdbController,
          decoration: const InputDecoration(
            labelText: 'TVDb ID',
            hintText: 'Optional',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final title = _titleController.text.trim();
    final hasResults = _existingTitles.isNotEmpty;

    if (title.isEmpty && !hasResults) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No existing titles were found using the provided identifiers.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTmdbSuggestionSection(),
          const SizedBox(height: 12),
          Text(
            'You may continue to add a new title using the button below.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openMethodSelection,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Add New Movie'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasResults
              ? 'Found ${_existingTitles.length} existing title(s).'
              : 'No existing titles were found that match the provided information.',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (hasResults)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Language')),
                  DataColumn(label: Text('Country')),
                  DataColumn(label: Text('Genre')),
                  DataColumn(label: Text('IMDb')),
                  DataColumn(label: Text('TMDb')),
                ],
                rows: _existingTitles
                    .map(
                      (movie) => DataRow(
                        cells: [
                          DataCell(GestureDetector(
                            onTap: () {
                              context.push('/main/library/movie/${movie.id}');
                            },
                            child: Text(
                              movie.title,
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          )),
                          DataCell(Text(movie.languages?.join(', ') ?? '-')),
                          DataCell(Text(movie.countries?.join(', ') ?? '-')),
                          DataCell(Text(movie.genres?.join(', ') ?? '-')),
                          DataCell(Text(movie.imdbId ?? '-')),
                          DataCell(Text(movie.tmdbId ?? '-')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (!hasResults) ...[
          _buildTmdbSuggestionSection(),
          const SizedBox(height: 12),
        ],
        Text(
          hasResults
              ? 'If you are sure the title "$title" does not exist in our database, you may add a new entry below.'
              : 'You may add "$title" to our database by clicking the button below.',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openMethodSelection,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add New Movie'),
          ),
        ),
      ],
    );
  }
}
