import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/movie_model.dart';
import 'api_service.dart';

class MovieService {
  final ApiService _apiService = ApiService();

  // Get movies with filters
  Future<List<MovieModel>> getMovies({
    int page = 1,
    int limit = 20,
    String? contentType,
    String? genre,
    String? lgbtqType,
    String? search,
  }) async {
    try {
      // Capitalize first letter of genre to match TMDb data format
      String? formattedGenre;
      if (genre != null && genre.isNotEmpty) {
        formattedGenre = genre[0].toUpperCase() + genre.substring(1);
      }

      final response = await _apiService.getMovies(
        page: page,
        limit: limit,
        contentType: contentType,
        genre: formattedGenre,
        lgbtqType: lgbtqType,
        search: search,
      );

      if (response['success'] == true && response['data'] != null) {
        final moviesData = response['data'] as List;
        return moviesData.map((movieData) {
          return MovieModel.fromJson(movieData as Map<String, dynamic>);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error getting movies: $e');
      print('Error details: ${e.toString()}');
      return [];
    }
  }

  // Get movie by ID
  Future<MovieModel?> getMovieById(String movieId) async {
    try {
      final response = await _apiService.getMovieById(movieId);

      if (response['success'] == true && response['data'] != null) {
        return MovieModel.fromJson(response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting movie by ID: $e');
      return null;
    }
  }

  // Get episode stream URL
  Future<String?> getEpisodeStreamUrl(String movieId, String episodeId) async {
    try {
      final response =
          await _apiService.getEpisodeStreamUrl(movieId, episodeId);

      if (response['success'] == true && response['data'] != null) {
        return response['data']['streamUrl'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting episode stream URL: $e');
      return null;
    }
  }

  // Get subtitle stream URL
  Future<String?> getSubtitleStreamUrl(
      String movieId, String episodeId, String subtitleId) async {
    try {
      print('📝 Fetching subtitle stream URL...');
      print('   Movie ID: $movieId');
      print('   Episode ID: $episodeId');
      print('   Subtitle ID: $subtitleId');

      final response = await _apiService.getSubtitleStreamUrl(
          movieId, episodeId, subtitleId);

      if (response['success'] == true && response['data'] != null) {
        final streamUrl = response['data']['streamUrl'] as String?;
        print('✅ Subtitle stream URL: $streamUrl');
        return streamUrl;
      }
      print('❌ No stream URL in response');
      return null;
    } catch (e) {
      print('❌ Error getting subtitle stream URL: $e');
      return null;
    }
  }

  // Get available filter options
  Future<MovieFilterOptions> getFilterOptions() async {
    try {
      final response = await _apiService.getMovieFilterOptions();

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        return MovieFilterOptions(
          genres: List<String>.from(data['genres'] ?? []),
          lgbtqTypes: List<String>.from(data['lgbtqTypes'] ?? []),
          contentTypes: List<String>.from(data['contentTypes'] ?? []),
        );
      }
      return MovieFilterOptions(genres: [], lgbtqTypes: [], contentTypes: []);
    } catch (e) {
      print('Error getting filter options: $e');
      return MovieFilterOptions(genres: [], lgbtqTypes: [], contentTypes: []);
    }
  }
}

// Movie filter options class
class MovieFilterOptions {
  final List<String> genres;
  final List<String> lgbtqTypes;
  final List<String> contentTypes;

  MovieFilterOptions({
    required this.genres,
    required this.lgbtqTypes,
    required this.contentTypes,
  });
}

// Provider
final movieServiceProvider = Provider<MovieService>((ref) {
  return MovieService();
});

// Movie filter parameters class
class MovieFilterParams {
  final int page;
  final int limit;
  final String? contentType;
  final String? genre;
  final String? lgbtqType;

  const MovieFilterParams({
    this.page = 1,
    this.limit = 20,
    this.contentType,
    this.genre,
    this.lgbtqType,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MovieFilterParams &&
        other.page == page &&
        other.limit == limit &&
        other.contentType == contentType &&
        other.genre == genre &&
        other.lgbtqType == lgbtqType;
  }

  @override
  int get hashCode {
    return page.hashCode ^
        limit.hashCode ^
        (contentType?.hashCode ?? 0) ^
        (genre?.hashCode ?? 0) ^
        (lgbtqType?.hashCode ?? 0);
  }
}

// Movie list provider with filters
final movieListProvider =
    FutureProvider.family<List<MovieModel>, MovieFilterParams>(
  (ref, params) async {
    final movieService = ref.watch(movieServiceProvider);
    return await movieService.getMovies(
      page: params.page,
      limit: params.limit,
      contentType: params.contentType,
      genre: params.genre,
      lgbtqType: params.lgbtqType,
    );
  },
);

// Movie detail provider
final movieDetailProvider = FutureProvider.family<MovieModel?, String>(
  (ref, movieId) async {
    final movieService = ref.watch(movieServiceProvider);
    return await movieService.getMovieById(movieId);
  },
);

// Movie filter options provider
final movieFilterOptionsProvider = FutureProvider<MovieFilterOptions>(
  (ref) async {
    final movieService = ref.watch(movieServiceProvider);
    return await movieService.getFilterOptions();
  },
);
