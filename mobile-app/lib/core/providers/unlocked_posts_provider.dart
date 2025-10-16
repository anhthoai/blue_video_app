import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track unlocked posts in memory
/// This allows the UI to immediately reflect unlock status without refetching from API
class UnlockedPostsNotifier extends StateNotifier<Set<String>> {
  UnlockedPostsNotifier() : super(<String>{});

  /// Mark a post as unlocked
  void unlockPost(String postId) {
    print('🔓 Marking post $postId as unlocked in memory');
    state = {...state, postId};
  }

  /// Check if a post is unlocked
  bool isPostUnlocked(String postId) {
    return state.contains(postId);
  }

  /// Clear all unlocked posts (e.g., on logout)
  void clearAll() {
    state = {};
  }
}

/// Global provider for unlocked posts
final unlockedPostsProvider =
    StateNotifierProvider<UnlockedPostsNotifier, Set<String>>((ref) {
  return UnlockedPostsNotifier();
});
