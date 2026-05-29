import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/dating_service.dart';
import '../../models/dating_model.dart';
import '../../core/theme/app_theme.dart';

class DatingProfileEditScreen extends ConsumerStatefulWidget {
  final DatingProfile? existing;
  const DatingProfileEditScreen({super.key, this.existing});

  @override
  ConsumerState<DatingProfileEditScreen> createState() =>
      _DatingProfileEditScreenState();
}

class _DatingProfileEditScreenState
    extends ConsumerState<DatingProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Personal info
  DateTime? _dateOfBirth;
  String? _role;
  int? _heightCm;
  int? _weightKg;
  String? _bodyType;
  String? _bodyHair;
  List<String> _languages = [];
  final _whereILiveCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  String? _ethnicity;
  String? _relationshipStatus;

  // Expectations
  List<String> _lookingFor = [];
  List<String> _whereToMeet = [];
  List<String> _preferredTribes = [];

  // Privacy & Settings
  bool _showDistance = true;
  bool _showOnline = true;
  bool _aiMatchingEnabled = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _applyProfile(p);
    } else {
      _loadExistingProfile();
    }
  }

  void _applyProfile(DatingProfile p) {
    _dateOfBirth = p.dateOfBirth;
    _role = p.role;
    _heightCm = p.heightCm;
    _weightKg = p.weightKg;
    _bodyType = p.bodyType;
    _bodyHair = p.bodyHair;
    _languages = List.from(p.languages);
    _whereILiveCtrl.text = p.whereILive ?? '';
    _nationalityCtrl.text = p.nationality ?? '';
    _ethnicity = p.ethnicity;
    _relationshipStatus = p.relationshipStatus;
    _lookingFor = List.from(p.lookingFor);
    _whereToMeet = List.from(p.whereToMeet);
    _preferredTribes = List.from(p.preferredTribes);
    _showDistance = p.showDistance;
    _showOnline = p.showOnline;
    _aiMatchingEnabled = p.aiMatchingEnabled;
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await DatingService().getMyDatingProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _applyProfile(profile);
      });
    } catch (_) {
      // Ignore load errors here; user can still create a new profile.
    }
  }

  @override
  void dispose() {
    _whereILiveCtrl.dispose();
    _nationalityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    setState(() => _saving = true);
    try {
      await DatingService().updateDatingProfile({
        if (_dateOfBirth != null)
          'dateOfBirth': _dateOfBirth!.toIso8601String(),
        if (_role != null) 'role': _role,
        if (_heightCm != null) 'heightCm': _heightCm,
        if (_weightKg != null) 'weightKg': _weightKg,
        if (_bodyType != null) 'bodyType': _bodyType,
        if (_bodyHair != null) 'bodyHair': _bodyHair,
        'languages': _languages,
        if (_whereILiveCtrl.text.trim().isNotEmpty)
          'whereILive': _whereILiveCtrl.text.trim(),
        if (_nationalityCtrl.text.trim().isNotEmpty)
          'nationality': _nationalityCtrl.text.trim(),
        if (_ethnicity != null) 'ethnicity': _ethnicity,
        if (_relationshipStatus != null)
          'relationshipStatus': _relationshipStatus,
        'lookingFor': _lookingFor,
        'whereToMeet': _whereToMeet,
        'preferredTribes': _preferredTribes,
        'showDistance': _showDistance,
        'showOnline': _showOnline,
        'aiMatchingEnabled': _aiMatchingEnabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved!')),
        );
        Navigator.pop(context, true); // signal parent to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (_saving) {
      return false;
    }
    await _save();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Dating Profile'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              TextButton(
                onPressed: _save,
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              _sectionHeader('Personal Information'),
              const SizedBox(height: 16),
              _buildDobField(),
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'Role',
                value: _role,
                options: DatingConstants.roles,
                labels: DatingConstants.roleLabels,
                onChanged: (v) => setState(() => _role = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      label: 'Height (cm)',
                      value: _heightCm,
                      onChanged: (v) => setState(() => _heightCm = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNumberField(
                      label: 'Weight (kg)',
                      value: _weightKg,
                      onChanged: (v) => setState(() => _weightKg = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'Body Type',
                value: _bodyType,
                options: DatingConstants.bodyTypes,
                labels: DatingConstants.bodyTypeLabels,
                onChanged: (v) => setState(() => _bodyType = v),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'Body Hair',
                value: _bodyHair,
                options: DatingConstants.bodyHairs,
                labels: DatingConstants.bodyHairLabels,
                onChanged: (v) => setState(() => _bodyHair = v),
              ),
              const SizedBox(height: 16),
              _buildMultiChip(
                label: 'Languages',
                options: DatingConstants.languages,
                selected: _languages,
                onChanged: (v) => setState(() => _languages = v),
                labelMap: {for (final l in DatingConstants.languages) l: l},
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whereILiveCtrl,
                decoration: _inputDecoration('Where I Live'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nationalityCtrl,
                decoration: _inputDecoration('Nationality'),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'Ethnicity',
                value: _ethnicity,
                options: DatingConstants.ethnicities,
                labels: DatingConstants.ethnicityLabels,
                onChanged: (v) => setState(() => _ethnicity = v),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'Relationship Status',
                value: _relationshipStatus,
                options: DatingConstants.relationshipStatuses,
                labels: DatingConstants.relationshipStatusLabels,
                onChanged: (v) => setState(() => _relationshipStatus = v),
              ),

              const SizedBox(height: 32),
              _sectionHeader('Expectations'),
              const SizedBox(height: 16),
              _buildMultiChip(
                label: 'Looking For',
                options: DatingConstants.lookingForOptions,
                labelMap: DatingConstants.lookingForLabels,
                selected: _lookingFor,
                onChanged: (v) => setState(() => _lookingFor = v),
              ),
              const SizedBox(height: 16),
              _buildMultiChip(
                label: 'Where to Meet',
                options: DatingConstants.whereToMeetOptions,
                labelMap: DatingConstants.whereToMeetLabels,
                selected: _whereToMeet,
                onChanged: (v) => setState(() => _whereToMeet = v),
              ),
              const SizedBox(height: 16),
              _buildMultiChip(
                label: 'Preferred Tribes (max 3)',
                options: DatingConstants.tribes,
                selected: _preferredTribes,
                onChanged: (v) => setState(() => _preferredTribes = v),
                maxSelect: 3,
                labelMap: DatingConstants.tribeLabels,
              ),

              const SizedBox(height: 32),
              _sectionHeader('Privacy & Settings'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Distance'),
                subtitle: const Text('Let others see how far you are'),
                value: _showDistance,
                onChanged: (v) => setState(() => _showDistance = v),
                activeColor: AppTheme.primaryColor,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Online Status'),
                value: _showOnline,
                onChanged: (v) => setState(() => _showOnline = v),
                activeColor: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withOpacity(0.15),
                      AppTheme.primaryColor.withOpacity(0.15),
                    ],
                  ),
                ),
                child: SwitchListTile(
                  title: const Row(
                    children: [
                      Text('⭐ AI Matching'),
                      SizedBox(width: 8),
                      _VipBadge(),
                    ],
                  ),
                  subtitle: const Text(
                      'Let AI find the best matches for you (VIP only)'),
                  value: _aiMatchingEnabled,
                  onChanged: (v) => setState(() => _aiMatchingEnabled = v),
                  activeColor: const Color(0xFFFFD700),
                ),
              ),

              const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDobField() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate:
              _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
          firstDate: DateTime(1940),
          lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
          helpText: 'Select Date of Birth',
        );
        if (picked != null) setState(() => _dateOfBirth = picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration('Date of Birth *'),
        child: Text(
          _dateOfBirth != null
              ? DateFormat.yMMMMd().format(_dateOfBirth!)
              : 'Tap to select',
          style: TextStyle(
            color: _dateOfBirth != null ? null : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required Map<String, String> labels,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label),
      items: [
        DropdownMenuItem<String>(value: null, child: Text('Select $label')),
        ...options.map((o) => DropdownMenuItem(
              value: o,
              child: Text(labels[o] ?? o),
            )),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildNumberField({
    required String label,
    required int? value,
    required void Function(int?) onChanged,
  }) {
    return TextFormField(
      initialValue: value?.toString(),
      keyboardType: TextInputType.number,
      decoration: _inputDecoration(label),
      onChanged: (v) => onChanged(int.tryParse(v)),
    );
  }

  Widget _buildMultiChip({
    required String label,
    required List<String> options,
    required List<String> selected,
    required void Function(List<String>) onChanged,
    int? maxSelect,
    Map<String, String>? labelMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            final displayLabel = labelMap?[opt] ?? opt;
            return GestureDetector(
              onTap: () {
                final copy = List<String>.from(selected);
                if (isSelected) {
                  copy.remove(opt);
                } else {
                  if (maxSelect != null && copy.length >= maxSelect) return;
                  copy.add(opt);
                }
                onChanged(copy);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.withOpacity(0.15),
                ),
                child: Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
        ),
      ),
      child: const Text(
        'VIP',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
