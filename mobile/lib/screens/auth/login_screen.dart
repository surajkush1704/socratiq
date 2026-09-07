import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscurePassword = true;

  int _rateLimitCountdown = 0;
  bool _isRateLimited = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        if (e is AuthRateLimitException) {
          _startRateLimitCountdown(e.retryAfterSeconds);
          _showError(e.message);
        } else {
          _showError('Sign in failed. Please try again.');
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
        if (e is AuthRateLimitException) {
          _startRateLimitCountdown(e.retryAfterSeconds);
          _showError(e.message);
        } else if (e.toString().contains('wrong-password') ||
            e.toString().contains('user-not-found')) {
          _showError('Invalid email or password.');
        } else if (e.toString().contains('email-already-in-use')) {
          _showError('An account already exists with this email.');
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
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.auroraGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSignUp ? 'Create account' : 'Welcome back',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    color: AppTheme.navyText,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  _isSignUp
                      ? 'Start learning smarter today'
                      : 'to SocratiQ',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your personal AI tutor awaits.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 40),
                // Glass card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: AppTheme.glassShadow,
                  ),
                  child: Column(
                    children: [
                      // Google button
                      GestureDetector(
                        onTap: (_loading || _isRateLimited) ? null : _handleGoogle,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 15, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                            boxShadow: AppTheme.cardShadow,
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Continue with Google',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.navyText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            child: Text(
                              'or',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.lightText,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Email field
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email address',
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 12),
                      // Password field
                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        suffix: GestureDetector(
                          onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.lightText,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Main button
                      GestureDetector(
                        onTap: (_loading || _isRateLimited) ? null : _handleEmail,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: _isRateLimited ? null : AppTheme.primaryGradient,
                            color: _isRateLimited ? AppTheme.divider : null,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                            boxShadow: _isRateLimited ? null : AppTheme.buttonShadow,
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
                                  _isRateLimited
                                      ? 'Wait $_rateLimitCountdown seconds...'
                                      : (_isSignUp ? 'Create Account' : 'Login'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: _isRateLimited
                                        ? AppTheme.secondaryText
                                        : Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Toggle
                      GestureDetector(
                        onTap: () =>
                            setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Login'
                              : 'Don\'t have an account? Sign up',
                          style: GoogleFonts.poppins(
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
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.divider),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.poppins(
            fontSize: 14, color: AppTheme.navyText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
              fontSize: 14, color: AppTheme.lightText),
          prefixIcon: Icon(icon, color: AppTheme.lightText, size: 18),
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
