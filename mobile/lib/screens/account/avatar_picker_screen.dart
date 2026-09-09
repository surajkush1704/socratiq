import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../services/sync_service.dart';
import '../../widgets/socratiq_avatar.dart';

class AvatarPickerScreen extends StatefulWidget {
  /// The currently active avatarId (0 = none).
  final int currentAvatarId;

  /// Non-null if user has a Google profile photo — enables "Use Google Photo".
  final String? photoUrl;

  const AvatarPickerScreen({
    super.key,
    this.currentAvatarId = 0,
    this.photoUrl,
  });

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  late int _selectedId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentAvatarId;
  }

  Future<void> _onSelect() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Attempt client Firestore write (may be restricted by client security rules)
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'avatarId': _selectedId}, SetOptions(merge: true));
        } catch (fsErr) {
          debugPrint('[AVATAR_PICKER] Client Firestore write ignored: $fsErr');
        }

        // 2. Sync to backend (backend Admin SDK securely writes to Firestore)
        await SyncService.syncProfile(avatarId: _selectedId);
      }

      if (mounted) {
        Navigator.pop(context, _selectedId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save avatar: $e',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  void _revertToGooglePhoto() {
    setState(() => _selectedId = 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: AppTheme.dynamicText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CHOOSE AVATAR',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.2,
            color: AppTheme.dynamicText(context),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Subtitle
                    Text(
                      'Pick a personality that matches your study style.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppTheme.dynamicSecondaryText(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── AVATAR GRID ──────────────────────────────────────────
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: kAvatars.length,
                      itemBuilder: (context, index) {
                        final avatar = kAvatars[index];
                        final isSelected = _selectedId == avatar.id;
                        return _AvatarCell(
                          avatar: avatar,
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedId = avatar.id),
                        );
                      },
                    ),

                    // ── USE GOOGLE PHOTO OPTION ──────────────────────────────
                    if (widget.photoUrl != null &&
                        widget.photoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton.icon(
                          onPressed: _revertToGooglePhoto,
                          icon: CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(widget.photoUrl!),
                          ),
                          label: Text(
                            'Use Google Photo instead',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      if (_selectedId == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Center(
                            child: Text(
                              'Google Photo will be used ✓',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppTheme.success,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // ── SELECT BUTTON ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: AppTheme.buttonShadow,
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Select',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AVATAR GRID CELL ──────────────────────────────────────────────────────────

class _AvatarCell extends StatelessWidget {
  final AvatarData avatar;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _AvatarCell({
    required this.avatar,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circle + selection ring + checkmark badge
          Stack(
            alignment: Alignment.bottomRight,
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: AppTheme.primaryBlue, width: 3)
                      : Border.all(color: Colors.transparent, width: 3),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.30),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: SocratiqAvatar(
                  size: 80,
                  avatarId: avatar.id,
                ),
              ),
              if (isSelected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Avatar label
          Text(
            avatar.label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? AppTheme.primaryBlue
                  : AppTheme.dynamicSecondaryText(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
