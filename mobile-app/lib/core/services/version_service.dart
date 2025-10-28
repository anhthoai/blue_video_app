import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

class VersionInfo {
  final String latestVersion;
  final String minVersion;
  final String currentVersion;
  final bool updateRequired;
  final bool forceUpdate;
  final String downloadUrl;
  final String releaseNotes;
  final String releaseDate;

  VersionInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.currentVersion,
    required this.updateRequired,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseDate,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      latestVersion: json['latestVersion'] ?? '1.0.0',
      minVersion: json['minVersion'] ?? '1.0.0',
      currentVersion: json['currentVersion'] ?? '1.0.0',
      updateRequired: json['updateRequired'] ?? false,
      forceUpdate: json['forceUpdate'] ?? false,
      downloadUrl: json['downloadUrl'] ?? '',
      releaseNotes: json['releaseNotes'] ?? '',
      releaseDate: json['releaseDate'] ?? '',
    );
  }
}

class VersionService {
  final ApiService _apiService = ApiService();

  Future<VersionInfo?> checkForUpdates() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Determine platform
      final platform = Platform.isIOS ? 'ios' : 'android';

      print('🔄 Checking for updates...');
      print('   Current version: $currentVersion');
      print('   Platform: $platform');

      // Call version check API
      final response = await _apiService.checkAppVersion(
        platform: platform,
        currentVersion: currentVersion,
      );

      if (response['success'] == true) {
        final versionInfo = VersionInfo.fromJson(response);

        print('✅ Version check complete:');
        print('   Latest: ${versionInfo.latestVersion}');
        print('   Update required: ${versionInfo.updateRequired}');
        print('   Force update: ${versionInfo.forceUpdate}');

        return versionInfo;
      }

      return null;
    } catch (e) {
      print('❌ Version check failed: $e');
      return null;
    }
  }
}

final versionServiceProvider = Provider<VersionService>((ref) {
  return VersionService();
});
