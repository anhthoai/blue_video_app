import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../core/services/app_lifecycle_service.dart';
import '../home/home_screen.dart';
// import '../discover/discover_screen.dart'; // Hidden for now
import '../library/library_screen.dart';
import '../community/community_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/current_user_profile_screen.dart';
import '../dating/dating_screen.dart';
import '../../core/services/version_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  AppLifecycleObserver? _lifecycleObserver;
  bool _prevDatingEnabled = false;

  final List<Widget> _baseScreens = [
    const HomeScreen(),
    const LibraryScreen(),
    const CommunityScreen(),
    const CurrentUserProfileScreen(),
    const ChatListScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Register lifecycle observer for background resume checks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final updateCoordinator = ref.read(appUpdateCoordinatorProvider);
        _lifecycleObserver = AppLifecycleObserver(
          context: context,
          updateCoordinator: updateCoordinator,
        );
        WidgetsBinding.instance.addObserver(_lifecycleObserver!);
        _refreshDatingFeatureFlag();
      }
    });
  }

  Future<void> _refreshDatingFeatureFlag() async {
    final info = await ref.read(versionServiceProvider).checkForUpdates();
    if (!mounted || info == null) {
      return;
    }
    ref.read(datingEnabledProvider.notifier).state = info.datingEnabled;
  }

  @override
  void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final homeFeedTabIndex = ref.watch(homeFeedTabIndexProvider);
    final isShortFeedTab = _currentIndex == 0 && homeFeedTabIndex > 0;
    final datingEnabled = ref.watch(datingEnabledProvider);

    // Reset index when dating tab disappears
    if (_prevDatingEnabled && !datingEnabled && _currentIndex >= _baseScreens.length) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _currentIndex = 0),
      );
    }
    _prevDatingEnabled = datingEnabled;

    final screens = [
      const HomeScreen(),
      const LibraryScreen(),
      const CommunityScreen(),
      const CurrentUserProfileScreen(),
      if (datingEnabled) const DatingScreen(),
      const ChatListScreen(),
    ];

    // Clamp index
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    final List<BottomNavigationBarItem> navItems = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: l10n.home,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.video_library_outlined),
        activeIcon: const Icon(Icons.video_library),
        label: l10n.library,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.people_outlined),
        activeIcon: const Icon(Icons.people),
        label: l10n.community,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outlined),
        activeIcon: const Icon(Icons.person),
        label: l10n.profile,
      ),
      if (datingEnabled)
        const BottomNavigationBarItem(
          icon: Icon(Icons.favorite_outline),
          activeIcon: Icon(Icons.favorite),
          label: 'Dating',
        ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.chat_outlined),
        activeIcon: const Icon(Icons.chat),
        label: l10n.chat,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor:
            isShortFeedTab ? Colors.black : Theme.of(context).colorScheme.surface,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor:
            isShortFeedTab ? Colors.white70 : AppTheme.textSecondaryColor,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
        items: navItems,
      ),
    );
  }
}
