import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/community_hub_models.dart';
import '../services/community_hub_service.dart';

class CommunityHubState {
  final List<CommunityForum> forums;
  final List<CommunityCreator> creators;
  final List<CommunityRequest> requests;
  final bool isLoading;
  final bool isLoaded;
  final String? errorMessage;

  const CommunityHubState({
    this.forums = const <CommunityForum>[],
    this.creators = const <CommunityCreator>[],
    this.requests = const <CommunityRequest>[],
    this.isLoading = false,
    this.isLoaded = false,
    this.errorMessage,
  });

  List<CommunityForum> get followedForums {
    return forums.where((forum) => forum.isFollowing).toList(growable: false);
  }

  List<CommunityCreator> get followedCreators {
    return creators
        .where((creator) => creator.isFollowing)
        .toList(growable: false);
  }

  CommunityRequest? requestById(String requestId) {
    for (final request in requests) {
      if (request.id == requestId) {
        return request;
      }
    }
    return null;
  }

  CommunityHubState copyWith({
    List<CommunityForum>? forums,
    List<CommunityCreator>? creators,
    List<CommunityRequest>? requests,
    bool? isLoading,
    bool? isLoaded,
    Object? errorMessage = _communityHubErrorSentinel,
  }) {
    return CommunityHubState(
      forums: forums ?? this.forums,
      creators: creators ?? this.creators,
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      isLoaded: isLoaded ?? this.isLoaded,
      errorMessage: errorMessage == _communityHubErrorSentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _communityHubErrorSentinel = Object();

class CommunityHubNotifier extends StateNotifier<CommunityHubState> {
  CommunityHubNotifier(this._service) : super(const CommunityHubState()) {
    load();
  }

  final CommunityHubService _service;

  Future<void> load({bool force = false}) async {
    if (state.isLoading && !force) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final overview = await _service.getOverview();
      state = state.copyWith(
        forums: overview.forums,
        creators: overview.creators,
        requests: overview.requests,
        isLoading: false,
        isLoaded: true,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoaded: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> ensureLoaded() async {
    if (!state.isLoaded && !state.isLoading) {
      await load();
    }
  }

  Future<void> refresh() async {
    await load(force: true);
  }

  Future<List<CommunityForum>> loadForums({String scope = 'all'}) async {
    return _service.getForums(scope: scope);
  }

  Future<CommunityForumDetail> getForumDetail(
    String forumId, {
    String feed = 'recommended',
    int page = 1,
    int limit = 20,
  }) async {
    return _service.getForumDetail(
      forumId,
      feed: feed,
      page: page,
      limit: limit,
    );
  }

  Future<CommunityRequest?> fetchRequest(String requestId) async {
    try {
      final request = await _service.getRequestDetail(requestId);
      _upsertRequest(request);
      return request;
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      return null;
    }
  }

  Future<bool> toggleCreatorFollow(String creatorId) async {
    final creator = _creatorById(creatorId);
    final nextFollowState = await _service.toggleCreatorFollow(
      creatorId,
      isCurrentlyFollowing: creator?.isFollowing ?? false,
    );
    _updateCreatorFollowState(creatorId, nextFollowState);
    return nextFollowState;
  }

  Future<CommunityForum?> toggleForumFollow(String forumId) async {
    final forum = await _service.toggleForumFollow(forumId);
    if (forum != null) {
      _upsertForum(forum);
    }
    return forum;
  }

  Future<void> toggleWantRequest(String requestId) async {
    final request = await _service.toggleWantRequest(requestId);
    _upsertRequest(request);
  }

  Future<void> addSupportCoins(String requestId, int coins) async {
    final request = await _service.addSupportCoins(
      requestId,
      coins: coins,
    );
    _upsertRequest(request);
  }

  Future<String> createRequest({
    required String title,
    required String description,
    required int coins,
    required List<String> keywords,
    String boardLabel = 'Latest',
    List<String>? previewHints,
    List<String> imagePaths = const <String>[],
  }) async {
    final request = await _service.createRequest(
      title: title,
      description: description,
      coins: coins,
      keywords: keywords,
      boardLabel: boardLabel,
      previewHints: previewHints,
      imageFiles: imagePaths.map(File.new).toList(growable: false),
    );
    _upsertRequest(request, insertAtTop: true);
    return request.id;
  }

  Future<String> addSubmission({
    required String requestId,
    required String title,
    required String description,
    required CommunityRequestSubmissionType type,
    String? linkedVideoUrl,
    CommunityLinkedMedia? linkedMedia,
    String? searchKeyword,
    String? filePath,
    File? thumbnailFile,
  }) async {
    final request = await _service.submitRequest(
      requestId: requestId,
      title: title,
      description: description,
      type: type,
      linkedVideoUrl: linkedVideoUrl,
      linkedMedia: linkedMedia,
      searchKeyword: searchKeyword,
      file: filePath != null && filePath.isNotEmpty ? File(filePath) : null,
      thumbnailFile: thumbnailFile,
    );
    _upsertRequest(request);
    return request.submissions.isNotEmpty ? request.submissions.first.id : '';
  }

  Future<void> approveSubmission(String requestId, String submissionId) async {
    final request = await _service.approveSubmission(requestId, submissionId);
    _upsertRequest(request);
  }

  Future<void> toggleSubmissionContributorFollow(
    String requestId,
    String submissionId,
  ) async {
    final request = state.requestById(requestId);
    if (request == null) {
      return;
    }

    for (final submission in request.submissions) {
      if (submission.id == submissionId) {
        await toggleCreatorFollow(submission.contributorId);
        return;
      }
    }
  }

  CommunityCreator? _creatorById(String creatorId) {
    for (final creator in state.creators) {
      if (creator.id == creatorId) {
        return creator;
      }
    }
    return null;
  }

  void _upsertForum(CommunityForum forum) {
    final forums = [...state.forums];
    final index = forums.indexWhere((item) => item.id == forum.id);
    if (index == -1) {
      forums.insert(0, forum);
    } else {
      forums[index] = forum;
    }

    state = state.copyWith(forums: forums);
  }

  void _upsertRequest(CommunityRequest request, {bool insertAtTop = false}) {
    final requests = [...state.requests];
    final index = requests.indexWhere((item) => item.id == request.id);
    if (index == -1) {
      if (insertAtTop) {
        requests.insert(0, request);
      } else {
        requests.add(request);
      }
    } else {
      requests[index] = request;
      if (insertAtTop && index > 0) {
        requests.removeAt(index);
        requests.insert(0, request);
      }
    }

    state = state.copyWith(requests: requests);
  }

  void _updateCreatorFollowState(String creatorId, bool isFollowing) {
    final creators = state.creators.map((creator) {
      if (creator.id != creatorId) {
        return creator;
      }

      return creator.copyWith(isFollowing: isFollowing);
    }).toList(growable: false);

    final requests = state.requests.map((request) {
      return request.copyWith(
        submissions: request.submissions.map((submission) {
          if (submission.contributorId != creatorId) {
            return submission;
          }

          return submission.copyWith(
            isFollowingContributor: isFollowing,
          );
        }).toList(growable: false),
      );
    }).toList(growable: false);

    state = state.copyWith(
      creators: creators,
      requests: requests,
    );
  }
}

final communityHubServiceProvider = Provider<CommunityHubService>((ref) {
  return CommunityHubService();
});

final communityHubProvider =
    StateNotifierProvider<CommunityHubNotifier, CommunityHubState>((ref) {
  return CommunityHubNotifier(ref.read(communityHubServiceProvider));
});
