import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/di/initialization_provider.dart';
import '../../shared/widgets/gradient_button.dart';

/// Swipeable onboarding explaining value props for farmers and buyers.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await setOnboardingCompleted(ref, value: true);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _OnboardPage(
        icon: Icons.storefront_rounded,
        title: AppStrings.onboarding1Title,
        body: AppStrings.onboarding1Body,
        accent: AppColors.golden,
      ),
      const _OnboardPage(
        icon: Icons.show_chart_rounded,
        title: AppStrings.onboarding2Title,
        body: AppStrings.onboarding2Body,
        accent: AppColors.freshGreen,
      ),
      const _OnboardPage(
        icon: Icons.local_shipping_rounded,
        title: AppStrings.onboarding3Title,
        body: AppStrings.onboarding3Body,
        accent: AppColors.warmOrange,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: pages,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 26 : 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.emerald : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: PrimaryGradientButton(
                label: _index == pages.length - 1 ? 'Get started' : 'Continue',
                onPressed: () async {
                  if (_index == pages.length - 1) {
                    await _finish();
                  } else {
                    await _controller.nextPage(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = (constraints.maxHeight * 0.42).clamp(140.0, 260.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              GlassyHero(icon: icon, accent: accent, height: heroHeight),
              const SizedBox(height: 22),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ).animate().fadeIn().slideX(begin: -0.04, end: 0),
              const SizedBox(height: 12),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyLarge,
              ).animate().fadeIn(delay: 80.ms),
            ],
          ),
        );
      },
    );
  }
}

class GlassyHero extends StatelessWidget {
  const GlassyHero({
    super.key,
    required this.icon,
    required this.accent,
    this.height = 260,
  });

  final IconData icon;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppColors.deepGreen.withValues(alpha: 0.95),
            AppColors.emerald.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -20,
            top: -10,
            child: Icon(Icons.grass_rounded, size: 180, color: Colors.white12),
          ),
          Center(
            child: Icon(icon, size: 92, color: accent),
          ),
        ],
      ),
    ).animate().scale(duration: 520.ms, curve: Curves.easeOutBack);
  }
}
