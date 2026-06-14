import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/initialization_provider.dart';

/// Premium animated splash — first screen every user sees.
/// Shows for 2 500 ms then routes to /onboarding, /login, or /main/home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── dot pulse controllers ──────────────────────────────────────────
  late final AnimationController _dot1;
  late final AnimationController _dot2;
  late final AnimationController _dot3;

  @override
  void initState() {
    super.initState();

    _dot1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _dot2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future<void>.delayed(const Duration(milliseconds: 200),
        () => _dot2.repeat(reverse: true));

    _dot3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future<void>.delayed(const Duration(milliseconds: 400),
        () => _dot3.repeat(reverse: true));

    Future<void>.delayed(const Duration(milliseconds: 2500), _routeNext);
  }

  @override
  void dispose() {
    _dot1.dispose();
    _dot2.dispose();
    _dot3.dispose();
    super.dispose();
  }

  Future<void> _routeNext() async {
    if (!mounted) return;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final onboarded = prefs.getBool('onboarding_completed') ?? false;
    if (!mounted) return;
    if (!onboarded) {
      context.go('/onboarding');
      return;
    }
    final authed = ref.read(authSessionProvider) != null;
    context.go(authed ? '/main/home' : '/login');
  }

  // ── build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.deepGreen, AppColors.emerald],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Logo circle ───────────────────────────────────────
              _LogoMark()
                  .animate()
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 28),

              // ── Brand name ────────────────────────────────────────
              _BrandName()
                  .animate(delay: 400.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),

              const SizedBox(height: 16),

              // ── Tagline ───────────────────────────────────────────
              const Text(
                "Africa's Agricultural Intelligence Platform",
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xB3FFFFFF), // white 70%
                  height: 1.5,
                ),
              ).animate(delay: 700.ms).fadeIn(duration: 500.ms),

              const Spacer(flex: 3),

              // ── Pulsing dots ──────────────────────────────────────
              _PulsingDots(dot1: _dot1, dot2: _dot2, dot3: _dot3)
                  .animate(delay: 900.ms)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo mark ─────────────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.eco_rounded,
          size: 52,
          color: AppColors.deepGreen,
        ),
      ),
    );
  }
}

// ── Brand name ─────────────────────────────────────────────────────────────────

class _BrandName extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SmartAgro',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        Text(
          'Connect',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Color(0xFFB9D9BB), // white-emerald tint
            letterSpacing: 4.0,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ── Pulsing loading dots ───────────────────────────────────────────────────────

class _PulsingDots extends StatelessWidget {
  const _PulsingDots({
    required this.dot1,
    required this.dot2,
    required this.dot3,
  });

  final AnimationController dot1;
  final AnimationController dot2;
  final AnimationController dot3;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(controller: dot1),
        const SizedBox(width: 8),
        _Dot(controller: dot2),
        const SizedBox(width: 8),
        _Dot(controller: dot3),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(controller.value);
        return Opacity(
          opacity: 0.35 + 0.65 * t,
          child: Transform.scale(
            scale: 0.7 + 0.3 * t,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.freshGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.freshGreen.withValues(alpha: 0.5 * t),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
