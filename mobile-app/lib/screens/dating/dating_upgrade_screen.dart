import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/dating_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dating_model.dart';

class DatingUpgradeScreen extends StatefulWidget {
  final int freeLimit;

  const DatingUpgradeScreen({
    super.key,
    this.freeLimit = 60,
  });

  @override
  State<DatingUpgradeScreen> createState() => _DatingUpgradeScreenState();
}

class _DatingUpgradeScreenState extends State<DatingUpgradeScreen> {
  final DatingService _datingService = DatingService();

  bool _loading = true;
  bool _purchasing = false;
  String? _error;
  DatingUpgradeStatus? _status;
  List<DatingUpgradePlan> _plans = [];
  String _selectedTier = 'VIP';
  String _selectedDuration = '1M';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _datingService.getUpgradeStatus(),
        _datingService.getUpgradePlans(),
      ]);

      final status = results[0] as DatingUpgradeStatus;
      final plans = results[1] as List<DatingUpgradePlan>;

      if (!mounted) return;

      final preferredTier = status.tier == 'UNLIMITED' ? 'UNLIMITED' : 'VIP';
      final preferredPlan = plans.firstWhere(
        (item) => item.tier == preferredTier,
        orElse: () => plans.first,
      );

      setState(() {
        _status = status;
        _plans = plans;
        _selectedTier = preferredPlan.tier;
        _selectedDuration = preferredPlan.durations.isNotEmpty
            ? preferredPlan.durations.first.key
            : '1M';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _purchase() async {
    if (_purchasing) return;

    final selectedPlan = _plans.firstWhere(
      (plan) => plan.tier == _selectedTier,
      orElse: () => _plans.first,
    );
    final selectedDuration = selectedPlan.durations.firstWhere(
      (item) => item.key == _selectedDuration,
      orElse: () => selectedPlan.durations.first,
    );

    final currentCoins = _status?.coinBalance ?? 0;
    if (currentCoins < selectedDuration.coins) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).datingNotEnoughCoins)),
      );
      context.push('/main/coin-recharge');
      return;
    }

    setState(() => _purchasing = true);
    try {
      final updated = await _datingService.purchaseUpgrade(
        tier: _selectedTier,
        duration: _selectedDuration,
      );

      if (!mounted) return;
      setState(() => _status = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updated.tier} ${AppLocalizations.of(context).datingActivatedSuccessfully}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).datingPurchaseFailed}: $e')),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.datingUpgradeTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadData,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedPlan = _plans.firstWhere(
      (item) => item.tier == _selectedTier,
      orElse: () => _plans.first,
    );
    final selectedDuration = selectedPlan.durations.firstWhere(
      (item) => item.key == _selectedDuration,
      orElse: () => selectedPlan.durations.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.datingUpgradeTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFEFF6FF),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.datingYourFreePreviewReached,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.datingFreeUsersViewFirst} (${widget.freeLimit})',
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.datingCurrentPlanCoins}: ${_status?.tier ?? 'FREE'} • ${_status?.coinBalance ?? 0}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PlanCard(
              title: 'VIP',
              subtitle: l10n.datingViewUpToProfiles,
              selected: _selectedTier == 'VIP',
              onTap: () {
                final vipPlan = _plans.firstWhere(
                  (item) => item.tier == 'VIP',
                  orElse: () => _plans.first,
                );
                setState(() {
                  _selectedTier = 'VIP';
                  _selectedDuration = vipPlan.durations.isNotEmpty
                      ? vipPlan.durations.first.key
                      : _selectedDuration;
                });
              },
              benefits: [
                l10n.datingSeeNearbyProfiles,
                l10n.datingAiMatchingSuggestions,
                l10n.datingPriorityDiscovery,
              ],
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 12),
            _PlanCard(
              title: 'UNLIMITED',
              subtitle: l10n.datingUnlimitedProfileViews,
              selected: _selectedTier == 'UNLIMITED',
              onTap: () {
                final unlimitedPlan = _plans.firstWhere(
                  (item) => item.tier == 'UNLIMITED',
                  orElse: () => _plans.first,
                );
                setState(() {
                  _selectedTier = 'UNLIMITED';
                  _selectedDuration = unlimitedPlan.durations.isNotEmpty
                      ? unlimitedPlan.durations.first.key
                      : _selectedDuration;
                });
              },
              benefits: [
                l10n.datingUnlimitedNearbyBrowsing,
                l10n.datingBestAiQuality,
                l10n.datingHighestPriorityVisibility,
              ],
              color: Color(0xFF0891B2),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.datingAvailableDurations,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedPlan.durations
                  .map(
                    (item) => _DurationChip(
                      label: item.label,
                      selected: _selectedDuration == item.key,
                      onTap: () => setState(() => _selectedDuration = item.key),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _purchasing ? null : _purchase,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _purchasing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('${l10n.datingPurchaseCoins} • ${selectedDuration.coins} ${l10n.coins}'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/main/coin-recharge'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.datingRechargeCoins),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> benefits;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.benefits,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.1),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...benefits.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFDBEAFE),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
    );
  }
}
