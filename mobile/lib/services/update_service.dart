import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String releasePageUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releasePageUrl,
  });
}

class UpdateService {
  static const String repoOwner = 'surajkush1704';
  static const String repoName = 'socratiq';
  static const String githubApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static bool _hasCheckedThisSession = false;

  /// Check GitHub for latest release and prompt user if an update is available.
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool silentIfUpToDate = true,
  }) async {
    // Avoid spamming on every navigation in the same session unless triggered manually
    if (silentIfUpToDate && _hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    try {
      final updateInfo = await _fetchUpdateInfo();
      if (updateInfo == null) {
        if (!silentIfUpToDate && context.mounted) {
          _showToast(context, 'Unable to check for updates right now.');
        }
        return;
      }

      final hasUpdate = _isVersionHigher(
        updateInfo.latestVersion,
        updateInfo.currentVersion,
      );

      if (!context.mounted) return;

      if (hasUpdate) {
        _showUpdateDialog(context, updateInfo);
      } else if (!silentIfUpToDate) {
        _showToast(
          context,
          'Socratiq is up to date (v${updateInfo.currentVersion})',
        );
      }
    } catch (e) {
      print('[UPDATE_SERVICE] Error checking updates: $e');
      if (!silentIfUpToDate && context.mounted) {
        _showToast(context, 'Could not check for updates.');
      }
    }
  }

  static Future<UpdateInfo?> _fetchUpdateInfo() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
      },
    ));

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVer = packageInfo.version.isNotEmpty ? packageInfo.version : '1.0.3';

    final response = await dio.get(githubApiUrl);
    if (response.statusCode != 200 || response.data == null) {
      return null;
    }

    final data = response.data as Map<String, dynamic>;
    final tagName = (data['tag_name'] as String? ?? '').replaceFirst('v', '').trim();
    final body = (data['body'] as String? ?? 'Exciting new features and bug fixes.').trim();
    final htmlUrl = data['html_url'] as String? ??
        'https://github.com/$repoOwner/$repoName/releases/latest';

    // Find direct APK download link in assets if present
    String downloadUrl = 'https://github.com/$repoOwner/$repoName/releases/latest/download/socratiq.apk';
    if (data['assets'] is List) {
      final assets = data['assets'] as List;
      for (final asset in assets) {
        if (asset is Map &&
            (asset['name'] as String? ?? '').toLowerCase().endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
          break;
        }
      }
    }

    return UpdateInfo(
      latestVersion: tagName,
      currentVersion: currentVer,
      releaseNotes: body,
      downloadUrl: downloadUrl,
      releasePageUrl: htmlUrl,
    );
  }

  /// Parses semantic versions like 1.0.3 vs 1.0.2
  static bool _isVersionHigher(String latest, String current) {
    try {
      final latestClean = latest.replaceAll(RegExp(r'[^0-9.]'), '');
      final currentClean = current.replaceAll(RegExp(r'[^0-9.]'), '');

      final latestParts = latestClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.dynamicCard(context);
    final textCol = AppTheme.dynamicText(context);
    final secCol = AppTheme.dynamicSecondaryText(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top badge / icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.buttonShadow,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'New Update Available!',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Current: v${info.currentVersion}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: secCol,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Latest: v${info.latestVersion}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Release notes
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      info.releaseNotes.isNotEmpty
                          ? info.releaseNotes
                          : 'Performance optimizations, bug fixes, and enhanced tutoring features.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: secCol,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          'Later',
                          style: GoogleFonts.dmSans(
                            color: secCol,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final url = Uri.parse(info.downloadUrl);
                          try {
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              final fallback = Uri.parse(info.releasePageUrl);
                              await launchUrl(fallback, mode: LaunchMode.externalApplication);
                            }
                          } catch (e) {
                            print('[UPDATE_SERVICE] Could not launch download URL: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Update Now',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
