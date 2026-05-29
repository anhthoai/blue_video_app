import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dating_model.dart';
import '../../core/theme/app_theme.dart';
import 'dating_screen.dart';

class DatingFilterSheet extends StatefulWidget {
  final DatingExploreFilters currentFilters;
  const DatingFilterSheet({super.key, required this.currentFilters});

  @override
  State<DatingFilterSheet> createState() => _DatingFilterSheetState();
}

class _DatingFilterSheetState extends State<DatingFilterSheet> {
  late RangeValues _ageRange;
  late List<String> _selectedRoles;
  late List<String> _selectedTribes;
  late List<String> _selectedLookingFor;

  @override
  void initState() {
    super.initState();
    _ageRange = RangeValues(
      (widget.currentFilters.minAge ?? 18).toDouble(),
      (widget.currentFilters.maxAge ?? 60).toDouble(),
    );
    _selectedRoles = List.from(widget.currentFilters.roles);
    _selectedTribes = List.from(widget.currentFilters.tribes);
    _selectedLookingFor = List.from(widget.currentFilters.lookingFor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.grey.shade400,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      l10n.datingFilters,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        _ageRange = const RangeValues(18, 60);
                        _selectedRoles.clear();
                        _selectedTribes.clear();
                        _selectedLookingFor.clear();
                      }),
                      child: Text(l10n.datingReset),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAgeSection(),
                      const SizedBox(height: 24),
                      _buildChipSection(
                        l10n.datingRole,
                        DatingConstants.roles,
                        DatingConstants.roleLabels,
                        _selectedRoles,
                        multiSelect: true,
                      ),
                      const SizedBox(height: 24),
                      _buildChipSection(
                        l10n.datingLookingFor,
                        DatingConstants.lookingForOptions,
                        DatingConstants.lookingForLabels,
                        _selectedLookingFor,
                        multiSelect: true,
                      ),
                      const SizedBox(height: 24),
                      _buildChipSection(
                        '${l10n.datingTribes} (max 3)',
                        DatingConstants.tribes,
                        DatingConstants.tribeLabels,
                        _selectedTribes,
                        multiSelect: true,
                        maxSelect: 3,
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.datingApplyFilters,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAgeSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.datingAge}: ${_ageRange.start.toInt()} – ${_ageRange.end.toInt()}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        RangeSlider(
          values: _ageRange,
          min: 18,
          max: 80,
          divisions: 62,
          activeColor: AppTheme.primaryColor,
          onChanged: (v) => setState(() => _ageRange = v),
        ),
      ],
    );
  }

  Widget _buildChipSection(
    String title,
    List<String> options,
    Map<String, String> labels,
    List<String> selected, {
    bool multiSelect = false,
    int? maxSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  selected.remove(opt);
                } else {
                  if (maxSelect != null && selected.length >= maxSelect) return;
                  if (!multiSelect) selected.clear();
                  selected.add(opt);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.withOpacity(0.15),
                ),
                child: Text(
                  labels[opt] ?? opt,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _apply() {
    Navigator.pop(
      context,
      DatingExploreFilters(
        minAge: _ageRange.start.toInt() == 18 ? null : _ageRange.start.toInt(),
        maxAge: _ageRange.end.toInt() == 60 ? null : _ageRange.end.toInt(),
        roles: List.from(_selectedRoles),
        tribes: List.from(_selectedTribes),
        lookingFor: List.from(_selectedLookingFor),
      ),
    );
  }
}
