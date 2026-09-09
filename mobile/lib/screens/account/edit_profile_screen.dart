import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../services/sync_service.dart';
import '../../widgets/socratiq_avatar.dart';
import 'avatar_picker_screen.dart';
import '../../widgets/app_page_route.dart';
import '../../widgets/swipe_back_wrapper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _nameError;
  String? _usernameError;
  int _usernameLength = 0;
  int _avatarId = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
    _usernameController.addListener(() {
      setState(() {
        _usernameLength = _usernameController.text.length;
        _usernameError = null;
      });
    });
    _nameController.addListener(() {
      if (_nameError != null) {
        setState(() => _nameError = null);
      }
    });
  }

  Future<void> _loadCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
    }

    try {
      if (user != null) {
        // Try backend API first (uses Firebase Admin, bypasses client permission rules)
        final profile = await SyncService.getProfile(user.uid);
        if (profile.isNotEmpty) {
          final username = profile['username'] as String? ?? '';
          _usernameController.text = username.replaceAll('@', '');
          _avatarId = (profile['avatarId'] as num?)?.toInt() ?? 0;
        } else {
          // Fallback to client Firestore query if backend returned null
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;
              final username = data['username'] as String? ?? '';
              _usernameController.text = username.replaceAll('@', '');
              _avatarId = (data['avatarId'] as num?)?.toInt() ?? 0;
            }
          } catch (fsErr) {
            debugPrint('[EDIT_PROFILE] Client Firestore read ignored: $fsErr');
          }
        }
      }
    } catch (e) {
      debugPrint('[EDIT_PROFILE] Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _usernameLength = _usernameController.text.length;
          _isLoading = false;
        });
      }
    }
  }

  void _onAvatarTap() async {
    final user = FirebaseAuth.instance.currentUser;
    final result = await Navigator.push<int>(
      context,
      AppPageRoute(
        builder: (_) => AvatarPickerScreen(
          currentAvatarId: _avatarId,
          photoUrl: user?.photoURL,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _avatarId = result);
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final rawUsername = _usernameController.text.trim().replaceAll('@', '');

    // Validate Display Name
    if (name.isEmpty) {
      setState(() => _nameError = 'Display Name is required');
      return;
    }
    if (name.length > 30) {
      setState(() => _nameError = 'Maximum 30 characters allowed');
      return;
    }

    // Validate Username
    if (rawUsername.isNotEmpty) {
      final validRegex = RegExp(r'^[a-zA-Z0-9_]+$');
      if (!validRegex.hasMatch(rawUsername)) {
        setState(() => _usernameError =
            'Only letters, numbers, and underscores allowed');
        return;
      }
      if (rawUsername.length > 20) {
        setState(() => _usernameError = 'Maximum 20 characters allowed');
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _nameError = null;
      _usernameError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Update Firebase Display Name
        await user.updateDisplayName(name);
        await user.reload();

        // 2. Attempt client Firestore write (may be restricted by client security rules)
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'name': name,
            'username': rawUsername,
            'avatarId': _avatarId,
            'lastActive': DateTime.now().toUtc().toIso8601String(),
          }, SetOptions(merge: true));
        } catch (fsErr) {
          debugPrint('[EDIT_PROFILE] Client Firestore write ignored: $fsErr');
        }

        // 3. Update backend profile via POST /sync/profile (uses Firebase Admin SDK)
        await SyncService.syncProfile(
          name: name,
          username: rawUsername,
          avatarId: _avatarId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('[EDIT_PROFILE] Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile: $e',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final user = FirebaseAuth.instance.currentUser;
    final photo = user?.photoURL;
    final currentDisplayName = user?.displayName ?? 'User';

    return SwipeBackWrapper(
      fallbackRoute: '/profile',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.dynamicText(context),
            ),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/profile');
              }
            },
          ),
          title: Text(
            'EDIT PROFILE',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 1.2,
            color: AppTheme.dynamicText(context),
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),

                            // ── AVATAR SECTION ─────────────────────────────
                            GestureDetector(
                              onTap: _onAvatarTap,
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      SocratiqAvatar(
                                        size: 92,
                                        avatarId: _avatarId,
                                        photoUrl: photo,
                                        displayName: currentDisplayName,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.dynamicCard(context),
                                            width: 2.5,
                                          ),
                                          boxShadow: isDark
                                              ? null
                                              : AppTheme.cardShadow,
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Edit',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── FIELD 1: DISPLAY NAME ──────────────────────
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Display Name',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.dynamicText(context),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.dynamicCard(context),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMedium),
                                border: Border.all(
                                  color: _nameError != null
                                      ? AppTheme.error
                                      : (isDark
                                          ? AppTheme.darkCardBorder
                                          : AppTheme.divider),
                                ),
                                boxShadow: isDark ? null : AppTheme.cardShadow,
                              ),
                              child: TextField(
                                controller: _nameController,
                                maxLength: 30,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.dynamicText(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'How should I call you?',
                                  hintStyle: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: AppTheme.dynamicSecondaryText(context),
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_nameError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _nameError!,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),

                            // ── FIELD 2: USERNAME ──────────────────────────
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Username',
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppTheme.dynamicText(context),
                                    ),
                                  ),
                                  Text(
                                    'Optional',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: AppTheme.dynamicSecondaryText(
                                          context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.dynamicCard(context),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMedium),
                                border: Border.all(
                                  color: _usernameError != null
                                      ? AppTheme.error
                                      : (isDark
                                          ? AppTheme.darkCardBorder
                                          : AppTheme.divider),
                                ),
                                boxShadow: isDark ? null : AppTheme.cardShadow,
                              ),
                              child: TextField(
                                controller: _usernameController,
                                maxLength: 20,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9_]')),
                                ],
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.dynamicText(context),
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16, right: 6),
                                    child: Text(
                                      '@',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                      minWidth: 0, minHeight: 0),
                                  hintText: 'yourusername',
                                  hintStyle: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: AppTheme.dynamicSecondaryText(context),
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (_usernameError != null)
                                    Expanded(
                                      child: Text(
                                        _usernameError!,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          color: AppTheme.error,
                                        ),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: Text(
                                        'Only letters, numbers, and underscores',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: AppTheme.dynamicSecondaryText(
                                              context),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '$_usernameLength/20',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: _usernameLength > 20
                                          ? AppTheme.error
                                          : AppTheme.dynamicSecondaryText(
                                              context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── BOTTOM SAVE CHANGES BUTTON ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                          boxShadow: AppTheme.buttonShadow,
                        ),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
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
                                  'Save changes',
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
      ),
    );
  }
}
