import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

// ── AVATAR DATA ───────────────────────────────────────────────────────────────

class AvatarData {
  final int id;
  final String emoji;
  final Color background;
  final String label;

  const AvatarData({
    required this.id,
    required this.emoji,
    required this.background,
    required this.label,
  });
}

const List<AvatarData> kAvatars = [
  AvatarData(id: 1,  emoji: '🦉', background: Color(0xFF1E3A8A), label: 'The Scholar'),
  AvatarData(id: 2,  emoji: '🚀', background: Color(0xFF7C3AED), label: 'The Explorer'),
  AvatarData(id: 3,  emoji: '🔬', background: Color(0xFF0F766E), label: 'The Scientist'),
  AvatarData(id: 4,  emoji: '📚', background: Color(0xFFC2410C), label: 'The Reader'),
  AvatarData(id: 5,  emoji: '🌱', background: Color(0xFF166534), label: 'The Learner'),
  AvatarData(id: 6,  emoji: '⭐', background: Color(0xFF1E293B), label: 'The Achiever'),
  AvatarData(id: 7,  emoji: '🎯', background: Color(0xFFBE185D), label: 'The Focus'),
  AvatarData(id: 8,  emoji: '💡', background: Color(0xFFA16207), label: 'The Thinker'),
  AvatarData(id: 9,  emoji: '🏆', background: Color(0xFF991B1B), label: 'The Champion'),
  AvatarData(id: 10, emoji: '🧠', background: Color(0xFF3730A3), label: 'The Mind'),
  AvatarData(id: 11, emoji: '⚡', background: Color(0xFF0E7490), label: 'The Quick'),
  AvatarData(id: 12, emoji: '🔭', background: Color(0xFF334155), label: 'The Visionary'),
];

AvatarData? avatarById(int id) {
  if (id < 1 || id > 12) return null;
  return kAvatars[id - 1];
}

// ── SOCRATIQ AVATAR WIDGET ────────────────────────────────────────────────────

/// Renders a circular avatar with the following priority:
///   1. Custom avatar (avatarId 1-12) — coloured circle + emoji
///   2. Google photo (photoUrl non-null) — NetworkImage CircleAvatar
///   3. Initials fallback — primaryGradient circle + first letter
///
/// [size]        — diameter of the circle in logical pixels
/// [avatarId]    — 1-12 for a custom avatar, 0 or null for none
/// [photoUrl]    — Google profile photo URL (can be null)
/// [displayName] — used for the initials fallback
class SocratiqAvatar extends StatelessWidget {
  final double size;
  final int avatarId;
  final String? photoUrl;
  final String displayName;

  const SocratiqAvatar({
    super.key,
    required this.size,
    this.avatarId = 0,
    this.photoUrl,
    this.displayName = '',
  });

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final data = avatarById(avatarId);

    // Priority 1: custom avatar
    if (data != null) {
      return _CustomAvatar(data: data, size: size);
    }

    // Priority 2: Google photo
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }

    // Priority 3: initials
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'S';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.dmSans(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

class _CustomAvatar extends StatelessWidget {
  final AvatarData data;
  final double size;

  const _CustomAvatar({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: data.background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        data.emoji,
        style: TextStyle(fontSize: size * 0.46, height: 1.0),
        textAlign: TextAlign.center,
      ),
    );
  }
}
