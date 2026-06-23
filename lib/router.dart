import 'package:atvara_app/screens/admin/admin_create_session_screen.dart';
import 'package:atvara_app/screens/admin/admin_session_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/attend/attend_landing_screen.dart';
import 'screens/attend/attend_form_screen.dart';
import 'screens/attend/attend_success_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_sessions_screen.dart';
// import 'screens/admin/admin_create_session_screen.dart';
// import 'screens/admin/admin_session_detail_screen.dart';

/// Global admin authentication state.
final adminAuthNotifier = ValueNotifier<bool>(false);

final GoRouter appRouter = GoRouter(
  initialLocation: '/attend',
  refreshListenable: adminAuthNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final isAdminArea = path.startsWith('/admin');
    final isLoginPage = path == '/admin';
    final isLoggedIn = adminAuthNotifier.value;

    // Redirect unauthenticated admin users to login
    if (isAdminArea && !isLoginPage && !isLoggedIn) {
      return '/admin';
    }
    // Redirect authenticated users away from login page
    if (isLoginPage && isLoggedIn) {
      return '/admin/sessions';
    }
    return null;
  },
  routes: [
    // ── Attendee Routes ──────────────────────────────────────────────
    GoRoute(
      path: '/attend',
      builder: (context, state) => const AttendLandingScreen(),
    ),
    GoRoute(
      path: '/attend/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return AttendFormScreen(sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/attend/:sessionId/success',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        final name = state.uri.queryParameters['name'] ?? 'Attendee';
        final session = state.uri.queryParameters['session'] ?? '';
        return AttendSuccessScreen(
          sessionId: sessionId,
          attendeeName: name,
          sessionName: session,
        );
      },
    ),

    // ── Admin Routes ─────────────────────────────────────────────────
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/admin/sessions',
      builder: (context, state) => const AdminSessionsScreen(),
    ),
    // NOTE: 'new' must be declared before ':id' to avoid conflict
    GoRoute(
      path: '/admin/sessions/new',
      builder: (context, state) => const AdminCreateSessionScreen(),
    ),
    GoRoute(
      path: '/admin/sessions/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AdminSessionDetailScreen(sessionId: id);
      },
    ),
  ],
);
