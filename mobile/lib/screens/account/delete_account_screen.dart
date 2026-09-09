import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/swipe_back_wrapper.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  int _step = 1; // 1=warning, 2=confirm, 3=deleting, 4=done
  bool _confirmChecked = false;

  Future<void> _deleteAccount() async {
    setState(() => _step = 3);
    try {
      await AuthService.deleteAccount();
      if (mounted) setState(() => _step = 4);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/login', (r) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step = 1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Deletion failed: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textCol = AppTheme.dynamicText(context);

    return SwipeBackWrapper(
      fallbackRoute: '/app-settings',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _step < 3 ? AppBar(
          title: Text('DELETE ACCOUNT',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 1.2,
                  color: textCol)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textCol),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/app-settings');
              }
            },
          ),
          iconTheme: IconThemeData(color: textCol),
        ) : null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1: return _buildWarning();
      case 2: return _buildConfirmation();
      case 3: return _buildDeleting();
      case 4: return _buildDone();
      default: return _buildWarning();
    }
  }

  Widget _buildWarning() {
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColor = AppTheme.dynamicDivider(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.error.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.error, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This action is permanent and cannot be undone.',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('What will be deleted:',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: textCol)),
        const SizedBox(height: 12),
        ...[
          'Your account and profile',
          'All session history and scores',
          'Your study streaks',
          'Daily statistics and progress',
        ].map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.error, size: 18),
              const SizedBox(width: 10),
              Text(item,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: secCol)),
            ],
          ),
        )),
        const SizedBox(height: 16),
        Text('What stays on your device:',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: textCol)),
        const SizedBox(height: 12),
        ...[
          'PDFs stored locally on your device (delete manually)',
        ].map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: secCol, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, color: secCol)),
              ),
            ],
          ),
        )),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _step = 2),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            alignment: Alignment.center,
            child: Text('Continue to delete account',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: Text('Keep my account',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textCol)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    final isDark = AppTheme.isDark(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);
    final cardBg = AppTheme.dynamicCard(context);
    final borderColor = AppTheme.dynamicDivider(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Final confirmation',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: textCol)),
        const SizedBox(height: 8),
        Text('Are you absolutely sure you want to delete your account?',
            style: GoogleFonts.dmSans(
                fontSize: 14, color: secCol, height: 1.5)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => setState(() => _confirmChecked = !_confirmChecked),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _confirmChecked
                      ? AppTheme.error
                      : cardBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _confirmChecked
                        ? AppTheme.error
                        : borderColor,
                    width: 2,
                  ),
                ),
                child: _confirmChecked
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I understand this action is permanent and all my '
                  'data will be deleted immediately.',
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: secCol,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _confirmChecked ? _deleteAccount : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _confirmChecked
                  ? const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    )
                  : null,
              color: _confirmChecked ? null : (isDark ? AppTheme.darkDivider : AppTheme.divider),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            alignment: Alignment.center,
            child: Text('Delete my account permanently',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _confirmChecked
                        ? Colors.white
                        : secCol)),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _step = 1),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: Text('Go back',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textCol)),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleting() {
    final secCol = AppTheme.dynamicSecondaryText(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryBlue),
          const SizedBox(height: 20),
          Text('Deleting your account...',
              style: GoogleFonts.dmSans(color: secCol, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDone() {
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 48),
          ),
          const SizedBox(height: 20),
          Text('Account Deleted',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: textCol)),
          const SizedBox(height: 8),
          Text('All your data has been permanently removed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: secCol)),
        ],
      ),
    );
  }
}
