import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/app_user.dart';
import '../../features/admin/admin_analytics_screen.dart';
import '../../features/admin/admin_commodities_screen.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/admin/admin_moderation_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_room_screen.dart';
import '../../features/home/dashboard_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/market/commodity_detail_screen.dart';
import '../../features/market/commodity_market_screen.dart';
import '../../features/market/market_trends_screen.dart';
import '../../features/marketplace/add_product_screen.dart';
import '../../features/marketplace/marketplace_screen.dart';
import '../../features/marketplace/product_detail_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../di/analytics_providers.dart';
import '../di/auth_providers.dart';
import '../di/initialization_provider.dart';

/// Global navigation graph with auth + onboarding redirects.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authSessionProvider, (_, __) => refresh.value++);
  ref.listen(onboardingCompletedProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    observers: [ref.read(analyticsServiceProvider).observer],
    redirect: (context, state) {
      final prefs = ref.read(loadedSharedPreferencesProvider);
      final onboarded = prefs.getBool('onboarding_completed') ?? false;
      final user = ref.read(authSessionProvider);
      final authed = user != null;
      final loc = state.matchedLocation;

      if (loc.startsWith('/splash')) return null;

      if (!onboarded) {
        if (!loc.startsWith('/onboarding')) return '/onboarding';
        return null;
      }

      final authPublic = loc.startsWith('/login') ||
          loc.startsWith('/register') ||
          loc.startsWith('/forgot') ||
          loc.startsWith('/otp');

      final protected = loc.startsWith('/main') ||
          loc.startsWith('/marketplace') ||
          loc.startsWith('/search') ||
          loc.startsWith('/notifications') ||
          loc.startsWith('/map') ||
          loc.startsWith('/settings') ||
          loc.startsWith('/admin');

      if (!authed) {
        if (protected) return '/login';
        return null;
      }

      if (authed && authPublic) return '/main/home';

      if (loc.startsWith('/admin') && user.role != UserRole.admin) {
        return '/main/home';
      }
      if (loc == '/marketplace/add' &&
          user.role != UserRole.farmer &&
          user.role != UserRole.admin) {
        return '/main/home';
      }
      if (user.role == UserRole.transporter &&
          (loc.startsWith('/marketplace') || loc.startsWith('/main/market'))) {
        return '/map';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/market',
                builder: (context, state) => const CommodityMarketScreen(),
                routes: [
                  GoRoute(
                    path: 'trends',
                    builder: (context, state) => const MarketTrendsScreen(),
                  ),
                  GoRoute(
                    path: 'commodity/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return CommodityDetailScreen(id: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/messages',
                builder: (context, state) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: 'thread/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ChatRoomScreen(threadId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/main/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/marketplace',
        builder: (context, state) => const MarketplaceScreen(),
        routes: [
          GoRoute(
            path: 'product/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProductDetailScreen(productId: id);
            },
          ),
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddProductScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomeScreen(),
        routes: [
          GoRoute(
            path: 'users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: 'moderation',
            builder: (context, state) => const AdminModerationScreen(),
          ),
          GoRoute(
            path: 'commodities',
            builder: (context, state) => const AdminCommoditiesScreen(),
          ),
          GoRoute(
            path: 'analytics',
            builder: (context, state) => const AdminAnalyticsScreen(),
          ),
        ],
      ),
    ],
  );
});

extension SmartAgroRouting on BuildContext {
  void goHome() => go('/main/home');
}
