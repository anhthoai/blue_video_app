import 'package:flutter/material.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';
import 'app_localizations_ja.dart';

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
  String get done;
  String get next;
  String get previous;
  String get seeAll;
  String get viewAll;

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
  String get unlike;
  String get comment;
  String get reply;
  String get viewPost;
  String get upload;
  String get download;
  String get copy;
  String get copied;
  String get copiedToClipboard;

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
  String get description;
  String get duration;
  String get category;
  String get tags;
  String get selectCategory;
  String get addTags;
  String get videoTitle;
  String get videoDescription;

  // User Related
  String get followers;
  String get following;
  String get posts;
  String get wallet;
  String get coinBalance;
  String get recharge;
  String get history;
  String get username;
  String get email;
  String get password;
  String get bio;
  String get editProfile;
  String get saveChanges;

  // Search
  String get searchHint;
  String get searchVideos;
  String get searchPosts;
  String get searchUsers;
  String get noResults;
  String get noResultsFound;
  String get searchForSomething;

  // Time
  String get justNow;
  String get minutesAgo;
  String get hoursAgo;
  String get daysAgo;
  String get weeksAgo;
  String get monthsAgo;
  String get yearsAgo;

  // Auth
  String get login;
  String get register;
  String get forgotPassword;
  String get resetPassword;
  String get rememberMe;
  String get dontHaveAccount;
  String get alreadyHaveAccount;
  String get signIn;
  String get signUp;
  String get enterEmail;
  String get enterPassword;
  String get enterUsername;
  String get confirmPassword;
  String get createAccount;

  // Post/Community
  String get createPost;
  String get whatsOnYourMind;
  String get postContent;
  String get addPhotos;
  String get addVideos;
  String get publish;
  String get draft;
  String get newest;
  String get oldest;
  String get popular;

  // Chat
  String get chats;
  String get newChat;
  String get noConversations;
  String get typeMessage;
  String get sendMessage;
  String get online;
  String get offline;

  // Upload
  String get selectFile;
  String get selectVideo;
  String get selectImages;
  String get selectThumbnail;
  String get uploading;
  String get uploadComplete;
  String get uploadFailed;
  String get processing;

  // Validation
  String get fieldRequired;
  String get invalidEmail;
  String get passwordTooShort;
  String get passwordsDoNotMatch;
  String get usernameTooShort;
  String get usernameInvalid;

  // Error Messages
  String get errorLoadingData;
  String get errorUploadingFile;
  String get errorNetworkConnection;
  String get errorUnknown;
  String get errorTryAgain;
  String get noInternetConnection;

  // Success Messages
  String get success;
  String get savedSuccessfully;
  String get updatedSuccessfully;
  String get deletedSuccessfully;
  String get uploadedSuccessfully;

  // Other
  String get noNotifications;
  String get markAllAsRead;
  String get clearAll;
  String get confirm;
  String get discard;
  String get keepEditing;
  String get discardChanges;
  String get unsavedChangesMessage;
  String get deleteConfirmation;
  String get cannotBeUndone;
  String get viewProfile;
  String get shareProfile;
  String get copyLink;
  String get reportUser;
  String get blockUser;
  String get makePublic;
  String get makePrivate;
  String get public;
  String get private;
  String get watchNow;
  String get playNow;
  String get addToPlaylist;
  String get removeFromPlaylist;
  String get createPlaylist;
  String get playlistName;
  String get emptyPlaylist;
  String get noVideosYet;
  String get noPostsYet;
  String get beTheFirst;

  // Additional UI elements
  String get live;
  String get liveStreaming;
  String get comingSoon;
  String get liveStreamingDescription;
  String get noTrendingVideos;
  String get noCategories;
  String get noPlaylistsFound;
  String get createPlaylistPrompt;
  String get create;
  String get addTo;
  String get addedToPlaylist;
  String get failedToAddVideo;
  String get enterPlaylistName;
  String get descriptionOptional;
  String get enterPlaylistDescription;
  String get publicPlaylist;
  String get pleaseEnterPlaylistName;
  String get playlistCreatedSuccessfully;
  String get failedToCreatePlaylist;
  String get untitled;
  String get subcategories;
  String get createNewPlaylist;
  String get errorLoadingPlaylists;

  // Chat additional
  String get messages;
  String get startNewConversation;
  String get archivedChats;
  String get blockedUsers;
  String get chatSettings;
  String get newGroupChat;

  // Profile additional
  String get liked;
  String get qrCode;
  String get scanQrCode;
  String get analytics;

  // Video card menu actions
  String get addComment;
  String get noCommentsYet;
  String get beTheFirstToComment;
  String get viewComments;
  String get saveVideo;

  // Video player screen
  String get recommendedForYou;
  String get followingUser;
  String get unfollowedUser;
  String get shareVideo;
  String get downloadVideo;
  String get reportVideo;

  // Community screen
  String get bookmark;
  String get unbookmark;
  String get filterPosts;
  String get selectCategories;
  String get applyFilter;
  String get clearFilter;
  String get searchCommunity;

  // Profile screen additional
  String get playlistDescription;

  // Coin screens
  String get coinRecharge;
  String get rechargeRecord;
  String get coinDetails;
  String get onlineRecharge;
  String get coins;
  String get noCoinPackagesAvailable;
  String get pleaseSelectCoinPackage;
  String get failedToLoadCoinPackages;
  String get paymentFailed;
  String get coinHistory;
  String get currentBalance;
  String get noTransactionsYet;
  String get yourCoinHistoryWillAppearHere;
  String get rechargeNow;
  String get used;
  String get earned;
  String get trendingNow;

  // Upload video screen
  String get addTitle;
  String get addDescription;
  String get pleaseSelectVideo;
  String get thumbnailSelected;
  String get processingVideo;
  String get videoUploadedSuccessfully;
  String get errorProcessingVideo;
  String get errorSelectingVideo;
  String get costCoins;
  String get makeVideoPublic;
  String get tapToSelectVideoFile;
  String get tapToSelectThumbnailImage;
  String get separateTagsWithCommas;
  String get freeVideo;
  String get anyoneCanWatchThisVideo;
  String get onlyVipUsersCanWatchThisVideo;

  // Theme settings
  String get lightMode;
  String get darkMode;

  // Email verification
  String get emailVerification;
  String get verifyingEmail;
  String get emailVerified;
  String get verificationFailed;
  String get goToLogin;
  String get tryAgain;

  // App updates
  String get updateAvailable;
  String get updateRequired;
  String get currentVersion;
  String get latestVersion;
  String get whatsNew;
  String get updateNow;
  String get later;
  String get forceUpdateMessage;

  // Auth additional
  String get welcomeBack;
  String get signInToAccount;
  String get pleaseEnterEmail;
  String get pleaseEnterValidEmail;
  String get pleaseEnterPassword;
  String get passwordMinLength;
  String get pleaseEnterUsername;
  String get usernameMinLength;
  String get pleaseConfirmPassword;
  String get agreeToTerms;
  String get termsAndConditions;
  String get and;
  String get privacyPolicy;
  String get iAgreeToThe;
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
