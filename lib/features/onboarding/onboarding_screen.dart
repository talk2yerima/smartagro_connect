import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/di/initialization_provider.dart';
import '../../shared/widgets/gradient_button.dart';

// ─── Page data ────────────────────────────────────────────────────────────────

class _PageData {
  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.gradientStart,
    required this.gradientEnd,
    required this.accent,
    required this.decorIcon,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color gradientStart;
  final Color gradientEnd;
  final Color accent;
  final IconData decorIcon;
}

const _kPages = [
  _PageData(
    icon: Icons.storefront_rounded,
    title: AppStrings.onboarding1Title,
    body: AppStrings.onboarding1Body,
    gradientStart: AppColors.deepGreen,
    gradientEnd: Color(0xFF388E3C),
    accent: AppColors.golden,
    decorIcon: Icons.grain_rounded,
  ),
  _PageData(
    icon: Icons.show_chart_rounded,
    title: AppStrings.onboarding2Title,
    body: AppStrings.onboarding2Body,
    gradientStart: Color(0xFF004D40),
    gradientEnd: Color(0xFF00897B),
    accent: AppColors.mintGreen,
    decorIcon: Icons.eco_rounded,
  ),
  _PageData(
    icon: Icons.local_shipping_rounded,
    title: AppStrings.onboarding3Title,
    body: AppStrings.onboarding3Body,
    gradientStart: Color(0xFFBF360C),
    gradientEnd: Color(0xFFE64A19),
    accent: Colors.white,
    decorIcon: Icons.route_outlined,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  double _pageOffset = 0.0;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() => _pageOffset = _controller.page ?? 0.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await setOnboardingCompleted(ref, value: true);
    if (!mounted) return;
    context.go('/login');
  }

  void _next() {
    HapticFeedback.selectionClick();
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _kPages.length - 1;
    final size = MediaQuery.sizeOf(context);
    final illustrationH = size.height * 0.52;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Full-bleed illustration layer (behind everything) ─────────────
          SizedBox(
            height: illustrationH,
            width: double.infinity,
            child: _IllustrationLayer(
              pages: _kPages,
              pageOffset: _pageOffset,
            ),
          ),

          // ── Scrollable page content (text + dots + CTA) ───────────────────
          Column(
            children: [
              // Reserve space for the illustration
              SizedBox(height: illustrationH - 32),

              // ── Text + controls card ─────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemCount: _kPages.length,
                    itemBuilder: (context, i) {
                      return _TextPage(
                        data: _kPages[i],
                        isVisible: i == _index,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // ── Skip button (floats over illustration) ────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: AnimatedOpacity(
                  opacity: isLast ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLast ? null : _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.90),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Dots + CTA (anchored bottom) ──────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_kPages.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutBack,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 28 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? _kPages[_index].gradientEnd
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    // CTA button
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: isLast
                          ? PrimaryGradientButton(
                              key: const ValueKey('get-started'),
                              label: 'Get Started',
                              onPressed: _finish,
                            )
                              .animate()
                              .scale(
                                begin: const Offset(0.92, 0.92),
                                duration: 320.ms,
                                curve: Curves.easeOutBack,
                              )
                              .fadeIn(duration: 200.ms)
                          : PrimaryGradientButton(
                              key: const ValueKey('continue'),
                              label: 'Continue',
                              onPressed: _next,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Illustration layer (parallax) ───────────────────────────────────────────

class _IllustrationLayer extends StatelessWidget {
  const _IllustrationLayer({
    required this.pages,
    required this.pageOffset,
  });

  final List<_PageData> pages;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(pages.length, (i) {
        final d = pages[i];
        // Fraction of this page that's visible: 1.0 = fully visible, 0.0 = off-screen
        final offset = pageOffset - i;
        final opacity = (1.0 - offset.abs()).clamp(0.0, 1.0);
        if (opacity == 0.0) return const SizedBox.shrink();

        return Opacity(
          opacity: opacity,
          child: _IllustrationPage(
            data: d,
            parallaxOffset: offset * 40.0,
          ),
        );
      }),
    );
  }
}

class _IllustrationPage extends StatelessWidget {
  const _IllustrationPage({
    required this.data,
    required this.parallaxOffset,
  });

  final _PageData data;
  final double parallaxOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [data.gradientStart, data.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Background decorative icon (large, parallax faster)
            Positioned(
              right: -40 + parallaxOffset * 1.6,
              top: -20,
              child: Icon(
                data.decorIcon,
                size: 220,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            // Secondary decorative blob (slow parallax)
            Positioned(
              left: -30 - parallaxOffset * 0.8,
              bottom: 20,
              child: Icon(
                data.decorIcon,
                size: 110,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            // Main icon (mid-speed parallax)
            Center(
              child: Transform.translate(
                offset: Offset(parallaxOffset * 0.6, 0),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(data.icon, size: 68, color: data.accent),
                ),
              ),
            ),
            // Accent ring (no parallax — anchors the composition)
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: data.accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text page ────────────────────────────────────────────────────────────────

class _TextPage extends StatelessWidget {
  const _TextPage({required this.data, required this.isVisible});

  final _PageData data;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent line
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: data.gradientEnd,
              borderRadius: BorderRadius.circular(2),
            ),
          ).animate(target: isVisible ? 1 : 0).scaleX(
              begin: 0, end: 1, duration: 350.ms, curve: Curves.easeOut),

          const SizedBox(height: 16),

          Text(
            data.title,
            style: textTheme.headlineSmall?.copyWith(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
              height: 1.2,
            ),
          )
              .animate(target: isVisible ? 1 : 0)
              .fadeIn(duration: 300.ms, delay: 60.ms)
              .slideY(begin: 0.08, end: 0, duration: 300.ms, delay: 60.ms),

          const SizedBox(height: 14),

          Text(
            data.body,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.gray,
              height: 1.6,
            ),
          )
              .animate(target: isVisible ? 1 : 0)
              .fadeIn(duration: 300.ms, delay: 120.ms)
              .slideY(begin: 0.06, end: 0, duration: 300.ms, delay: 120.ms),
        ],
      ),
    );
  }
}

// ─── GlassyHero kept for backward-compat (used in other places) ──────────────

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
