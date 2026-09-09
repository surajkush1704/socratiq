import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/google_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;

  int _rateLimitCountdown = 0;
  bool _isRateLimited = false;

  String _captchaCode = '';

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _generateCaptcha() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = math.Random();
    final buffer = StringBuffer();
    for (int i = 0; i < 5; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    setState(() {
      _captchaCode = buffer.toString();
      _captchaController.clear();
    });
  }

  void _startRateLimitCountdown(int seconds) {
    setState(() {
      _rateLimitCountdown = seconds;
      _isRateLimited = true;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _rateLimitCountdown--);
      if (_rateLimitCountdown <= 0) {
        setState(() => _isRateLimited = false);
        return false;
      }
      return true;
    });
  }

  Future<void> _handleGoogle() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.signInWithGoogle();
      if (result != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (e is AuthRateLimitException) {
          _startRateLimitCountdown(e.retryAfterSeconds);
          _showError(e.message);
        } else if (errStr.contains('10') ||
            errStr.contains('developer_error') ||
            errStr.contains('sha-1')) {
          _showError('Google Sign-In configuration error: SHA-1 fingerprint needs to be added in Firebase Console.');
        } else if (errStr.contains('12500')) {
          _showError('Google Play Services error (12500). Please check your Google account settings.');
        } else if (errStr.contains('network') || errStr.contains('7')) {
          _showError('Network error connecting to Google. Please check your internet connection.');
        } else if (errStr.contains('sign_in_canceled') ||
            errStr.contains('sign_in_cancelled') ||
            errStr.contains('12501')) {
          // User deliberately cancelled the popup, do not show error
        } else {
          final cleanMsg = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('PlatformException(', '')
              .split(',')
              .first;
          _showError('Google sign in failed: $cleanMsg');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (_isSignUp) {
      final enteredCaptcha = _captchaController.text.trim().toUpperCase();
      if (enteredCaptcha.isEmpty) {
        _showError('Please solve the captcha verification.');
        return;
      }
      if (enteredCaptcha != _captchaCode) {
        _generateCaptcha();
        _showError('Incorrect captcha code. Please try the new code.');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final result = _isSignUp
          ? await AuthService.signUpWithEmail(email, password)
          : await AuthService.signInWithEmail(email, password);
      if (result != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        if (_isSignUp) _generateCaptcha();
        if (e is AuthRateLimitException) {
          _startRateLimitCountdown(e.retryAfterSeconds);
          _showError(e.message);
        } else if (e.toString().contains('wrong-password') ||
            e.toString().contains('user-not-found') ||
            e.toString().contains('invalid-credential')) {
          _showError('Invalid email or password.');
        } else if (e.toString().contains('email-already-in-use')) {
          _showError('An account already exists with this email.');
        } else if (e.toString().contains('weak-password')) {
          _showError('Password should be at least 6 characters.');
        } else if (e.toString().contains('invalid-email')) {
          _showError('Please enter a valid email address.');
        } else {
          _showError('Authentication failed. Please try again.');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
    ));
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordSheet(
        initialEmail: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColor = AppTheme.dynamicDivider(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(gradient: AppTheme.dynamicAuroraGradient(context)),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0.0, constraints.maxHeight - 56),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Top Middle Brand Section
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'SocratiQ',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 38,
                                  color: textCol,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your personal AI tutor awaits.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: secCol,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Glass card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusLarge),
                            border: Border.all(color: borderColor),
                            boxShadow: isDark ? [] : AppTheme.glassShadow,
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isSignUp ? 'Create account' : 'Welcome',
                                style: GoogleFonts.dmSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textCol,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Google button
                              GestureDetector(
                                onTap: (_loading || _isRateLimited) ? null : _handleGoogle,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkBackgroundAlt : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusPill),
                                    boxShadow: isDark ? [] : AppTheme.cardShadow,
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const GoogleLogo(size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Continue with Google',
                                        style: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: textCol,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: borderColor)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      'or',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: secCol,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: borderColor)),
                                ],
                              ),
                              const SizedBox(height: 18),
                              // Email
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.dmSans(color: textCol),
                                decoration: InputDecoration(
                                  hintText: 'Email address',
                                  prefixIcon: Icon(Icons.mail_outline_rounded,
                                      color: secCol, size: 20),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Password
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.dmSans(color: textCol),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded,
                                      color: secCol, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: secCol,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                              ),
                              // Captcha only on Sign Up
                              if (_isSignUp) ...[
                                const SizedBox(height: 12),
                                _buildCaptchaWidget(
                                    isDark, borderColor, textCol, secCol),
                              ],
                              if (!_isSignUp) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordSheet,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot password?',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              // Submit button
                              GestureDetector(
                                onTap: (_loading || _isRateLimited) ? null : _handleEmail,
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: (_loading || _isRateLimited)
                                        ? LinearGradient(colors: [
                                            AppTheme.primaryBlue.withValues(alpha: 0.5),
                                            AppTheme.primaryBlue.withValues(alpha: 0.5),
                                          ])
                                        : AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusPill),
                                    boxShadow: (_loading || _isRateLimited)
                                        ? []
                                        : AppTheme.buttonShadow,
                                  ),
                                  child: Center(
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _isRateLimited
                                                ? 'Wait ${_rateLimitCountdown}s'
                                                : (_isSignUp
                                                    ? 'Create account'
                                                    : 'Login'),
                                            style: GoogleFonts.dmSans(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Toggle sign-up
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    if (_isSignUp) _generateCaptcha();
                                  });
                                },
                                child: Text(
                                  _isSignUp
                                      ? 'Already have an account? Sign in'
                                      : 'Don\'t have an account? Sign up',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptchaWidget(
      bool isDark, Color borderColor, Color textCol, Color secCol) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF0891B2),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFF059669),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkCardBorder
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: CustomPaint(
                  painter: _CaptchaBackgroundPainter(
                    seed: _captchaCode.hashCode,
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_captchaCode.length, (i) {
                        final char = _captchaCode[i];
                        final color = colors[i % colors.length];
                        final tilt = ((i % 3) - 1) * 0.12;
                        return Transform.rotate(
                          angle: tilt,
                          child: Text(
                            char,
                            style: GoogleFonts.dmSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4,
                              color: color,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkBackgroundAlt
                    : AppTheme.background,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: borderColor),
              ),
              child: IconButton(
                onPressed: _generateCaptcha,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppTheme.primaryBlue,
                tooltip: 'Get new captcha',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _captchaController,
          hint: 'Enter captcha code above',
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    final isDark = AppTheme.isDark(context);
    final borderColor = AppTheme.dynamicDivider(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackgroundAlt : AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.dmSans(
            fontSize: 14, color: textCol),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(
              fontSize: 14, color: secCol),
          prefixIcon: Icon(icon, color: secCol, size: 18),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _CaptchaBackgroundPainter extends CustomPainter {
  final int seed;
  final bool isDark;

  _CaptchaBackgroundPainter({required this.seed, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.08)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      path.moveTo(0, rand.nextDouble() * size.height);
      path.quadraticBezierTo(
        size.width / 2,
        rand.nextDouble() * size.height,
        size.width,
        rand.nextDouble() * size.height,
      );
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CaptchaBackgroundPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.isDark != isDark;
}

// ── FORGOT PASSWORD MODAL WITH 10-MINUTE COUNTDOWN ────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _resetEmailController;
  bool _loading = false;
  bool _sent = false;
  int _secondsRemaining = 0;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resetEmailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resetEmailController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 600; // 10 minutes
      _sent = true;
      _errorMessage = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handleSendReset() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.sendPasswordResetEmail(email);
      if (mounted) {
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('user-not-found')) {
            _errorMessage = 'No user found with this email address.';
          } else if (e.toString().contains('invalid-email')) {
            _errorMessage = 'Please enter a valid email address.';
          } else {
            _errorMessage = 'Failed to send reset link. Please try again.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.dynamicCard(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);
    final borderColor = AppTheme.dynamicDivider(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge),
          ),
          border: Border.all(color: borderColor),
          boxShadow: isDark ? [] : AppTheme.glassShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon + Title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset password',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: textCol,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'We\'ll email you a recovery link',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: secCol,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                      color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (!_sent) ...[
              Text(
                'Enter your email address and we will send you a password reset link valid for 10 minutes.',
                style: GoogleFonts.dmSans(fontSize: 13, color: secCol),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackgroundAlt
                      : AppTheme.background,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _resetEmailController,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: textCol),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    hintStyle: GoogleFonts.dmSans(
                        fontSize: 14, color: secCol),
                    prefixIcon: Icon(Icons.email_outlined,
                        color: secCol, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _loading ? null : _handleSendReset,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: AppTheme.buttonShadow,
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Send reset link',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ] else ...[
              // Live countdown card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF0FDF4),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.success.withOpacity(0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_read_rounded,
                            color: AppTheme.success,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset link sent!',
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textCol,
                                ),
                              ),
                              Text(
                                _resetEmailController.text.trim(),
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: secCol,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Link valid for:',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: secCol,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue
                                .withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(999),
                          ),
                          child: Text(
                            _formatTime(_secondsRemaining),
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _secondsRemaining / 600.0,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.06),
                        valueColor: const AlwaysStoppedAnimation(
                            AppTheme.primaryBlue),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please check your inbox (and spam folder). Click the link in the email to set a new password before the 10-minute timer expires.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: secCol,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: textCol,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_secondsRemaining <= 0 && !_loading)
                          ? _handleSendReset
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        disabledBackgroundColor:
                            isDark ? AppTheme.darkDivider : AppTheme.divider,
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPill),
                        ),
                      ),
                      child: Text(
                        _secondsRemaining > 0
                            ? 'Resend in ${_formatTime(_secondsRemaining)}'
                            : 'Resend link',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _secondsRemaining > 0
                              ? secCol
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
