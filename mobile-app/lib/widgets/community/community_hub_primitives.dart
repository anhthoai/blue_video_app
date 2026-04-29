import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CommunityAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const CommunityAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _paletteFor(name);
    final diameter = radius * 2;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Text(
        initialsForName(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

String initialsForName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }

  final pieces = trimmed.split(RegExp(r'\s+'));
  if (pieces.length == 1) {
    return pieces.first.substring(0, 1).toUpperCase();
  }

  return (pieces.first.substring(0, 1) + pieces.last.substring(0, 1)).toUpperCase();
}

String formatCompactNumber(int value) {
  return NumberFormat.compact().format(value);
}

String formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) {
    return 'Just now';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }
  return DateFormat('MMM d').format(dateTime);
}

List<Color> _paletteFor(String seed) {
  final palettes = <List<Color>>[
    const <Color>[Color(0xFF6D5EF7), Color(0xFF46C2FF)],
    const <Color>[Color(0xFFFF7A59), Color(0xFFFFC56B)],
    const <Color>[Color(0xFF38B48B), Color(0xFF7BE0B3)],
    const <Color>[Color(0xFFFF4FA0), Color(0xFFFF8F70)],
    const <Color>[Color(0xFF5367FF), Color(0xFF8BCBFF)],
  ];

  final codeUnits = seed.codeUnits;
  var sum = 0;
  for (final unit in codeUnits) {
    sum += unit;
  }

  return palettes[sum % palettes.length];
}
