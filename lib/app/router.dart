import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/network/book_search_service.dart';
import '../features/ai/ai_assistant_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/book_detail/book_detail_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/explore/game_screen.dart';
import '../features/feedback/feedback_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/add_book_screen.dart';
import '../features/library/library_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reading_session/reading_session_screen.dart';
import '../features/search/search_screen.dart';
import 'shell.dart';

/// Navigator akar, dipakai layar fokus agar tidak terbungkus shell.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Peta rute Storyloka (dokumen desain Bagian 3.2–3.4).
///
/// * 4 cabang shell  → bottom nav tampil (SCR-02, 03, 04, 09, 10, 14).
/// * Rute di luar shell → layar fokus, bottom nav disembunyikan
///   (SCR-01, 05, 06, 07, 08, 15, 16, 17).
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: <RouteBase>[
    // SCR-01 — Splash, Register, Login & Biometrik (WF-02).
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth',
      // extra = 'expired' | 'biometric' | null (dikirim splash).
      builder: (context, state) =>
          AuthScreen(startMessage: state.extra as String?),
    ),

    // Shell 5 slot: Beranda · Explore · Profil · Kesan · (Logout di dialog).
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        // Cabang Beranda — juga menampung SCR-03 dan SCR-14 (nav tampil).
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(), // SCR-02
            ),
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(), // SCR-03
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) =>
                  const NotificationsScreen(), // SCR-14
            ),
          ],
        ),
        // Cabang Explore.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(), // SCR-04
            ),
          ],
        ),
        // Cabang Profil.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/profil',
              builder: (context, state) => const ProfileScreen(), // SCR-09
            ),
          ],
        ),
        // Cabang Kesan & Saran mata kuliah PAM.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/kesan',
              builder: (context, state) => const FeedbackScreen(), // SCR-10
            ),
          ],
        ),
      ],
    ),

    // ---- Layar fokus (bottom nav disembunyikan) -------------------------
    GoRoute(
      // Query `?book=` = konteks buku dari SCR-06 ("Tanya AI") — WF-07.
      path: '/ai',
      builder: (context, state) => AiAssistantScreen(
        bookId: int.tryParse(state.uri.queryParameters['book'] ?? ''),
      ), // SCR-05
    ),
    // Rute statis `/book/edit` didahulukan agar tidak tertangkap `/book/:id`.
    // Query `?id=` = mode edit; `extra` = hasil pencarian online (TC-13).
    GoRoute(
      path: '/book/edit',
      builder: (context, state) {
        final extra = state.extra;
        final id = int.tryParse(state.uri.queryParameters['id'] ?? '');
        if (extra is OnlineBookResult) {
          return AddBookScreen(prefill: extra);
        }
        return AddBookScreen(bookId: id);
      },
    ),
    GoRoute(
      path: '/book/:id',
      builder: (context, state) =>
          BookDetailScreen(bookId: state.pathParameters['id']), // SCR-06
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(), // SCR-08
    ),
    GoRoute(
      // Query `?id=` = buku yang sedang dibaca (dari SCR-02 / SCR-06).
      path: '/session',
      builder: (context, state) => ReadingSessionScreen(
        bookId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
      ), // SCR-15
    ),
    GoRoute(
      path: '/game',
      builder: (context, state) => const GameScreen(), // SCR-16
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfileScreen(), // SCR-17
    ),
  ],
);
