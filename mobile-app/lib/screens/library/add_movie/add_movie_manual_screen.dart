import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/movie_service.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController();
    final countryController = TextEditingController();
    final languageController = TextEditingController();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${l10n.addLabel} ${l10n.originalTitlesLabel}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: countryController,
                decoration: InputDecoration(labelText: l10n.countryLabel),
              ),
              TextField(
                controller: languageController,
                decoration: InputDecoration(labelText: l10n.languageLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: Text(l10n.addLabel),
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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('"${response.movie!.title}" ${l10n.movieImportedSuccessfully}')),
        );
        context.go('/main/library/movie/${response.movie!.id}');
      } else {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? l10n.failedCreateMovie)),
        );
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.failedCreateMovie}: $e')),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manualMovieEntry),
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
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.titleRequired;
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
                  decoration: InputDecoration(
                    labelText: l10n.plotOverview,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _runtimeController,
                  decoration: InputDecoration(
                    labelText: l10n.runtimeMinutes,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _genresController,
                  decoration: InputDecoration(
                    labelText: l10n.genresCommaSeparated,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _countriesController,
                  decoration: InputDecoration(
                    labelText: l10n.countriesCommaSeparated,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _languagesController,
                  decoration: InputDecoration(
                    labelText: l10n.languagesCommaSeparated,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _posterUrlController,
                  decoration: InputDecoration(
                    labelText: l10n.posterImageUrl,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _trailerUrlController,
                  decoration: InputDecoration(
                    labelText: l10n.videoTrailerUrl,
                    border: const OutlineInputBorder(),
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
                    label: Text(_isSaving ? 'Saving...' : l10n.addMovie),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.typeLabel,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.movie),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.tvSeriesLabel),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlternativeTitlesSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.alternativeTitles,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _addAlternativeTitle,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).addLabel),
            ),
          ],
        ),
        if (_alternativeTitles.isEmpty)
          Text(
            l10n.noAlternativeTitlesYet,
            style: const TextStyle(color: Colors.grey),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.externalIdsOptional,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        Text(
          'Release Date',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
