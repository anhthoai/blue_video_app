import 'dart:io';

import '../../models/community_hub_models.dart';
import 'api_service.dart';

class CommunityHubService {
  final ApiService _apiService = ApiService();

  Future<CommunityHubOverview> getOverview() async {
    final response = await _apiService.getCommunityHubOverview();
    return CommunityHubOverview.fromJson(_requireDataMap(response));
  }

  Future<List<CommunityForum>> getForums({String scope = 'all'}) async {
    final response = await _apiService.getCommunityForums(scope: scope);
    return _requireDataList(response)
        .map(CommunityForum.fromJson)
        .toList(growable: false);
  }

  Future<CommunityForum?> toggleForumFollow(String forumId) async {
    final response = await _apiService.toggleCommunityForumFollow(forumId);
    final data = response['data'];
    if (data is Map) {
      return CommunityForum.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<CommunityForumDetail> getForumDetail(
    String forumId, {
    String feed = 'recommended',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiService.getCommunityForumDetail(
      forumId,
      feed: feed,
      page: page,
      limit: limit,
    );
    return CommunityForumDetail.fromJson(_requireDataMap(response));
  }

  Future<List<CommunityCreator>> getCreatorRanking() async {
    final response = await _apiService.getCommunityCreatorRanking();
    return _requireDataList(response)
        .map(CommunityCreator.fromJson)
        .toList(growable: false);
  }

  Future<bool> toggleCreatorFollow(
    String creatorId, {
    required bool isCurrentlyFollowing,
  }) async {
    final response = isCurrentlyFollowing
        ? await _apiService.unfollowUser(creatorId)
        : await _apiService.followUser(creatorId);

    if (response['following'] is bool) {
      return response['following'] == true;
    }

    throw Exception(response['message'] ?? 'Failed to update follow state');
  }

  Future<List<CommunityRequest>> getRequests() async {
    final response = await _apiService.getCommunityRequests();
    return _requireDataList(response)
        .map(CommunityRequest.fromJson)
        .toList(growable: false);
  }

  Future<CommunityRequest> createRequest({
    required String title,
    required String description,
    required int coins,
    required List<String> keywords,
    String boardLabel = 'Latest',
    List<String>? previewHints,
    List<File>? imageFiles,
  }) async {
    final response = await _apiService.createCommunityRequest(
      title: title,
      description: description,
      coins: coins,
      keywords: keywords,
      boardLabel: boardLabel,
      previewHints: previewHints,
      imageFiles: imageFiles,
    );
    return CommunityRequest.fromJson(_requireDataMap(response));
  }

  Future<CommunityRequest> getRequestDetail(String requestId) async {
    final response = await _apiService.getCommunityRequestDetail(requestId);
    return CommunityRequest.fromJson(_requireDataMap(response));
  }

  Future<CommunityRequest> toggleWantRequest(String requestId) async {
    final response = await _apiService.toggleCommunityRequestWant(requestId);
    return CommunityRequest.fromJson(_requireDataMap(response));
  }

  Future<CommunityRequest> addSupportCoins(
    String requestId, {
    required int coins,
  }) async {
    final response = await _apiService.supportCommunityRequest(
      requestId,
      coins: coins,
    );
    return CommunityRequest.fromJson(_requireDataMap(response));
  }

  Future<CommunityRequest> submitRequest({
    required String requestId,
    required String title,
    required String description,
    required CommunityRequestSubmissionType type,
    String? linkedVideoUrl,
    CommunityLinkedMedia? linkedMedia,
    String? searchKeyword,
    File? file,
    File? thumbnailFile,
  }) async {
    final response = await _apiService.submitCommunityRequest(
      requestId: requestId,
      title: title,
      description: description,
      type: type == CommunityRequestSubmissionType.fileUpload
          ? 'fileUpload'
          : 'linkedVideo',
      linkedVideoUrl: linkedVideoUrl,
      linkedMedia: linkedMedia,
      searchKeyword: searchKeyword,
      file: file,
      thumbnailFile: thumbnailFile,
    );
    return CommunityRequest.fromJson(_requireDataMap(response));
  }

  Future<CommunityRequest> approveSubmission(
    String requestId,
    String submissionId,
  ) async {
    final response = await _apiService.approveCommunityRequestSubmission(
      requestId,
      submissionId,
    );
    return CommunityRequest.fromJson(_requireDataMap(response));
  }

  Map<String, dynamic> _requireDataMap(Map<String, dynamic> response) {
    if (response['success'] == true && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }

    throw Exception(response['message'] ?? 'Request failed');
  }

  List<Map<String, dynamic>> _requireDataList(Map<String, dynamic> response) {
    if (response['success'] == true && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    }

    throw Exception(response['message'] ?? 'Request failed');
  }
}
