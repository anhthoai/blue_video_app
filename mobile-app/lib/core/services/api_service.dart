import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://192.168.1.100:3000/api/v1';
  static String get socketUrl =>
      dotenv.env['API_SOCKET_URL'] ?? 'http://192.168.1.100:3000';

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Get headers with authentication
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Save tokens
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // Clear tokens
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // Get stored access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Handle API response
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      // Handle 401 Unauthorized - auto sign out
      await _handleUnauthorized();
      throw Exception('Authentication required - please sign in again');
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Handle 401 Unauthorized response
  Future<void> _handleUnauthorized() async {
    // Clear tokens and user data
    await clearTokens();

    // Clear any stored user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('remember_me');
    await prefs.remove('current_user');

    print('🔐 User automatically signed out due to invalid authentication');
  }

  // Authentication APIs
  Future<Map<String, dynamic>> login(String email, String password,
      {bool rememberMe = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _getHeaders(),
      body: json.encode({
        'email': email,
        'password': password,
        'rememberMe': rememberMe,
      }),
    );

    final data = await _handleResponse(response);

    if (data['success'] == true && data['data'] != null) {
      final userData = data['data'];
      await saveTokens(
        userData['accessToken'] ?? '',
        userData['refreshToken'] ?? '',
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? bio,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: await _getHeaders(),
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'bio': bio,
      }),
    );

    final data = await _handleResponse(response);

    if (data['success'] == true && data['data'] != null) {
      final userData = data['data'];
      await saveTokens(
        userData['accessToken'] ?? '',
        userData['refreshToken'] ?? '',
      );
    }

    return data;
  }

  Future<void> logout() async {
    await clearTokens();
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: await _getHeaders(),
      body: json.encode({
        'email': email,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: await _getHeaders(),
      body: json.encode({
        'token': token,
        'newPassword': newPassword,
      }),
    );

    return await _handleResponse(response);
  }

  // Community Posts APIs
  Future<Map<String, dynamic>> getCommunityPosts({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (category != null) queryParams['category'] = category;
    if (search != null) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/community/posts').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> createCommunityPost({
    required String type,
    String? title,
    String? content,
    List<String>? images,
    List<String>? videos,
    String? linkUrl,
    String? linkTitle,
    String? linkDescription,
    Map<String, dynamic>? pollOptions,
    List<String>? tags,
    String? category,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/community/posts'),
      headers: await _getHeaders(),
      body: json.encode({
        'type': type,
        'title': title,
        'content': content,
        'images': images ?? [],
        'videos': videos ?? [],
        'linkUrl': linkUrl,
        'linkTitle': linkTitle,
        'linkDescription': linkDescription,
        'pollOptions': pollOptions,
        'tags': tags ?? [],
        'category': category,
      }),
    );

    return await _handleResponse(response);
  }

  // Video APIs
  Future<Map<String, dynamic>> getVideos({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null) queryParams['search'] = search;
    if (category != null) queryParams['category'] = category;

    final uri = Uri.parse('$baseUrl/videos').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> uploadVideo({
    required String title,
    String? description,
    required File videoFile,
    String? thumbnailPath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/videos/upload'),
    );

    // Add headers
    final headers = await _getHeaders();
    request.headers.addAll(headers);

    // Add video file
    request.files.add(await http.MultipartFile.fromPath(
      'video',
      videoFile.path,
    ));

    // Add thumbnail if provided
    if (thumbnailPath != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'thumbnail',
        thumbnailPath,
      ));
    }

    // Add other fields
    request.fields['title'] = title;
    if (description != null) request.fields['description'] = description;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return await _handleResponse(response);
  }

  // User APIs
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getUserVideos(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/videos'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> followUser(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/follow'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId/follow'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> reportUser({
    required String userId,
    required String reason,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/report'),
      headers: await _getHeaders(),
      body: json.encode({
        'reason': reason,
        'description': description,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> blockUser(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/block'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> unblockUser(String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId/block'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  // Social APIs
  Future<Map<String, dynamic>> toggleLike({
    required String contentId,
    required String contentType,
    required String likeType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/social/like'),
      headers: await _getHeaders(),
      body: json.encode({
        'contentId': contentId,
        'contentType': contentType,
        'type': likeType,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> addComment({
    required String contentId,
    required String contentType,
    required String content,
    String? parentId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/social/comment'),
      headers: await _getHeaders(),
      body: json.encode({
        'contentId': contentId,
        'contentType': contentType,
        'content': content,
        'parentId': parentId,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getComments({
    required String contentId,
    required String contentType,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'contentId': contentId,
      'contentType': contentType,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final uri = Uri.parse('$baseUrl/social/comments').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> shareContent({
    required String contentId,
    required String contentType,
    String? message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/social/share'),
      headers: await _getHeaders(),
      body: json.encode({
        'contentId': contentId,
        'contentType': contentType,
        'message': message,
      }),
    );

    return await _handleResponse(response);
  }

  // Chat APIs
  Future<Map<String, dynamic>> getChatRooms({
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final uri = Uri.parse('$baseUrl/chat/rooms').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> createChatRoom({
    String? name,
    required String type,
    required List<String> participantIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/rooms'),
      headers: await _getHeaders(),
      body: json.encode({
        'name': name,
        'type': type,
        'participantIds': participantIds,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getChatMessages({
    required String roomId,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final uri = Uri.parse('$baseUrl/chat/rooms/$roomId/messages').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> sendMessage({
    required String roomId,
    required String content,
    String? messageType,
    String? fileUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/rooms/$roomId/messages'),
      headers: await _getHeaders(),
      body: json.encode({
        'content': content,
        'messageType': messageType ?? 'TEXT',
        'fileUrl': fileUrl,
      }),
    );

    return await _handleResponse(response);
  }

  // Get single video by ID
  Future<Map<String, dynamic>> getVideoById(String videoId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/videos/$videoId'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  // Video management APIs
  Future<Map<String, dynamic>> updateVideo({
    required String videoId,
    String? title,
    String? description,
    List<String>? tags,
    String? category,
    bool? isPublic,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/videos/$videoId'),
      headers: await _getHeaders(),
      body: json.encode({
        'title': title,
        'description': description,
        'tags': tags,
        'category': category,
        'isPublic': isPublic,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> deleteVideo(String videoId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/videos/$videoId'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  // Health check
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await http.get(
      Uri.parse('$baseUrl/../health'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  // Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    required String username,
    String? bio,
    String? firstName,
    String? lastName,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/profile'),
      headers: await _getHeaders(),
      body: json.encode({
        'username': username,
        'bio': bio,
        'firstName': firstName,
        'lastName': lastName,
      }),
    );

    return await _handleResponse(response);
  }

  // Upload avatar
  Future<Map<String, dynamic>> uploadAvatar(File imageFile) async {
    final token = await getAccessToken();
    if (token == null) {
      throw Exception('No access token available');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/avatar'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    // Determine content type from file extension
    String contentType = 'image/jpeg';
    final extension = imageFile.path.split('.').last.toLowerCase();
    if (extension == 'png') {
      contentType = 'image/png';
    } else if (extension == 'jpg' || extension == 'jpeg') {
      contentType = 'image/jpeg';
    } else if (extension == 'gif') {
      contentType = 'image/gif';
    } else if (extension == 'webp') {
      contentType = 'image/webp';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'avatar',
        imageFile.path,
        contentType: http_parser.MediaType.parse(contentType),
      ),
    );

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    return await _handleResponse(response);
  }

  // Upload banner
  Future<Map<String, dynamic>> uploadBanner(File imageFile) async {
    final token = await getAccessToken();
    if (token == null) {
      throw Exception('No access token available');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/banner'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    // Determine content type from file extension
    String contentType = 'image/jpeg';
    final extension = imageFile.path.split('.').last.toLowerCase();
    if (extension == 'png') {
      contentType = 'image/png';
    } else if (extension == 'jpg' || extension == 'jpeg') {
      contentType = 'image/jpeg';
    } else if (extension == 'gif') {
      contentType = 'image/gif';
    } else if (extension == 'webp') {
      contentType = 'image/webp';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'banner',
        imageFile.path,
        contentType: http_parser.MediaType.parse(contentType),
      ),
    );

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    return await _handleResponse(response);
  }
}
