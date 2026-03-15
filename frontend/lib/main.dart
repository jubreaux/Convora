import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/theme/app_theme.dart';
import 'package:convora/core/providers/providers.dart';
import 'package:convora/features/auth/auth_screen.dart';
import 'package:convora/features/dashboard/dashboard_screen.dart';
import 'package:convora/features/scenarios/scenarios_screen.dart';
import 'package:convora/features/scenarios/manage_scenarios_screen.dart';
import 'package:convora/features/scenarios/scenario_form_screen.dart';
import 'package:convora/features/history/history_screen.dart';
import 'package:convora/features/training/training_screen.dart';
import 'package:convora/features/feedback/feedback_screen.dart';
import 'package:convora/features/session_review/session_review_screen.dart';
import 'package:convora/features/account_setup/account_setup_screen.dart';
import 'package:convora/features/profile/profile_screen.dart';

// ===== Router Setup =====
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/dashboard' : '/login',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuth && !isLoggingIn) {
        return '/login';
      }
      if (isAuth && isLoggingIn) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/scenarios',
        builder: (context, state) => const ScenariosScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/training',
        builder: (context, state) => const TrainingSessionScreen(),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/session-review/:sessionId',
        builder: (context, state) => SessionReviewScreen(
          sessionId: int.parse(state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/account-setup',
        builder: (context, state) => const AccountSetupScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/manage-scenarios',
        builder: (context, state) => const ManageScenariosScreen(),
      ),
      GoRoute(
        path: '/scenario-form',
        builder: (context, state) => const ScenarioFormScreen(),
      ),
      GoRoute(
        path: '/scenario-form/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return ScenarioFormScreen(scenarioId: id != null ? int.parse(id) : null);
        },
      ),
    ],
  );
});

void main() {
  runApp(const ProviderScope(child: ConvoraApp()));
}

class ConvoraApp extends ConsumerWidget {
  const ConvoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Convora',
      routerConfig: router,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
    );
  }
}
