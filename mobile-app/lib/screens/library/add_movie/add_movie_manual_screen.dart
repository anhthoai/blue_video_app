import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/movie_service.dart';

class AddMovieManualScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final String? initialTitle;
  final String? initialImdbId;
  final String? initialTmdbId;
  final String? initialTvdbId;

  const AddMovieManualScreen({
    super.key,
    this.initialType,
    this.initialTitle,
    this.initialImdbId,
    this.initialTmdbId,
    this.initialTvdbId,
  });

  @override
  ConsumerState<AddMovieManualScreen> createState() =>
      _AddMovieManualScreenState();
}

class _AddMovieManualScreenState extends ConsumerState<AddMovieManualScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedType = 'MOVIE';
  DateTime? _releaseDate;

  final _titleController = TextEditingController();
  final _imdbController = TextEditingController();
  final _tmdbController = TextEditingController();
  final _tvdbController = TextEditingController();
  final _plotController = TextEditingController();
  final _runtimeController = TextEditingController();
  final _genresController = TextEditingController();
  final _countriesController = TextEditingController();
  final _languagesController = TextEditingController();
  final _posterUrlController = TextEditingController();
  final _trailerUrlController = TextEditingController();

  final List<AlternativeTitleForm> _alternativeTitles = [];

  bool _isSaving = false;

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

  @override
  void dispose() {
    _titleController.dispose();
    _imdbController.dispose();
    _tmdbController.dispose();
    _tvdbController.dispose();
    _plotController.dispose();
    _runtimeController.dispose();
    _genresController.dispose();
    _countriesController.dispose();
    _languagesController.dispose();
    _posterUrlController.dispose();
    _trailerUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectReleaseDate() async {
    final initialDate = _releaseDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _releaseDate = picked;
      });
    }
  }

  Future<void> _addAlternativeTitle() async {
    final titleController = TextEditingController();
    final countryController = TextEditingController();
    final languageController = TextEditingController();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Alternative Title'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(labelText: 'Country'),
              ),
              TextField(
                controller: languageController,
                decoration: const InputDecoration(labelText: 'Language'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (shouldAdd == true) {
      setState(() {
        _alternativeTitles.add(
          AlternativeTitleForm(
            title: titleController.text.trim(),
            country: countryController.text.trim().isEmpty
                ? null
                : countryController.text.trim(),
            language: languageController.text.trim().isEmpty
                ? null
                : languageController.text.trim(),
          ),
        );
      });
    }
  }

  Future<void> _saveManualMovie() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final movieService = ref.read(movieServiceProvider);

      final response = await movieService.createManualMovie(
        contentType: _selectedType,
        title: _titleController.text.trim(),
        plot: _plotController.text.trim(),
        alternativeTitles: _alternativeTitles
            .map((alt) => alt.toJson())
            .toList(growable: false),
        imdbId: _imdbController.text.trim().isEmpty
            ? null
            : _imdbController.text.trim(),
        tmdbId: _tmdbController.text.trim().isEmpty
            ? null
            : _tmdbController.text.trim(),
        tvdbId: _tvdbController.text.trim().isEmpty
            ? null
            : _tvdbController.text.trim(),
        releaseDate: _releaseDate,
        runtime: _runtimeController.text.trim().isEmpty
            ? null
            : int.tryParse(_runtimeController.text.trim()),
        genres: _splitByComma(_genresController.text),
        countries: _splitByComma(_countriesController.text),
        languages: _splitByComma(_languagesController.text),
        posterUrl: _posterUrlController.text.trim().isEmpty
            ? null
            : _posterUrlController.text.trim(),
        trailerUrl: _trailerUrlController.text.trim().isEmpty
            ? null
            : _trailerUrlController.text.trim(),
      );

      if (!mounted) return;

      if (response.success && response.movie != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Created "${response.movie!.title}" successfully.')),
        );
        context.go('/main/library/movie/${response.movie!.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(response.message ?? 'Failed to create movie.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating movie: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<String> _splitByComma(String input) {
    return input
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Movie Entry'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeSelector(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildAlternativeTitlesSection(),
                const SizedBox(height: 16),
                _buildExternalIdFields(),
                const SizedBox(height: 16),
                _buildReleaseDateField(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _plotController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Plot / Overview',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _runtimeController,
                  decoration: const InputDecoration(
                    labelText: 'Runtime (minutes)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _genresController,
                  decoration: const InputDecoration(
                    labelText: 'Genres (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _countriesController,
                  decoration: const InputDecoration(
                    labelText: 'Countries (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _languagesController,
                  decoration: const InputDecoration(
                    labelText: 'Languages (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _posterUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Poster Image URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _trailerUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Video Trailer URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveManualMovie,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Add Movie'),
                  ),
                ),
              ],
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

  Widget _buildAlternativeTitlesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Alternative Titles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _addAlternativeTitle,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (_alternativeTitles.isEmpty)
          const Text(
            'No alternative titles added yet.',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _alternativeTitles
                .map(
                  (alt) => Chip(
                    label: Text(
                      alt.displayText,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onDeleted: () {
                      setState(() {
                        _alternativeTitles.remove(alt);
                      });
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildExternalIdFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'External IDs',
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
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseDateField() {
    final formatter = DateFormat.yMMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Release Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _selectReleaseDate,
          icon: const Icon(Icons.date_range),
          label: Text(
            _releaseDate == null
                ? 'Select Date'
                : formatter.format(_releaseDate!),
          ),
        ),
      ],
    );
  }
}

class AlternativeTitleForm {
  final String title;
  final String? country;
  final String? language;

  AlternativeTitleForm({
    required this.title,
    this.country,
    this.language,
  });

  String get displayText {
    final parts = [title];
    if (country != null && country!.isNotEmpty) {
      parts.add('($country)');
    }
    if (language != null && language!.isNotEmpty) {
      parts.add('[${language!.toUpperCase()}]');
    }
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (country != null) 'country': country,
      if (language != null) 'language': language,
    };
  }
}
