import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../core/services/version_service.dart';
import '../../core/services/app_lifecycle_service.dart';
import '../home/home_screen.dart';
// import '../discover/discover_screen.dart'; // Hidden for now
import '../library/library_screen.dart';
import '../community/community_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/current_user_profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  AppLifecycleObserver? _lifecycleObserver;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LibraryScreen(), // New Library screen
    // const DiscoverScreen(), // Hidden for now
    const CommunityScreen(),
    const ChatListScreen(),
    const CurrentUserProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Initialize lifecycle observer and check for updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final versionService = ref.read(versionServiceProvider);
        _lifecycleObserver = AppLifecycleObserver(
          context: context,
          versionService: versionService,
        );
        WidgetsBinding.instance.addObserver(_lifecycleObserver!);

        // Check for updates on startup
        _lifecycleObserver!.checkForUpdatesOnStartup();
      }
    });
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
      // BottomNavigationBarItem(
      //   icon: const Icon(Icons.explore_outlined),
      //   activeIcon: const Icon(Icons.explore),
      //   label: l10n.discover,
      // ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.people_outlined),
        activeIcon: const Icon(Icons.people),
        label: l10n.community,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.chat_outlined),
        activeIcon: const Icon(Icons.chat),
        label: l10n.chat,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outlined),
        activeIcon: const Icon(Icons.person),
        label: l10n.profile,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondaryColor,
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
