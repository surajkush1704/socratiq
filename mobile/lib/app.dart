import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/legal/privacy_policy_screen.dart';
import 'screens/legal/terms_screen.dart';
import 'screens/legal/about_screen.dart';
import 'screens/account/delete_account_screen.dart';
import 'screens/account/edit_profile_screen.dart';
import 'screens/account/avatar_picker_screen.dart';
import 'screens/session/learn_screen.dart';
import 'screens/session/detail_explanation_screen.dart';
import 'screens/session/revise_summary_screen.dart';
import 'services/theme_service.dart';
import 'widgets/app_page_route.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class SocratiqApp extends StatelessWidget {
  const SocratiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'SocratiQ',
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
          onGenerateRoute: (settings) {
            final WidgetBuilder? builder = _routes[settings.name];
            if (builder != null) {
              return AppPageRoute(
                builder: builder,
                settings: settings,
              );
            }
            return null;
          },
        );
      },
    );
  }

  static final Map<String, WidgetBuilder> _routes = {
    '/login':          (_) => const LoginScreen(),
    '/home':           (_) => const HomeScreen(),
    '/library':        (_) => const LibraryScreen(),
    '/upload':         (_) => const UploadScreen(),
    '/dashboard':      (_) => const DashboardScreen(),
    '/profile':        (_) => const ProfileScreen(),
    '/settings':       (_) => const ProfileScreen(),
    '/app-settings':   (_) => const SettingsScreen(),
    '/voice-agent':    (_) => const LearnScreen(mode: 'learn'),
    '/learn-detail':   (_) => const DetailExplanationScreen(),
    '/revise-summary': (_) => const ReviseSummaryScreen(),
    '/privacy-policy': (_) => const PrivacyPolicyScreen(),
    '/terms':          (_) => const TermsScreen(),
    '/about':          (_) => const AboutScreen(),
    '/delete-account': (_) => const DeleteAccountScreen(),
    '/edit-profile':  (_) => const EditProfileScreen(),
    '/avatar-picker': (_) => const AvatarPickerScreen(),
  };
}
