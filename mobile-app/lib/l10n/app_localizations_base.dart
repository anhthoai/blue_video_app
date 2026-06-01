import 'package:flutter/material.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_th.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_es.dart';
import 'app_localizations_id.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ar.dart';

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
  String get clearCacheAction;
  String get clearCacheMessage;
  String get cacheCleared;
  String get openSystemSettings;
  String get openSystemSettingsFailed;
  String get openPrivacyPolicyFailed;
  String get notificationAccess;
  String get notificationsEnabled;
  String get notificationsDisabled;
  String get notificationsRestricted;
  String get requestNotificationPermission;
  String get privacyPolicySubtitle;
  String get feedbackMessageLabel;
  String get feedbackMessageHint;
  String get feedbackEmptyMessage;
  String get feedbackShareFailed;
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
  String get enableBiometricLoginOnDevice;
  String get signInWithBiometrics;
  String get biometricLoginFailed;
  String get biometricLoginError;
  String get biometricLogin;
  String get biometricLoginDescription;
  String get biometricLoginDisabled;
  String get biometricLoginDisableFailed;
  String get authenticateToLogin;
  String get biometricLoginEnabled;
  String get biometricSetupRequired;
  String get verifyEmailBeforeSignIn;

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
  String get paymentCheckingResultTitle;
  String get paymentSuccessSyncingTitle;
  String get paymentSyncPendingHelp;
  String get paymentOpenHome;
  String get paymentViewRechargeRecord;
  String get paymentMissingOrder;
  String get paymentNotCompletedRetry;
  String get paymentConfirmedCoinsAdded;
  String get paymentOpenedInBrowserReturnToApp;
  String get creditCardComingSoon;
  String get failedToOpenPaymentGateway;
  String get couldNotOpenBrowserForPayment;

  // Category filters
  String get all;
  String get categories;
  String get topRated;
  String get mostViewed;
  String get random;

  // Library Feature
  String get library;
  String get database;
  String get movies;
  String get ebooks;
  String get magazines;
  String get comics;
  String get movie;
  String get tvSeries;
  String get short;
  String get drama;
  String get comedy;
  String get romance;
  String get action;
  String get thriller;
  String get horror;
  String get lesbian;
  String get gay;
  String get bisexual;
  String get transgender;
  String get queer;
  String get episodes;
  String get season;
  String get episode;
  String get playMovie;
  String get addToWatchlist;
  String get releaseYear;
  String get rating;
  String get runtime;
  String get director;
  String get cast;
  String get overview;

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
  String get shortForYou;
  String get shortFollowing;
  String get shortSwipeUpOrDown;
  String get shortNoVideosFromCreatorsYouFollowYet;
  String get shortFollowMoreCreatorsOrSwitchToForYou;
  String get shortNoVideosAvailableYet;
  String get shortTryAgainLaterOrSwitchToExplore;
  String get shortBackToHome;
  String get shortSound;
  String get shortOpen;

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
  String get verificationEmailSent;
  String get verificationExpiredHelp;
  String get resendVerificationEmail;
  String get enterEmailToResendVerification;
  String get resendVerificationFailed;

  // App updates
  String get updateAvailable;
  String get updateRequired;
  String get currentVersion;
  String get latestVersion;
  String get whatsNew;
  String get updateNow;
  String get later;
  String get forceUpdateMessage;
  String get updateDownloading;
  String get updateInstallPrompt;
  String get updateDownloadFailed;
  String get updateRetry;
  String get updateInstallerFailed;
  String get updateAndroidInstallerOnly;

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

  // Dating feature
  String get datingExplore;
  String get datingMeet;
  String get datingSearchProfiles;
  String get datingSearchHint;
  String get datingClear;
  String get datingEnableLocation;
  String get datingLocationPermissionDenied;
  String get datingLocationError;
  String get datingPlanUnlimitedUnlocked;
  String get datingPlanVipUnlocked;
  String get datingPlanFreeUnlocked;
  String get datingUpdateLocation;
  String get datingSmart;
  String get datingTrendingInYourArea;
  String get datingNewFace;
  String get datingNoUsersNearby;
  String get datingAllowLocationAndTryAgain;
  String get datingYou;
  String get datingUnlockMoreProfilesBanner;
  String get datingRequestSentCheckChat;
  String get datingRequestSentViaChat;
  String get datingRequestAlreadySentCheckChat;
  String get datingFriendRequestSent;
  String get datingProfileNotFound;
  String get datingOpenPrivateAlbum;
  String get datingWaitingPermission;
  String get datingRequestUnlock;
  String get datingPrivatePhotos;
  String get datingPrivateAlbumPermissionGranted;
  String get datingPrivateAlbumPending;
  String get datingPrivateAlbumRequestPermission;
  String get datingSuperLiked;
  String get datingLikedWaitingMatch;
  String get datingPassed;
  String get datingHeight;
  String get datingWeight;
  String get datingBodyType;
  String get datingBodyHair;
  String get datingLanguages;
  String get datingLivesIn;
  String get datingNationality;
  String get datingEthnicity;
  String get datingRelationship;
  String get datingAboutMe;
  String get datingLookingFor;
  String get datingInterestedIn;
  String get datingWhereToMeet;
  String get datingTribes;
  String get datingSwipeHint;
  String get datingFilters;
  String get datingReset;
  String get datingRole;
  String get datingApplyFilters;
  String get datingAge;
  String get datingNoMatchesYet;
  String get datingLikeSomeoneBack;
  String get datingAiSuggestionsActive;
  String get datingAutoSuggestionsPerDay;
  String get datingUpgradeVipForAiMatch;
  String get datingAiSuggestions;
  String get datingDailySuggestions;
  String get datingMutualMatches;
  String get datingAiMatchModeActive;
  String get datingAutoMatchMode;
  String get datingVipAiScoring;
  String get datingUpgradeVipAiAccuracy;
  String get datingReject;
  String get datingAiScore;
  String get datingMutualMatch;
  String get datingPhotoUploaded;
  String get datingDeletePhoto;
  String get datingRemovePhotoConfirm;
  String get datingMyPrivateAlbum;
  String get datingPrivateAlbum;
  String get datingRequests;
  String get datingAccessRequests;
  String get datingNoPendingRequests;
  String get datingAccepted;
  String get datingDenied;
  String get datingWantsToSeePrivateAlbum;
  String get datingNotEnoughCoins;
  String get datingActivatedSuccessfully;
  String get datingPurchaseFailed;
  String get datingUpgradeTitle;
  String get datingYourFreePreviewReached;
  String get datingFreeUsersViewFirst;
  String get datingCurrentPlanCoins;
  String get datingViewUpToProfiles;
  String get datingUnlimitedProfileViews;
  String get datingSeeNearbyProfiles;
  String get datingAiMatchingSuggestions;
  String get datingPriorityDiscovery;
  String get datingUnlimitedNearbyBrowsing;
  String get datingBestAiQuality;
  String get datingHighestPriorityVisibility;
  String get datingAvailableDurations;
  String get datingPurchaseCoins;
  String get datingRechargeCoins;
  String get datingEditProfile;
  String get datingPersonalInformation;
  String get datingExpectations;
  String get datingPrivacySettings;
  String get datingShowDistance;
  String get datingShowDistanceSubtitle;
  String get datingShowOnlineStatus;
  String get datingAiMatching;
  String get datingAiMatchingSubtitle;
  String get datingSelectDateOfBirth;
  String get datingDateOfBirth;
  String get datingTapToSelect;
  String get datingSelectPrefix;

  // Profile and chat extras
  String get profileDatingAvatarsMax6;
  String get profileDatingAvatarsHelp;
  String get profileEditDatingProfileSubtitle;
  String get profilePrivateAlbumMax9Images;
  String get profilePrivateAlbumSubtitle;
  String get profilePleaseLogIn;
  String get profileUsernameRequired;
  String get profileUsernameMinLength;
  String get profileBioMaxLength;
  String get profileAccountInformation;
  String get profileAccountId;
  String get profileVerified;
  String get profileMemberSince;
  String get profileDangerZone;
  String get profileDeleteAccount;
  String get profileDeleteAccountConfirmMessage;
  String get profileDeleteAccountComingSoon;
  String get profileMainAvatar;
  String get profileYes;
  String get profileNo;
  String get profileDatingMaxPhotosReached;
  String get profileDatingAvatarAdded;
  String get profileDatingAvatarDeleteError;
  String get profileProfileUpdateFailed;
  String get profileFirstName;
  String get profileLastName;
  String get profileEnterFirstName;
  String get profileEnterLastName;
  String get profileEnterUsername;
  String get profileBioHint;
  String get chatFilterYourTurn;
  String get chatFilterUnread;
  String get chatFilterDistance;
  String get chatFilterWithPrivateAlbum;
  String get chatFilterRole;
  String get chatFilterGroup;
  String get chatRefreshChats;
  String get chatSearchChats;
  String get chatNoChatsFound;
  String get chatPrivateAlbumRequestText;
  String get chatPrivateAlbumUnlockedText;
  String get chatAlbumAccessGranted;
  String get chatAgree;
  String get chatAgreed;
  String get chatViewPrivateAlbum;
  String get chatRevokeAccess;
  String get chatAccessRevoked;
  String get chatAccessInvalid;
  String get chatPrivateAlbumRequestSent;
  String get chatPrivateAlbumRequestAlreadySent;
  String get chatPrivateAlbumNoPhotos;
  String get chatRequestSent;
  String get chatSendRequest;
  String get chatProfileSnapshot;
  String get chatPersonalProfile;
  String get chatMatchedExpectations;
  String get chatNoMatchedExpectations;
  String get chatYearsShort;
  String get chatCentimetersShort;
  String get chatKilogramsShort;
  String get chatInfo;
  String get chatMuteNotifications;
  String get chatUnmuteNotifications;
  String get chatRoom;
  String get chatMembers;
  String get chatOnlineNow;
  String get chatDirectMessage;
  String get chatParticipant;
  String get chatNoMessagesYet;
  String get chatStartConversation;
  String get chatAttachmentPhoto;
  String get chatAttachmentPhotoSubtitle;
  String get chatAttachmentCamera;
  String get chatAttachmentCameraSubtitle;
  String get chatAttachmentVideo;
  String get chatAttachmentVideoSubtitle;
  String get chatAttachmentDocument;
  String get chatAttachmentDocumentSubtitle;
  String get chatAttachmentAudio;
  String get chatAttachmentAudioSubtitle;
  String get chatUploadingFile;
  String get chatFileSentSuccessfully;
  String get chatFailedToUploadFile;
  String get chatUnableToLoadDetails;
  String get chatNotificationsMuted;
  String get chatNotificationsUnmuted;
  String get chatUnableToStartCall;
  String get chatGroupCallNotSupported;
  String get chatSignInToCall;
  String get chatUnableToStartCallGeneric;
  String get chatProfileUnavailable;
  String get chatSingleProfileUnavailable;

  // Community and home extras
  String get communityOriginal;
  String get communityRequest;
  String get communityHotForums;
  String get communityMore;
  String get communityContentCreators;
  String get communityRecommended;
  String get communityHighlights;
  String get hotForumsMomentumTitle;
  String get hotForumsMomentumSubtitle;
  String get hotForumsLoadErrorTitle;
  String get hotForumsEmptyTitle;
  String get hotForumsEmptySubtitle;
  String get contentCreatorMoreAppears;
  String get contentCreatorMetricLikes;
  String get contentCreatorMetricUploads;
  String get contentCreatorMetricEarnings;
  String get contentCreatorMetricCoins;
  String get contentCreatorWindowDay;
  String get contentCreatorWindowWeek;
  String get contentCreatorWindowMonth;

  // Additional localization keys (settings, community, profile, library)
  String get changePassword;
  String get changePasswordSubtitle;
  String get adminSection;
  String get managementDashboard;
  String get managementDashboardSubtitle;
  String get reportsMenu;
  String get reportsMenuSubtitle;
  String get feedbackInbox;
  String get feedbackInboxSubtitle;
  String get changePasswordHelp;
  String get currentPasswordLabel;
  String get newPasswordLabel;
  String get confirmNewPasswordLabel;
  String get currentPasswordRequired;
  String get newPasswordRequired;
  String get newPasswordMinLength;
  String get newPasswordMustDiffer;
  String get confirmNewPasswordRequired;
  String get changePasswordSuccess;
  String get changePasswordFailed;

  String get groupName;
  String get groupNameRequired;
  String get addAtLeastOneMember;
  String get selectedMembers;
  String get noUsersFound;
  String get errorLoadingUsers;

  String get communityUploadMasters;
  String get communityTopics;
  String get communityUsers;
  String get communityNothingHereRetry;
  String get communityFollowForumHint;
  String get communityFollowUserHint;
  String get communityNoForumsYet;
  String get communityRefreshHint;
  String get communityNoOriginalPostsYet;
  String get communityCreateFirstPostHint;
  String get communityRequestLatest;
  String get communityRequestRanking;
  String get communityRequestGuide;
  String get communitySearchingRequests;
  String get communityNoRankingYet;
  String get communityRankingHint;
  String get communityNoRequestsFound;
  String get communityTryAnotherKeyword;

  String get createPostAddContentOrMedia;
  String get createPostSuccess;
  String get createPostError;
  String get createPostAddMedia;
  String get createPostSelectedSummary;
  String get createPostProcessingVideos;
  String get createPostAudience;
  String get createPostFreePostHint;
  String get createPostValidCost;
  String get createPostVipOnly;
  String get createPostVipOnlySubtitle;
  String get createPostMakePublicSubtitle;
  String get createPostMakePrivateSubtitle;
  String get createPostSettings;
  String get createPostAllowComments;
  String get createPostAllowCommentsSubtitle;
  String get createPostAllowLinks;
  String get createPostAllowLinksSubtitle;
  String get createPostPinPost;
  String get createPostPinPostSubtitle;
  String get createPostNsfw;
  String get createPostNsfwSubtitle;
  String get createPostWhoCanReply;
  String get createPostFollowers;
  String get createPostPaidViewers;
  String get createPostPeopleYouFollow;
  String get createPostVerifiedFollowers;
  String get createPostNoOne;
  String get tagsOptional;
  String get selectedMedia;
  String get imagesLabel;
  String get videosLabel;

  String get createRequest;
  String get createRequestBannerTitle;
  String get createRequestBannerSubtitle;
  String get createRequestWhatLookingFor;
  String get createRequestDescribeHint;
  String get createRequestDescribeRequired;
  String get createRequestHeadlineHint;
  String get createRequestKeywords;
  String get createRequestKeywordsHint;
  String get createRequestReferenceImages;
  String get attach;
  String get createRequestReferenceHint;
  String get coinBounty;
  String get coinBountyHint;
  String get coinBountyValidation;
  String get availableBalance;
  String get publishing;
  String get publishRequest;
  String get attachImagesFailed;
  String get insufficientCoinsBounty;

  String get addLabel;
  String get failedLoadLibrarySections;
  String get noItemsFoundIn;
  String get ifRecentImportTryRefresh;
  String get unableToLoadSection;
  String get movieNotFound;
  String get originalTitlesLabel;
  String get releaseLabel;
  String get countryLabel;
  String get adultLabel;
  String get filesLabel;
  String get importFromUlozTo;
  String get videoFileLabel;
  String get noEpisodesYet;

  String get noLikedVideosYet;
  String get likedVideosWillAppear;
  String get refreshLikedVideos;
  String get noPlaylistsYet;
  String get createFirstPlaylist;
  String get refreshPlaylists;
  String get refreshPosts;
  String get privateLabel;
  String get totalViews;
  String get totalLikes;
  String get totalComments;
  String get engagementRate;
  String get likesPerVideo;
  String get commentsPerVideo;
  String get viewsPerVideo;

  String get uploadingProgress;
  String get selectThumbnailOptional;
  String get generatingThumbnails;
  String get autoGeneratedThumbnails;
  String get selectThumbnailOrUpload;
  String get enterVideoTitle;
  String get enterTitleRequired;
  String get enterVideoDescription;
  String get tagExamples;
  String get validCostMessage;
  String get uploadFailedWithError;

  // Add movie / admin / profile remaining strings
  String get addMovie;
  String get addNewMovie;
  String get manualMovieEntry;
  String get titleOptional;
  String get provideTitleToSearchHint;
  String get checking;
  String get typeLabel;
  String get externalIdsOptional;
  String get tvSeriesLabel;
  String get noTmdbMatches;
  String get originalLabel;
  String get importFromTmdb;
  String get enterTitleOrExternalId;
  String get failedSearchExistingTitles;
  String get failedSearchTmdb;
  String get movieImportedSuccessfully;
  String get failedImportMovie;
  String get noExistingTitlesFound;
  String get continueAddNewTitle;
  String get foundExistingTitles;
  String get noMatchingExistingTitles;
  String get languageLabel;
  String get genreLabel;
  String get alternativeTitles;
  String get noAlternativeTitlesYet;
  String get plotOverview;
  String get runtimeMinutes;
  String get genresCommaSeparated;
  String get countriesCommaSeparated;
  String get languagesCommaSeparated;
  String get posterImageUrl;
  String get videoTrailerUrl;
  String get titleRequired;
  String get failedCreateMovie;

  String get failedLoadPlaylists;
  String get noPlaylistsPromptCreate;
  String get untitledLabel;
  String get saveQrComingSoon;
  String get scanToViewProfile;

  String get adminAccessRequired;
  String get adminAccessOnly;
  String get adminUnableLoadData;
  String get aiMatchingProvider;
  String get addToPlaylistFailed;
  String get freeContentBonusCoins;
  String get freeContentBonusCoinsSubtitle;
  String get freeMediaPost;
  String get freeVideoUpload;
  String get screenCaptureProtection;
  String get screenCaptureProtectionSubtitle;
  String get datingFeature;
  String get datingFeatureSubtitle;
  String get searchRadius;
  String get recentFeedback;
  String get noFeedbackSubmittedYet;
}

/// Factory class to get the correct localization instance
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh', 'ja', 'vi', 'ko', 'th', 'pt', 'es', 'id', 'tr', 'ar']
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'zh':
        return AppLocalizationsZh();
      case 'ja':
        return AppLocalizationsJa();
      case 'vi':
        return AppLocalizationsVi();
      case 'ko':
        return AppLocalizationsKo();
      case 'th':
        return AppLocalizationsTh();
      case 'pt':
        return AppLocalizationsPt();
      case 'es':
        return AppLocalizationsEs();
      case 'id':
        return AppLocalizationsId();
      case 'tr':
        return AppLocalizationsTr();
      case 'ar':
        return AppLocalizationsAr();
      case 'en':
      default:
        return AppLocalizationsEn();
    }
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
