import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://192.168.1.100:3000/api/v1';

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

  // Like/Unlike a community post
  Future<Map<String, dynamic>> likeCommunityPost(String postId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/community/posts/$postId/like'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // Bookmark/Unbookmark a community post
  Future<Map<String, dynamic>> bookmarkCommunityPost(String postId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/community/posts/$postId/bookmark'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // Report a community post
  Future<Map<String, dynamic>> reportCommunityPost(
    String postId, {
    String? reason,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/community/posts/$postId/report'),
      headers: await _getHeaders(),
      body: json.encode({
        'reason': reason ?? 'Inappropriate content',
        'description': description ?? '',
      }),
    );
    return await _handleResponse(response);
  }

  // Pin/Unpin a community post
  Future<Map<String, dynamic>> pinCommunityPost(String postId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/community/posts/$postId/pin'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // Increment post views
  Future<Map<String, dynamic>> incrementPostViews(String postId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/community/posts/$postId/view'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // Get posts by tag
  Future<Map<String, dynamic>> getPostsByTag(
    String tag, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/community/posts/tag/$tag?page=$page&limit=$limit'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // Get all available tags from community posts
  Future<Map<String, dynamic>> getCommunityTags() async {
    final response = await http.get(
      Uri.parse('$baseUrl/community/tags'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> createCommunityPost({
    String? content,
    String? type,
    List<File>? imageFiles,
    List<File>? videoFiles,
    List<File>? videoThumbnails,
    List<String>? videoDurations,
    String? linkUrl,
    String? linkTitle,
    String? linkDescription,
    Map<String, dynamic>? pollOptions,
    List<String>? tags,
    int? cost,
    bool? requiresVip,
    bool? allowComments,
    bool? allowCommentLinks,
    bool? isPinned,
    bool? isNsfw,
    String? replyRestriction,
  }) async {
    // Create multipart request
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/community/posts'),
    );

    // Add headers
    final headers = await _getHeaders();
    request.headers.addAll(headers);

    // Add text fields
    if (content != null) request.fields['content'] = content;
    if (type != null) request.fields['type'] = type;
    if (linkUrl != null) request.fields['linkUrl'] = linkUrl;
    if (linkTitle != null) request.fields['linkTitle'] = linkTitle;
    if (linkDescription != null)
      request.fields['linkDescription'] = linkDescription;
    if (pollOptions != null)
      request.fields['pollOptions'] = json.encode(pollOptions);
    if (tags != null) request.fields['tags'] = json.encode(tags);
    if (cost != null) request.fields['cost'] = cost.toString();
    if (requiresVip != null)
      request.fields['requiresVip'] = requiresVip.toString();
    if (allowComments != null)
      request.fields['allowComments'] = allowComments.toString();
    if (allowCommentLinks != null)
      request.fields['allowCommentLinks'] = allowCommentLinks.toString();
    if (isPinned != null) request.fields['isPinned'] = isPinned.toString();
    if (isNsfw != null) request.fields['isNsfw'] = isNsfw.toString();
    if (replyRestriction != null)
      request.fields['replyRestriction'] = replyRestriction;

    // Add image files
    if (imageFiles != null) {
      for (final file in imageFiles) {
        request.files
            .add(await http.MultipartFile.fromPath('files', file.path));
      }
    }

    // Add video files
    if (videoFiles != null) {
      for (final file in videoFiles) {
        request.files
            .add(await http.MultipartFile.fromPath('files', file.path));
      }
    }

    // Add video thumbnails
    if (videoThumbnails != null && videoDurations != null) {
      for (int i = 0; i < videoThumbnails.length; i++) {
        final thumbnail = videoThumbnails[i];
        if (thumbnail != null) {
          request.files
              .add(await http.MultipartFile.fromPath('files', thumbnail.path));
        }
      }

      // Send durations as JSON
      request.fields['videoDurations'] = json.encode(videoDurations);
    }

    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

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

  // Increment video view count
  Future<Map<String, dynamic>> incrementVideoView(String videoId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/videos/$videoId/view'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  // Toggle video like
  Future<Map<String, dynamic>> toggleVideoLike(String videoId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/videos/$videoId/like'),
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  // Increment video share count
  Future<Map<String, dynamic>> incrementVideoShare(String videoId,
      {String? platform}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/videos/$videoId/share'),
      headers: await _getHeaders(),
      body: json.encode({
        if (platform != null) 'platform': platform,
      }),
    );

    return await _handleResponse(response);
  }

  // Increment video download count
  Future<Map<String, dynamic>> incrementVideoDownload(String videoId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/videos/$videoId/download'),
      headers: await _getHeaders(),
    );

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

  // Add comment to content
  Future<Map<String, dynamic>> addComment({
    required String contentId,
    required String contentType,
    required String content,
    String? parentCommentId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/social/comments'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'contentId': contentId,
        'contentType': contentType,
        'content': content,
        'parentCommentId': parentCommentId,
      }),
    );
    return await _handleResponse(response);
  }

  // Toggle like on comment
  Future<Map<String, dynamic>> toggleCommentLike(String commentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/social/comments/$commentId/like'),
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
    String? fileName,
    String? fileDirectory,
    int? fileSize,
    String? mimeType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/rooms/$roomId/messages'),
      headers: await _getHeaders(),
      body: json.encode({
        'content': content,
        'type': messageType ?? 'TEXT',
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileDirectory': fileDirectory,
        'fileSize': fileSize,
        'mimeType': mimeType,
      }),
    );

    return await _handleResponse(response);
  }

  // Upload chat attachment (file, image, video, audio, document)
  Future<Map<String, dynamic>> uploadChatAttachment(File file) async {
    final uri = Uri.parse('$baseUrl/chat/upload');

    final request = http.MultipartRequest('POST', uri);

    // Add headers
    final headers = await _getHeaders();
    headers.forEach((key, value) {
      request.headers[key] = value;
    });

    // Add file
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(
            lookupMimeType(file.path) ?? 'application/octet-stream'),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

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
        contentType: MediaType.parse(contentType),
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
        contentType: MediaType.parse(contentType),
      ),
    );

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> searchUsers({
    String query = '',
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'q': query,
      'limit': limit.toString(),
    };

    final uri = Uri.parse('$baseUrl/users/search/users').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    return await _handleResponse(response);
  }

  // Get presigned URL for file access (when CDN is not configured)
  Future<String?> getPresignedUrl(String objectKey) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/files/presigned-url'),
        headers: await _getHeaders(),
        body: json.encode({'objectKey': objectKey}),
      );

      final result = await _handleResponse(response);
      if (result['success'] == true && result['data'] != null) {
        return result['data']['url'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting presigned URL: $e');
      return null;
    }
  }

  // Convert object key to accessible URL (CDN or presigned URL)
  Future<String?> getAccessibleFileUrl(String? url) async {
    if (url == null || url.isEmpty) return null;

    // If URL starts with http/https, it's already a CDN URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Otherwise, it's an object key - get presigned URL
    return await getPresignedUrl(url);
  }

  // Get trending videos
  Future<List<Map<String, dynamic>>> getTrendingVideos({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final url = '$baseUrl/videos/trending?page=$page&limit=$limit';
      print('📡 API Call: GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      print('📥 Response Status: ${response.statusCode}');
      print(
          '📥 Response Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      final result = await _handleResponse(response);
      if (result['success'] == true && result['data'] != null) {
        final videos = List<Map<String, dynamic>>.from(result['data'] as List);
        print('✅ Trending API returned ${videos.length} videos');
        return videos;
      }
      print('⚠️ Trending API returned no data or success=false');
      return [];
    } catch (e) {
      print('❌ Error getting trending videos: $e');
      return [];
    }
  }

  // Get all categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: await _getHeaders(),
      );

      final result = await _handleResponse(response);
      if (result['success'] == true && result['data'] != null) {
        return List<Map<String, dynamic>>.from(result['data'] as List);
      }
      return [];
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

  // Get videos by category
  Future<List<Map<String, dynamic>>> getVideosByCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/categories/$categoryId/videos?page=$page&limit=$limit'),
        headers: await _getHeaders(),
      );

      final result = await _handleResponse(response);
      if (result['success'] == true && result['data'] != null) {
        return List<Map<String, dynamic>>.from(result['data'] as List);
      }
      return [];
    } catch (e) {
      print('Error getting videos by category: $e');
      return [];
    }
  }

  // Upload video
  // Update video thumbnail selection
  Future<Map<String, dynamic>> updateVideoThumbnail(
    String videoId,
    int thumbnailIndex,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/videos/$videoId/thumbnail'),
        headers: await _getHeaders(),
        body: json.encode({
          'thumbnailIndex': thumbnailIndex,
        }),
      );

      return await _handleResponse(response);
    } catch (e) {
      print('Error updating video thumbnail: $e');
      return {
        'success': false,
        'message': 'Failed to update thumbnail: $e',
      };
    }
  }

  Future<Map<String, dynamic>> uploadVideo({
    required File videoFile,
    File? thumbnailFile,
    required String title,
    String? description,
    String? categoryId,
    List<String>? tags,
    int? cost,
    String? status,
    int? duration,
    Map<String, File>? subtitleFiles, // langCode -> subtitle file
    Function(double)? onProgress,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/videos/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add video file
      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();
      final videoMultipart = http.MultipartFile(
        'video',
        videoStream,
        videoLength,
        filename: videoFile.path.split('/').last,
      );
      request.files.add(videoMultipart);

      // Add thumbnail if provided
      if (thumbnailFile != null) {
        final thumbnailStream = http.ByteStream(thumbnailFile.openRead());
        final thumbnailLength = await thumbnailFile.length();
        final thumbnailMultipart = http.MultipartFile(
          'thumbnail',
          thumbnailStream,
          thumbnailLength,
          filename: thumbnailFile.path.split('/').last,
        );
        request.files.add(thumbnailMultipart);
      }

      // Add subtitle files if provided
      if (subtitleFiles != null && subtitleFiles.isNotEmpty) {
        for (final entry in subtitleFiles.entries) {
          final langCode = entry.key;
          final subtitleFile = entry.value;

          final subtitleStream = http.ByteStream(subtitleFile.openRead());
          final subtitleLength = await subtitleFile.length();
          final subtitleMultipart = http.MultipartFile(
            'subtitle_$langCode', // Field name: subtitle_eng, subtitle_tha, etc.
            subtitleStream,
            subtitleLength,
            filename: subtitleFile.path.split('/').last,
          );
          request.files.add(subtitleMultipart);
        }

        // Add subtitle language codes as a field
        request.fields['subtitles'] = subtitleFiles.keys.join(',');
      }

      // Add fields
      request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;
      if (categoryId != null) request.fields['categoryId'] = categoryId;
      if (tags != null && tags.isNotEmpty)
        request.fields['tags'] = tags.join(',');
      if (cost != null) request.fields['cost'] = cost.toString();
      if (status != null) request.fields['status'] = status;
      if (duration != null) request.fields['duration'] = duration.toString();

      // Send request
      final streamedResponse = await request.send();

      // Listen to response stream and track progress
      List<int> responseBytes = [];

      await for (var chunk in streamedResponse.stream) {
        responseBytes.addAll(chunk);

        // Call progress callback if provided
        if (onProgress != null) {
          // For upload progress, we use a simple percentage based on response received
          // Note: This tracks download of response, not upload progress
          // For true upload progress, we'd need platform-specific implementation
          onProgress(
              0.9); // Show 90% when upload is complete and waiting for response
        }
      }

      // Convert response bytes to Response object
      final response = http.Response.bytes(
        responseBytes,
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
        request: streamedResponse.request,
      );

      // Call final progress
      if (onProgress != null) {
        onProgress(1.0);
      }

      return await _handleResponse(response);
    } catch (e) {
      print('Error uploading video: $e');
      return {
        'success': false,
        'message': 'Upload failed: $e',
      };
    }
  }

  // Socket.IO URL
  String get socketUrl =>
      baseUrl.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://');
}
