import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/dating_service.dart';
import '../../core/services/file_url_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dating_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/presigned_image.dart';
import 'dating_profile_screen.dart';
import 'dating_filter_sheet.dart';
import 'dating_meet_screen.dart';
import 'dating_upgrade_screen.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _exploreFiltersProvider =
    StateProvider<DatingExploreFilters>((ref) => const DatingExploreFilters());

final _exploreSearchProvider = StateProvider<String>((ref) => '');

final _upgradeStatusProvider =
    FutureProvider.autoDispose<DatingUpgradeStatus>((ref) async {
  return DatingService().getUpgradeStatus();
});

final _exploreUsersProvider =
    FutureProvider.autoDispose.family<List<DatingExploreUser>, _ExploreQuery>(
  (ref, query) async {
    return DatingService().getExploreUsers(
      tab: query.tab,
      limit: query.limit,
      lat: query.lat,
      lon: query.lon,
      radiusKm: query.radiusKm,
      query: query.search,
      minAge: query.filters.minAge,
      maxAge: query.filters.maxAge,
      roles: query.filters.roles,
      tribes: query.filters.tribes,
      lookingFor: query.filters.lookingFor,
    );
  },
);

class _ExploreQuery {
  final String tab;
  final int limit;
  final double? lat;
  final double? lon;
  final int radiusKm;
  final String search;
  final DatingExploreFilters filters;

  const _ExploreQuery({
    required this.tab,
    this.limit = 180,
    this.lat,
    this.lon,
    this.radiusKm = 3,
    this.search = '',
    required this.filters,
  });

  @override
  bool operator ==(Object other) =>
      other is _ExploreQuery &&
      other.tab == tab &&
      other.limit == limit &&
      other.lat == lat &&
      other.lon == lon &&
      other.radiusKm == radiusKm &&
      other.search == search &&
      other.filters == filters;

  @override
  int get hashCode =>
      Object.hash(tab, limit, lat, lon, radiusKm, search, filters);
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class DatingScreen extends ConsumerStatefulWidget {
  const DatingScreen({super.key});

  @override
  ConsumerState<DatingScreen> createState() => _DatingScreenState();
}

class _DatingScreenState extends ConsumerState<DatingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ExploreTab(),
                DatingMeetScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searchText = ref.watch(_exploreSearchProvider);
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Title with tabs
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Colors.transparent,
                    dividerColor: Colors.transparent,
                    labelPadding: const EdgeInsets.only(right: 16),
                    tabs: [
                      _headerTab(l10n.datingExplore, 0),
                      _headerTab(l10n.datingMeet, 1),
                    ],
                  ),
                ),
                // Action buttons (only for Explore tab)
                if (_tabController.index == 0) ...[
                  _iconButton(
                    Icons.search,
                    onTap: _openSearchDialog,
                  ),
                  const SizedBox(width: 8),
                  _iconButton(
                    Icons.edit_outlined,
                    onTap: () => context.push('/main/profile/edit'),
                  ),
                ],
              ],
            ),
            if (_tabController.index == 0 && searchText.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    label: Text('${l10n.search}: "${searchText.trim()}"'),
                    onPressed: () =>
                        ref.read(_exploreSearchProvider.notifier).state = '',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearchDialog() async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(_exploreSearchProvider);
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.datingSearchProfiles),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.datingSearchHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(l10n.datingClear),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.search),
          ),
        ],
      ),
    );
    if (result != null) {
      ref.read(_exploreSearchProvider.notifier).state = result;
    }
  }

  Widget _headerTab(String label, int index) {
    final isSelected = _tabController.index == index;
    return Tab(
      child: Text(
        label,
        style: TextStyle(
          fontSize: isSelected ? 26 : 18,
          fontWeight: FontWeight.bold,
          color: isSelected
              ? (index == 1
                  ? const Color(0xFF8E44FF)
                  : Theme.of(context).textTheme.titleLarge?.color)
              : Colors.grey,
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withValues(alpha: 0.15),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

// ─── Explore Tab ─────────────────────────────────────────────────────────────

class _ExploreTab extends ConsumerStatefulWidget {
  const _ExploreTab();

  @override
  ConsumerState<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<_ExploreTab> {
  int _subtabIndex = 0; // 0=Smart/Nearby, 1=Online, 2=New Face
  double? _lat;
  double? _lon;
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    if (_locationLoading) return;
    setState(() => _locationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.datingEnableLocation)),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.datingLocationPermissionDenied)),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lon = position.longitude;
      });
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.datingLocationError}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final upgradeStatus = ref.watch(_upgradeStatusProvider).valueOrNull;
    final tier = upgradeStatus?.tier ?? 'FREE';
    final isVip = tier == 'VIP';
    final isUnlimited = tier == 'UNLIMITED';
    final visibleLimit =
        upgradeStatus?.viewLimit ?? (isUnlimited ? 100000 : (isVip ? 600 : 60));
    final fetchLimit =
        isUnlimited ? 1000 : (visibleLimit + 180).clamp(180, 1000);
    final filters = ref.watch(_exploreFiltersProvider);
    final search = ref.watch(_exploreSearchProvider);
    const effectiveRadius = 5000;
    final activeTab = _subtabIndex == 1 ? 'online' : 'nearby';
    final query = _ExploreQuery(
      tab: activeTab,
      limit: fetchLimit,
      lat: _lat,
      lon: _lon,
      radiusKm: effectiveRadius,
      search: search,
      filters: filters,
    );
    final usersAsync = ref.watch(_exploreUsersProvider(query));

    return Column(
      children: [
        _buildSubtabs(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  isUnlimited
                      ? '${l10n.datingPlanUnlimitedUnlocked} • ${l10n.datingUnlimitedProfileViews}'
                      : isVip
                          ? '${l10n.datingPlanVipUnlocked} • $visibleLimit'
                          : '${l10n.datingPlanFreeUnlocked} • $visibleLimit',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (_locationLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: _loadCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 14),
                  label: Text(l10n.datingUpdateLocation),
                ),
            ],
          ),
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (users) => users.isEmpty
                ? _buildEmpty()
                : _buildGrid(users, visibleLimit: visibleLimit),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtabs() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _subtab(l10n.datingSmart, 0),
                  const SizedBox(width: 8),
                  _subtab(l10n.online, 1),
                  const SizedBox(width: 8),
                  _subtab(l10n.datingNewFace, 2),
                ],
              ),
            ),
          ),
          // Filter icon
          GestureDetector(
            onTap: _openFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.tune, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtab(String label, int index) {
    final isSelected = _subtabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _subtabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.grey.withValues(alpha: 0.15),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<DatingExploreUser> users,
      {required int visibleLimit}) {
    final selfUsers = users.where((u) => u.isSelf).toList();
    final otherUsers = users.where((u) => !u.isSelf).toList();
    final visibleOthers = otherUsers.take(visibleLimit).toList();
    final lockedOthers = otherUsers.skip(visibleLimit).toList();
    final visibleUsers = [...selfUsers, ...visibleOthers];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_exploreUsersProvider),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _UserCard(
                  user: visibleUsers[index],
                  swipeProfileIds:
                      visibleUsers.map((user) => user.userId).toList(),
                  swipeProfileIndex: index,
                ),
                childCount: visibleUsers.length,
              ),
            ),
          ),
          if (lockedOthers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _UpgradeBanner(
                onTap: () async {
                  final upgraded = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DatingUpgradeScreen(),
                    ),
                  );
                  if (upgraded == true) {
                    ref.invalidate(_upgradeStatusProvider);
                    ref.invalidate(_exploreUsersProvider);
                  }
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _UserCard(
                    user: lockedOthers[index],
                    locked: true,
                  ),
                  childCount: lockedOthers.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            l10n.datingNoUsersNearby,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.datingAllowLocationAndTryAgain,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _openFilters() async {
    final current = ref.read(_exploreFiltersProvider);
    final result = await showModalBottomSheet<DatingExploreFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DatingFilterSheet(currentFilters: current),
    );
    if (result != null) {
      ref.read(_exploreFiltersProvider.notifier).state = result;
    }
  }
}

// ─── User Card ────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final DatingExploreUser user;
  final bool locked;
  final List<String>? swipeProfileIds;
  final int swipeProfileIndex;

  const _UserCard({
    required this.user,
    this.locked = false,
    this.swipeProfileIds,
    this.swipeProfileIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatarUrl = appendCacheBuster(user.avatarUrl, user.updatedAt);
    return GestureDetector(
      onTap: locked
          ? () async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.datingUnlockMoreProfilesBanner)),
              );
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DatingUpgradeScreen(),
                ),
              );
            }
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DatingProfileScreen(
                    userId: user.userId,
                    swipeProfileIds: swipeProfileIds,
                    swipeProfileIndex: swipeProfileIndex,
                  ),
                ),
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Avatar
            avatarUrl != null
                ? PresignedImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: _placeholder(),
                  )
                : _placeholder(),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            if (locked)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock, color: Colors.white, size: 24),
                ),
              ),

            // Online indicator
            if (user.isOnline == true || user.isOnline == false)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.isOnline == true
                        ? const Color(0xFF4CAF50)
                        : Colors.grey,
                  ),
                ),
              ),

            if (user.isSelf)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.datingYou,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),

            // Info
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.username?.isNotEmpty == true
                        ? user.username!
                        : user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (user.distanceKm != null)
                    Text(
                      [
                        if (user.distanceKm != null)
                          user.distanceKm == 0 ? '0m' : '${user.distanceKm}km',
                      ].join('  '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(Icons.person, color: Colors.white54, size: 40),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF0891B2)],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.datingUnlockMoreProfilesBanner,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter model ─────────────────────────────────────────────────────────────

class DatingExploreFilters {
  final int? minAge;
  final int? maxAge;
  final List<String> roles;
  final List<String> tribes;
  final List<String> lookingFor;

  const DatingExploreFilters({
    this.minAge,
    this.maxAge,
    this.roles = const [],
    this.tribes = const [],
    this.lookingFor = const [],
  });

  @override
  bool operator ==(Object other) =>
      other is DatingExploreFilters &&
      other.minAge == minAge &&
      other.maxAge == maxAge &&
      _listEq(other.roles, roles) &&
      _listEq(other.tribes, tribes) &&
      _listEq(other.lookingFor, lookingFor);

  @override
  int get hashCode => Object.hash(
      minAge, maxAge, roles.join(), tribes.join(), lookingFor.join());

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
