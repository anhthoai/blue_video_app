import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/movie_model.dart';

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  final ScrollController _scrollController = ScrollController();

  // Filter state
  String? _selectedContentType;
  String? _selectedGenre;
  String? _selectedLgbtqType;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Content Type Filter
        _buildFilterBar(
          title: 'Type',
          options: [
            {'id': null, 'name': l10n.all},
            {'id': 'MOVIE', 'name': l10n.movie},
            {'id': 'TV_SERIES', 'name': l10n.tvSeries},
            {'id': 'SHORT', 'name': l10n.short},
          ],
          selectedId: _selectedContentType,
          onSelect: (id) {
            setState(() {
              _selectedContentType = id;
            });
          },
        ),

        // Genre Filter
        _buildFilterBar(
          title: 'Genre',
          options: [
            {'id': null, 'name': l10n.all},
            {'id': 'drama', 'name': l10n.drama},
            {'id': 'comedy', 'name': l10n.comedy},
            {'id': 'romance', 'name': l10n.romance},
            {'id': 'action', 'name': l10n.action},
            {'id': 'thriller', 'name': l10n.thriller},
            {'id': 'horror', 'name': l10n.horror},
          ],
          selectedId: _selectedGenre,
          onSelect: (id) {
            setState(() {
              _selectedGenre = id;
            });
          },
        ),

        // LGBTQ+ Type Filter
        _buildFilterBar(
          title: 'LGBTQ+',
          options: [
            {'id': null, 'name': l10n.all},
            {'id': 'lesbian', 'name': l10n.lesbian},
            {'id': 'gay', 'name': l10n.gay},
            {'id': 'bisexual', 'name': l10n.bisexual},
            {'id': 'transgender', 'name': l10n.transgender},
            {'id': 'queer', 'name': l10n.queer},
          ],
          selectedId: _selectedLgbtqType,
          onSelect: (id) {
            setState(() {
              _selectedLgbtqType = id;
            });
          },
        ),

        // Movies Grid
        Expanded(
          child: _buildMoviesGrid(l10n),
        ),
      ],
    );
  }

  Widget _buildFilterBar({
    required String title,
    required List<Map<String, String?>> options,
    required String? selectedId,
    required Function(String?) onSelect,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: options.map((option) {
          final id = option['id'];
          final name = option['name']!;
          final isSelected = selectedId == id;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: FilterChip(
              label: Text(name),
              selected: isSelected,
              onSelected: (selected) {
                onSelect(id);
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoviesGrid(AppLocalizations l10n) {
    // TODO: Replace with actual data from API
    // For now, showing placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No movies yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Movies will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Selected filters:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${_selectedContentType ?? "All"}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          Text(
            'Genre: ${_selectedGenre ?? "All"}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          Text(
            'LGBTQ+: ${_selectedLgbtqType ?? "All"}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );

    // When we have data, use this grid:
    /*
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return _buildMovieCard(movie);
      },
    );
    */
  }

  Widget _buildMovieCard(MovieModel movie) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to movie detail screen
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (movie.posterUrl != null)
                    Image.network(
                      movie.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.movie, size: 48),
                        );
                      },
                    )
                  else
                    Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.movie, size: 48),
                    ),

                  // Rating overlay
                  if (movie.voteAverage != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              movie.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Movie info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        movie.releaseYear,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (movie.runtime != null) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          movie.formattedRuntime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
