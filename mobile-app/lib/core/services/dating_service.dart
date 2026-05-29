import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'api_service.dart';
import '../../models/dating_model.dart';

List<String> _toStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.cast<String>();
  return [];
}

class DatingService {
  static final DatingService _instance = DatingService._internal();
  factory DatingService() => _instance;
  DatingService._internal();

  final ApiService _api = ApiService();

  // ── Explore ───────────────────────────────────────────────────────────────

  Future<List<DatingExploreUser>> getExploreUsers({
    String tab = 'nearby',
    double? lat,
    double? lon,
    int radiusKm = 3,
    int page = 1,
    int limit = 180,
    int? minAge,
    int? maxAge,
    String? query,
    List<String>? roles,
    List<String>? tribes,
    List<String>? lookingFor,
  }) async {
    final headers = await _api.getHeaders();
    final params = {
      'tab': tab,
      'radiusKm': radiusKm.toString(),
      'page': page.toString(),
      'limit': limit.toString(),
      if (lat != null) 'lat': lat.toString(),
      if (lon != null) 'lon': lon.toString(),
      if (minAge != null) 'minAge': minAge.toString(),
      if (maxAge != null) 'maxAge': maxAge.toString(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (roles != null && roles.isNotEmpty) 'roles': roles.join(','),
      if (tribes != null && tribes.isNotEmpty) 'tribes': tribes.join(','),
      if (lookingFor != null && lookingFor.isNotEmpty)
        'lookingFor': lookingFor.join(','),
    };

    final uri = Uri.parse('${ApiService.baseUrl}/dating/explore')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && json['success'] == true) {
      final list = json['data'] as List;
      return list
          .map((e) => DatingExploreUser.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(json['message'] ?? 'Failed to load explore users');
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<DatingProfile> getDatingProfile(String userId) async {
    final headers = await _api.getHeaders();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/dating/profile/$userId'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      return DatingProfile.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw Exception(json['message'] ?? 'Failed to get dating profile');
  }

  Future<DatingProfile> getMyDatingProfile() => getDatingProfile('me');

  Future<DatingProfile> updateDatingProfile(Map<String, dynamic> data) async {
    final headers = await _api.getHeaders();
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/dating/profile'),
      headers: headers,
      body: jsonEncode(data),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      return DatingProfile.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw Exception(json['message'] ?? 'Failed to update dating profile');
  }

  Future<DatingUpgradeStatus> getUpgradeStatus() async {
    final headers = await _api.getHeaders();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/dating/upgrade/status'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      return DatingUpgradeStatus.fromJson(json['data'] as Map<String, dynamic>);
    }
    throw Exception(json['message'] ?? 'Failed to get dating upgrade status');
  }

  Future<List<DatingUpgradePlan>> getUpgradePlans() async {
    final headers = await _api.getHeaders();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/dating/upgrade/plans'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      final plans = (json['data'] as Map<String, dynamic>)['plans'] as List<dynamic>? ?? const [];
      return plans
          .map((item) => DatingUpgradePlan.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception(json['message'] ?? 'Failed to get dating upgrade plans');
  }

  Future<DatingUpgradeStatus> purchaseUpgrade({
    required String tier,
    required String duration,
  }) async {
    final headers = await _api.getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/dating/upgrade/purchase'),
      headers: headers,
      body: jsonEncode({
        'tier': tier,
        'duration': duration,
      }),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>;
      return DatingUpgradeStatus(
        tier: data['tier'] as String? ?? tier,
        expiresAt: data['expiresAt'] != null
            ? DateTime.tryParse(data['expiresAt'] as String)
            : null,
        viewLimit: (data['tier'] as String?) == 'UNLIMITED'
            ? null
            : (data['tier'] as String?) == 'VIP'
                ? 600
                : 60,
        coinBalance: data['coinBalance'] as int? ?? 0,
      );
    }
    throw Exception(json['message'] ?? 'Failed to purchase dating upgrade');
  }

  // ── Match ─────────────────────────────────────────────────────────────────

  Future<bool> sendMatchAction(String userId, String action) async {
    final headers = await _api.getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/dating/match/$userId'),
      headers: headers,
      body: jsonEncode({'action': action}),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      return json['isMutual'] as bool? ?? false;
    }
    throw Exception(json['message'] ?? 'Failed to send match action');
  }

  Future<List<DatingMatchUser>> getMutualMatches({
    int page = 1,
    int limit = 20,
  }) async {
    final headers = await _api.getHeaders();
    final uri = Uri.parse('${ApiService.baseUrl}/dating/matches')
        .replace(queryParameters: {'page': page.toString(), 'limit': limit.toString()});
    final response = await http.get(uri, headers: headers);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      final list = json['data'] as List;
      return list
          .map((e) => DatingMatchUser.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(json['message'] ?? 'Failed to get matches');
  }

  Future<DatingSuggestionResult> getSuggestedMatches() async {
    final headers = await _api.getHeaders();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/dating/matches/suggestions'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      return DatingSuggestionResult.fromJson(json);
    }
    throw Exception(json['message'] ?? 'Failed to get suggested matches');
  }

  // ── Private Album ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadPrivatePhoto(File photo) async {
    final token = await _api.getAccessToken();
    final mimeType = lookupMimeType(photo.path) ?? 'image/jpeg';
    final parts = mimeType.split('/');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/dating/private-album/upload'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath(
      'photo',
      photo.path,
      contentType: MediaType(parts[0], parts[1]),
    ));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (streamed.statusCode == 200 && json['success'] == true) {
      return json['data'] as Map<String, dynamic>;
    }
    throw Exception(json['message'] ?? 'Failed to upload photo');
  }

  Future<List<String>> uploadPublicPhoto(File photo) async {
    final token = await _api.getAccessToken();
    final mimeType = lookupMimeType(photo.path) ?? 'image/jpeg';
    final parts = mimeType.split('/');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/dating/public-photos/upload'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath(
      'photo',
      photo.path,
      contentType: MediaType(parts[0], parts[1]),
    ));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (streamed.statusCode == 200 && json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>;
      return _toStringList(data['publicPhotos']);
    }
    throw Exception(json['message'] ?? 'Failed to upload public photo');
  }

  Future<List<String>> deletePublicPhoto(int index) async {
    final headers = await _api.getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/dating/public-photos/$index'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>;
      return _toStringList(data['publicPhotos']);
    }
    throw Exception(json['message'] ?? 'Failed to delete public photo');
  }

  Future<void> deletePrivatePhoto(int index) async {
    final headers = await _api.getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/dating/private-album/$index'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Failed to delete photo');
    }
  }

  Future<void> requestPrivateAlbumAccess(String userId, {String? message}) async {
    final headers = await _api.getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/dating/private-album/request/$userId'),
      headers: headers,
      body: jsonEncode({'message': message}),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Failed to request album access');
    }
  }

  Future<void> respondPrivateAlbumAccess(
    String requestId,
    String action, // 'ACCEPTED' | 'DENIED'
  ) async {
    final headers = await _api.getHeaders();
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/dating/private-album/respond/$requestId'),
      headers: headers,
      body: jsonEncode({'action': action}),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Failed to respond to album access');
    }
  }

  Future<List<PrivateAlbumAccessRequest>> getPrivateAlbumAccessRequests({
    String type = 'received', // 'received' | 'sent'
  }) async {
    final headers = await _api.getHeaders();
    final uri = Uri.parse('${ApiService.baseUrl}/dating/private-album/requests')
        .replace(queryParameters: {'type': type});
    final response = await http.get(uri, headers: headers);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && json['success'] == true) {
      final list = json['data'] as List;
      return list
          .map((e) => PrivateAlbumAccessRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(json['message'] ?? 'Failed to get access requests');
  }

  Future<Map<String, dynamic>> requestPrivateAlbumViaChat(String userId) async {
    final headers = await _api.getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/dating/private-album/request-chat/$userId'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['success'] != true) throw Exception(json['message'] ?? 'Failed to send request');
    return json['data'] as Map<String, dynamic>;
  }

  Future<void> agreePrivateAlbumRequest(String requestId) async {
    final headers = await _api.getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/dating/private-album/agree-chat/$requestId'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['success'] != true) throw Exception(json['message'] ?? 'Failed to agree to request');
  }

  Future<void> revokePrivateAlbumAccess(String requesterId) async {
    final headers = await _api.getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/dating/private-album/revoke/$requesterId'),
      headers: headers,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['success'] != true) throw Exception(json['message'] ?? 'Failed to revoke access');
  }
}
