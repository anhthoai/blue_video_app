import 'package:flutter/material.dart';

/// Base class for app localizations
abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
  
  // App General
  String get appName;
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get search;
  String get loading;
  String get error;
  String get retry;
  String get close;
  
  // Settings Screen
  String get settings;
  String get appInformation;
  String get appVersion;
  String get testInstructions;
  String get testInstructionsSubtitle;
  String get account;
  String get profileSettings;
  String get profileSettingsSubtitle;
  String get notifications;
  String get notificationsSubtitle;
  String get privacySecurity;
  String get privacySecuritySubtitle;
  String get showNsfwContent;
  String get nsfwContentVisible;
  String get nsfwContentBlurred;
  String get appSettings;
  String get theme;
  String get themeSubtitle;
  String get language;
  String get languageSubtitle;
  String get storage;
  String get storageSubtitle;
  String get support;
  String get helpSupport;
  String get helpSupportSubtitle;
  String get sendFeedback;
  String get sendFeedbackSubtitle;
  String get rateApp;
  String get rateAppSubtitle;
  String get debugTestingOnly;
  String get mockDataStatus;
  String get mockDataStatusSubtitle;
  String get apiStatus;
  String get apiStatusSubtitle;
  String get logout;
  String get logoutConfirmTitle;
  String get logoutConfirmMessage;
  String get logoutFailed;
  
  // Language Selection
  String get selectLanguage;
  String get english;
  String get chinese;
  String get japanese;
  String get systemDefault;
  
  // NSFW Confirmation
  String get ageConfirmationRequired;
  String get ageConfirmationMessage;
  String get iAm18Plus;
  
  // Common Actions
  String get share;
  String get report;
  String get block;
  String get unblock;
  String get follow;
  String get unfollow;
  String get like;
  String get comment;
  String get viewPost;
  String get upload;
  
  // Navigation
  String get home;
  String get discover;
  String get community;
  String get profile;
  String get chat;
  
  // Video Related
  String get videos;
  String get trending;
  String get forYou;
  String get subscriptions;
  String get playlists;
  String get uploadVideo;
  String get views;
  String get likes;
  String get comments;
  String get shares;
  
  // User Related
  String get followers;
  String get following;
  String get posts;
  String get wallet;
  String get coinBalance;
  String get recharge;
  String get history;
  
  // Error Messages
  String get errorLoadingData;
  String get errorUploadingFile;
  String get errorNetworkConnection;
  String get errorUnknown;
}

/// Factory class to get the correct localization instance
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh', 'ja'].contains(locale.languageCode);
  }
  
  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'zh':
        return AppLocalizationsZh();
      case 'ja':
        return AppLocalizationsJa();
      case 'en':
      default:
        return AppLocalizationsEn();
    }
  }
  
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

// English Translations
class AppLocalizationsEn extends AppLocalizations {
  @override
  String get appName => 'Blue Video';
  
  @override
  String get ok => 'OK';
  
  @override
  String get cancel => 'Cancel';
  
  @override
  String get save => 'Save';
  
  @override
  String get delete => 'Delete';
  
  @override
  String get edit => 'Edit';
  
  @override
  String get search => 'Search';
  
  @override
  String get loading => 'Loading...';
  
  @override
  String get error => 'Error';
  
  @override
  String get retry => 'Retry';
  
  @override
  String get close => 'Close';
  
  // Settings
  @override
  String get settings => 'Settings';
  
  @override
  String get appInformation => 'App Information';
  
  @override
  String get appVersion => 'App Version';
  
  @override
  String get testInstructions => 'Test Instructions';
  
  @override
  String get testInstructionsSubtitle => 'How to test the app features';
  
  @override
  String get account => 'Account';
  
  @override
  String get profileSettings => 'Profile Settings';
  
  @override
  String get profileSettingsSubtitle => 'Manage your profile information';
  
  @override
  String get notifications => 'Notifications';
  
  @override
  String get notificationsSubtitle => 'Manage notification preferences';
  
  @override
  String get privacySecurity => 'Privacy & Security';
  
  @override
  String get privacySecuritySubtitle => 'Manage your privacy settings';
  
  @override
  String get showNsfwContent => 'Show NSFW Content';
  
  @override
  String get nsfwContentVisible => 'NSFW content is visible';
  
  @override
  String get nsfwContentBlurred => 'NSFW content is blurred (18+ required)';
  
  @override
  String get appSettings => 'App Settings';
  
  @override
  String get theme => 'Theme';
  
  @override
  String get themeSubtitle => 'Light, Dark, or System';
  
  @override
  String get language => 'Language';
  
  @override
  String get languageSubtitle => 'English';
  
  @override
  String get storage => 'Storage';
  
  @override
  String get storageSubtitle => 'Manage app storage';
  
  @override
  String get support => 'Support';
  
  @override
  String get helpSupport => 'Help & Support';
  
  @override
  String get helpSupportSubtitle => 'Get help with the app';
  
  @override
  String get sendFeedback => 'Send Feedback';
  
  @override
  String get sendFeedbackSubtitle => 'Share your thoughts';
  
  @override
  String get rateApp => 'Rate App';
  
  @override
  String get rateAppSubtitle => 'Rate us on the app store';
  
  @override
  String get debugTestingOnly => 'Debug (Testing Only)';
  
  @override
  String get mockDataStatus => 'Mock Data Status';
  
  @override
  String get mockDataStatusSubtitle => 'Mock data is active for testing';
  
  @override
  String get apiStatus => 'API Status';
  
  @override
  String get apiStatusSubtitle => 'No real API connections';
  
  @override
  String get logout => 'Logout';
  
  @override
  String get logoutConfirmTitle => 'Logout';
  
  @override
  String get logoutConfirmMessage => 'Are you sure you want to logout?';
  
  @override
  String get logoutFailed => 'Logout failed';
  
  // Language Selection
  @override
  String get selectLanguage => 'Select Language';
  
  @override
  String get english => 'English';
  
  @override
  String get chinese => '中文 (Chinese)';
  
  @override
  String get japanese => '日本語 (Japanese)';
  
  @override
  String get systemDefault => 'System Default';
  
  // NSFW
  @override
  String get ageConfirmationRequired => 'Age Confirmation Required';
  
  @override
  String get ageConfirmationMessage =>
      'You must be 18 years or older to view NSFW content.\n\nDo you confirm that you are 18 years or older?';
  
  @override
  String get iAm18Plus => 'I am 18+';
  
  // Common Actions
  @override
  String get share => 'Share';
  
  @override
  String get report => 'Report';
  
  @override
  String get block => 'Block';
  
  @override
  String get unblock => 'Unblock';
  
  @override
  String get follow => 'Follow';
  
  @override
  String get unfollow => 'Unfollow';
  
  @override
  String get like => 'Like';
  
  @override
  String get comment => 'Comment';
  
  @override
  String get viewPost => 'View Post';
  
  @override
  String get upload => 'Upload';
  
  // Navigation
  @override
  String get home => 'Home';
  
  @override
  String get discover => 'Discover';
  
  @override
  String get community => 'Community';
  
  @override
  String get profile => 'Profile';
  
  @override
  String get chat => 'Chat';
  
  // Video Related
  @override
  String get videos => 'Videos';
  
  @override
  String get trending => 'Trending';
  
  @override
  String get forYou => 'For You';
  
  @override
  String get subscriptions => 'Subscriptions';
  
  @override
  String get playlists => 'Playlists';
  
  @override
  String get uploadVideo => 'Upload Video';
  
  @override
  String get views => 'views';
  
  @override
  String get likes => 'likes';
  
  @override
  String get comments => 'comments';
  
  @override
  String get shares => 'shares';
  
  // User Related
  @override
  String get followers => 'Followers';
  
  @override
  String get following => 'Following';
  
  @override
  String get posts => 'Posts';
  
  @override
  String get wallet => 'Wallet';
  
  @override
  String get coinBalance => 'Coin Balance';
  
  @override
  String get recharge => 'Recharge';
  
  @override
  String get history => 'History';
  
  // Error Messages
  @override
  String get errorLoadingData => 'Error loading data';
  
  @override
  String get errorUploadingFile => 'Error uploading file';
  
  @override
  String get errorNetworkConnection => 'Network connection error';
  
  @override
  String get errorUnknown => 'An unknown error occurred';
}

// Chinese Translations (Simplified)
class AppLocalizationsZh extends AppLocalizations {
  @override
  String get appName => '蓝色视频';
  
  @override
  String get ok => '确定';
  
  @override
  String get cancel => '取消';
  
  @override
  String get save => '保存';
  
  @override
  String get delete => '删除';
  
  @override
  String get edit => '编辑';
  
  @override
  String get search => '搜索';
  
  @override
  String get loading => '加载中...';
  
  @override
  String get error => '错误';
  
  @override
  String get retry => '重试';
  
  @override
  String get close => '关闭';
  
  // Settings
  @override
  String get settings => '设置';
  
  @override
  String get appInformation => '应用信息';
  
  @override
  String get appVersion => '应用版本';
  
  @override
  String get testInstructions => '测试说明';
  
  @override
  String get testInstructionsSubtitle => '如何测试应用功能';
  
  @override
  String get account => '账户';
  
  @override
  String get profileSettings => '个人资料设置';
  
  @override
  String get profileSettingsSubtitle => '管理您的个人资料信息';
  
  @override
  String get notifications => '通知';
  
  @override
  String get notificationsSubtitle => '管理通知偏好';
  
  @override
  String get privacySecurity => '隐私与安全';
  
  @override
  String get privacySecuritySubtitle => '管理您的隐私设置';
  
  @override
  String get showNsfwContent => '显示成人内容';
  
  @override
  String get nsfwContentVisible => '成人内容可见';
  
  @override
  String get nsfwContentBlurred => '成人内容已模糊（需年满18岁）';
  
  @override
  String get appSettings => '应用设置';
  
  @override
  String get theme => '主题';
  
  @override
  String get themeSubtitle => '浅色、深色或跟随系统';
  
  @override
  String get language => '语言';
  
  @override
  String get languageSubtitle => '中文';
  
  @override
  String get storage => '存储';
  
  @override
  String get storageSubtitle => '管理应用存储';
  
  @override
  String get support => '支持';
  
  @override
  String get helpSupport => '帮助与支持';
  
  @override
  String get helpSupportSubtitle => '获取应用帮助';
  
  @override
  String get sendFeedback => '发送反馈';
  
  @override
  String get sendFeedbackSubtitle => '分享您的想法';
  
  @override
  String get rateApp => '评价应用';
  
  @override
  String get rateAppSubtitle => '在应用商店为我们评分';
  
  @override
  String get debugTestingOnly => '调试（仅用于测试）';
  
  @override
  String get mockDataStatus => '模拟数据状态';
  
  @override
  String get mockDataStatusSubtitle => '模拟数据已激活用于测试';
  
  @override
  String get apiStatus => 'API 状态';
  
  @override
  String get apiStatusSubtitle => '无真实 API 连接';
  
  @override
  String get logout => '登出';
  
  @override
  String get logoutConfirmTitle => '登出';
  
  @override
  String get logoutConfirmMessage => '您确定要登出吗？';
  
  @override
  String get logoutFailed => '登出失败';
  
  // Language Selection
  @override
  String get selectLanguage => '选择语言';
  
  @override
  String get english => 'English (英语)';
  
  @override
  String get chinese => '中文';
  
  @override
  String get japanese => '日本語 (日语)';
  
  @override
  String get systemDefault => '跟随系统';
  
  // NSFW
  @override
  String get ageConfirmationRequired => '需要年龄确认';
  
  @override
  String get ageConfirmationMessage => '您必须年满18岁才能查看成人内容。\n\n您确认您已年满18岁吗？';
  
  @override
  String get iAm18Plus => '我已年满18岁';
  
  // Common Actions
  @override
  String get share => '分享';
  
  @override
  String get report => '举报';
  
  @override
  String get block => '屏蔽';
  
  @override
  String get unblock => '取消屏蔽';
  
  @override
  String get follow => '关注';
  
  @override
  String get unfollow => '取消关注';
  
  @override
  String get like => '点赞';
  
  @override
  String get comment => '评论';
  
  @override
  String get viewPost => '查看帖子';
  
  @override
  String get upload => '上传';
  
  // Navigation
  @override
  String get home => '首页';
  
  @override
  String get discover => '发现';
  
  @override
  String get community => '社区';
  
  @override
  String get profile => '个人资料';
  
  @override
  String get chat => '聊天';
  
  // Video Related
  @override
  String get videos => '视频';
  
  @override
  String get trending => '热门';
  
  @override
  String get forYou => '为你推荐';
  
  @override
  String get subscriptions => '订阅';
  
  @override
  String get playlists => '播放列表';
  
  @override
  String get uploadVideo => '上传视频';
  
  @override
  String get views => '次观看';
  
  @override
  String get likes => '个赞';
  
  @override
  String get comments => '条评论';
  
  @override
  String get shares => '次分享';
  
  // User Related
  @override
  String get followers => '粉丝';
  
  @override
  String get following => '关注中';
  
  @override
  String get posts => '帖子';
  
  @override
  String get wallet => '钱包';
  
  @override
  String get coinBalance => '金币余额';
  
  @override
  String get recharge => '充值';
  
  @override
  String get history => '历史';
  
  // Error Messages
  @override
  String get errorLoadingData => '加载数据出错';
  
  @override
  String get errorUploadingFile => '上传文件出错';
  
  @override
  String get errorNetworkConnection => '网络连接错误';
  
  @override
  String get errorUnknown => '发生未知错误';
}

// Japanese Translations
class AppLocalizationsJa extends AppLocalizations {
  @override
  String get appName => 'ブルービデオ';
  
  @override
  String get ok => 'OK';
  
  @override
  String get cancel => 'キャンセル';
  
  @override
  String get save => '保存';
  
  @override
  String get delete => '削除';
  
  @override
  String get edit => '編集';
  
  @override
  String get search => '検索';
  
  @override
  String get loading => '読み込み中...';
  
  @override
  String get error => 'エラー';
  
  @override
  String get retry => '再試行';
  
  @override
  String get close => '閉じる';
  
  // Settings
  @override
  String get settings => '設定';
  
  @override
  String get appInformation => 'アプリ情報';
  
  @override
  String get appVersion => 'アプリバージョン';
  
  @override
  String get testInstructions => 'テスト手順';
  
  @override
  String get testInstructionsSubtitle => 'アプリ機能のテスト方法';
  
  @override
  String get account => 'アカウント';
  
  @override
  String get profileSettings => 'プロフィール設定';
  
  @override
  String get profileSettingsSubtitle => 'プロフィール情報を管理';
  
  @override
  String get notifications => '通知';
  
  @override
  String get notificationsSubtitle => '通知設定を管理';
  
  @override
  String get privacySecurity => 'プライバシーとセキュリティ';
  
  @override
  String get privacySecuritySubtitle => 'プライバシー設定を管理';
  
  @override
  String get showNsfwContent => 'NSFWコンテンツを表示';
  
  @override
  String get nsfwContentVisible => 'NSFWコンテンツが表示されます';
  
  @override
  String get nsfwContentBlurred => 'NSFWコンテンツがぼかされています（18歳以上）';
  
  @override
  String get appSettings => 'アプリ設定';
  
  @override
  String get theme => 'テーマ';
  
  @override
  String get themeSubtitle => 'ライト、ダーク、またはシステム';
  
  @override
  String get language => '言語';
  
  @override
  String get languageSubtitle => '日本語';
  
  @override
  String get storage => 'ストレージ';
  
  @override
  String get storageSubtitle => 'アプリストレージを管理';
  
  @override
  String get support => 'サポート';
  
  @override
  String get helpSupport => 'ヘルプとサポート';
  
  @override
  String get helpSupportSubtitle => 'アプリのヘルプを取得';
  
  @override
  String get sendFeedback => 'フィードバックを送信';
  
  @override
  String get sendFeedbackSubtitle => 'ご意見をお聞かせください';
  
  @override
  String get rateApp => 'アプリを評価';
  
  @override
  String get rateAppSubtitle => 'アプリストアで評価してください';
  
  @override
  String get debugTestingOnly => 'デバッグ（テストのみ）';
  
  @override
  String get mockDataStatus => 'モックデータステータス';
  
  @override
  String get mockDataStatusSubtitle => 'テスト用のモックデータが有効です';
  
  @override
  String get apiStatus => 'APIステータス';
  
  @override
  String get apiStatusSubtitle => '実際のAPI接続なし';
  
  @override
  String get logout => 'ログアウト';
  
  @override
  String get logoutConfirmTitle => 'ログアウト';
  
  @override
  String get logoutConfirmMessage => '本当にログアウトしますか？';
  
  @override
  String get logoutFailed => 'ログアウトに失敗しました';
  
  // Language Selection
  @override
  String get selectLanguage => '言語を選択';
  
  @override
  String get english => 'English (英語)';
  
  @override
  String get chinese => '中文 (中国語)';
  
  @override
  String get japanese => '日本語';
  
  @override
  String get systemDefault => 'システムデフォルト';
  
  // NSFW
  @override
  String get ageConfirmationRequired => '年齢確認が必要です';
  
  @override
  String get ageConfirmationMessage => 'NSFWコンテンツを表示するには18歳以上である必要があります。\n\n18歳以上であることを確認しますか？';
  
  @override
  String get iAm18Plus => '18歳以上です';
  
  // Common Actions
  @override
  String get share => '共有';
  
  @override
  String get report => '報告';
  
  @override
  String get block => 'ブロック';
  
  @override
  String get unblock => 'ブロック解除';
  
  @override
  String get follow => 'フォロー';
  
  @override
  String get unfollow => 'フォロー解除';
  
  @override
  String get like => 'いいね';
  
  @override
  String get comment => 'コメント';
  
  @override
  String get viewPost => '投稿を表示';
  
  @override
  String get upload => 'アップロード';
  
  // Navigation
  @override
  String get home => 'ホーム';
  
  @override
  String get discover => '発見';
  
  @override
  String get community => 'コミュニティ';
  
  @override
  String get profile => 'プロフィール';
  
  @override
  String get chat => 'チャット';
  
  // Video Related
  @override
  String get videos => 'ビデオ';
  
  @override
  String get trending => 'トレンド';
  
  @override
  String get forYou => 'おすすめ';
  
  @override
  String get subscriptions => '登録チャンネル';
  
  @override
  String get playlists => 'プレイリスト';
  
  @override
  String get uploadVideo => 'ビデオをアップロード';
  
  @override
  String get views => '回視聴';
  
  @override
  String get likes => 'いいね';
  
  @override
  String get comments => 'コメント';
  
  @override
  String get shares => '共有';
  
  // User Related
  @override
  String get followers => 'フォロワー';
  
  @override
  String get following => 'フォロー中';
  
  @override
  String get posts => '投稿';
  
  @override
  String get wallet => 'ウォレット';
  
  @override
  String get coinBalance => 'コイン残高';
  
  @override
  String get recharge => 'チャージ';
  
  @override
  String get history => '履歴';
  
  // Error Messages
  @override
  String get errorLoadingData => 'データの読み込みエラー';
  
  @override
  String get errorUploadingFile => 'ファイルのアップロードエラー';
  
  @override
  String get errorNetworkConnection => 'ネットワーク接続エラー';
  
  @override
  String get errorUnknown => '不明なエラーが発生しました';
}

