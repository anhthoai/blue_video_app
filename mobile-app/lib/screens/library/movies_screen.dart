import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/movie_model.dart';
import '../../core/services/movie_service.dart';

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
    final filterOptionsAsync = ref.watch(movieFilterOptionsProvider);

    return Column(
      children: [
        // Dynamic filters based on available data
        filterOptionsAsync.when(
          data: (filterOptions) => Column(
            children: [
              // Content Type Filter
              if (filterOptions.contentTypes.isNotEmpty)
                _buildFilterBar(
                  title: 'Type',
                  options: [
                    {'id': null, 'name': l10n.all},
                    ...filterOptions.contentTypes.map((type) {
                      return {
                        'id': type,
                        'name': _getLocalizedContentType(type, l10n),
                      };
                    }).toList(),
                  ],
                  selectedId: _selectedContentType,
                  onSelect: (id) {
                    if (id != _selectedContentType) {
                      setState(() {
                        _selectedContentType = id;
                      });
                    }
                  },
                ),

              // Genre Filter
              if (filterOptions.genres.isNotEmpty)
                _buildFilterBar(
                  title: 'Genre',
                  options: [
                    {'id': null, 'name': l10n.all},
                    ...filterOptions.genres.map((genre) {
                      return {
                        'id': genre.toLowerCase(),
                        'name': genre, // Use the actual genre name from TMDb
                      };
                    }).toList(),
                  ],
                  selectedId: _selectedGenre,
                  onSelect: (id) {
                    if (id != _selectedGenre) {
                      setState(() {
                        _selectedGenre = id;
                      });
                    }
                  },
                ),

              // LGBTQ+ Type Filter
              if (filterOptions.lgbtqTypes.isNotEmpty)
                _buildFilterBar(
                  title: 'LGBTQ+',
                  options: [
                    {'id': null, 'name': l10n.all},
                    ...filterOptions.lgbtqTypes.map((type) {
                      return {
                        'id': type.toLowerCase(),
                        'name': _getLocalizedLgbtqType(type, l10n),
                      };
                    }).toList(),
                  ],
                  selectedId: _selectedLgbtqType,
                  onSelect: (id) {
                    if (id != _selectedLgbtqType) {
                      setState(() {
                        _selectedLgbtqType = id;
                      });
                    }
                  },
                ),
            ],
          ),
          loading: () => const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const SizedBox.shrink(),
        ),

        // Movies Grid
        Expanded(
          child: _buildMoviesGrid(l10n),
        ),
      ],
    );
  }

  // Get localized content type name
  String _getLocalizedContentType(String type, AppLocalizations l10n) {
    switch (type) {
      case 'MOVIE':
        return l10n.movie;
      case 'TV_SERIES':
        return l10n.tvSeries;
      case 'SHORT':
        return l10n.short;
      default:
        return type;
    }
  }

  // Get localized LGBTQ+ type name
  String _getLocalizedLgbtqType(String type, AppLocalizations l10n) {
    switch (type.toLowerCase()) {
      case 'lesbian':
        return l10n.lesbian;
      case 'gay':
        return l10n.gay;
      case 'bisexual':
        return l10n.bisexual;
      case 'transgender':
        return l10n.transgender;
      case 'queer':
        return l10n.queer;
      default:
        return type;
    }
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
    final filterParams = MovieFilterParams(
      contentType: _selectedContentType,
      genre: _selectedGenre,
      lgbtqType: _selectedLgbtqType,
    );

    final moviesAsync = ref.watch(movieListProvider(filterParams));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(movieListProvider(filterParams));
        // Wait a bit for the provider to refresh
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: moviesAsync.when(
        data: (movies) {
          if (movies.isEmpty) {
            return ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
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
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

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
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${l10n.errorLoadingData}: $error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(movieListProvider(filterParams));
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCard(MovieModel movie) {
    return GestureDetector(
      onTap: () {
        // Navigate to movie detail screen
        context.push('/main/library/movie/${movie.id}');
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
