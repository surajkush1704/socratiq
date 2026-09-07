import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';

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
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _step < 3 ? AppBar(
        title: Text('Delete Account',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.navyText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.navyText),
      ) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildStep(),
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
                  style: GoogleFonts.poppins(
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
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.navyText)),
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
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppTheme.secondaryText)),
            ],
          ),
        )),
        const SizedBox(height: 16),
        Text('What will NOT be deleted:',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.navyText)),
        const SizedBox(height: 12),
        ...[
          'PDFs stored locally on your device (delete manually)',
        ].map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.secondaryText, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.secondaryText)),
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
            child: Text('Continue to Delete Account',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: AppTheme.divider),
            ),
            alignment: Alignment.center,
            child: Text('Keep My Account',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.navyText)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Final Confirmation',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: AppTheme.navyText)),
        const SizedBox(height: 8),
        Text('Are you absolutely sure you want to delete your account?',
            style: GoogleFonts.poppins(
                fontSize: 15, color: AppTheme.secondaryText, height: 1.5)),
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
                      : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _confirmChecked
                        ? AppTheme.error
                        : AppTheme.divider,
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
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppTheme.secondaryText,
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
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                  : null,
              color: _confirmChecked ? null : AppTheme.divider,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            alignment: Alignment.center,
            child: Text('Delete My Account Permanently',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _confirmChecked
                        ? Colors.white
                        : AppTheme.lightText)),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _step = 1),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: AppTheme.divider),
            ),
            alignment: Alignment.center,
            child: Text('Go Back',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.navyText)),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryBlue),
          SizedBox(height: 20),
          Text('Deleting your account...',
              style: TextStyle(color: AppTheme.secondaryText)),
        ],
      ),
    );
  }

  Widget _buildDone() {
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
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: AppTheme.navyText)),
          const SizedBox(height: 8),
          Text('All your data has been permanently removed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppTheme.secondaryText)),
        ],
      ),
    );
  }
}
