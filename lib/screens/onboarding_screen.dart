import 'package:flutter/material.dart';
import '../theme.dart';

/// Welcome onboarding — 3 swipeable feature highlights.
/// Inspired by Stripe/Notion: quick wow-moment, then straight to action.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.local_shipping_rounded,
      iconBg: AppColors.gold,
      title: 'Manage Shipments\nLike a Pro',
      subtitle:
          'Track air & sea shipments, manage packages, and stay on top of every delivery to West Africa and beyond.',
      accent: AppColors.gold,
    ),
    _OnboardingPage(
      icon: Icons.people_rounded,
      iconBg: AppColors.info,
      title: 'Know Your\nCustomers',
      subtitle:
          'Keep a full directory with contacts, payment history, and one-tap WhatsApp sharing for receipts.',
      accent: AppColors.info,
    ),
    _OnboardingPage(
      icon: Icons.cloud_sync_rounded,
      iconBg: AppColors.success,
      title: 'Sync Everywhere.\nWork Offline.',
      subtitle:
          'Your data is saved locally first. Sign in to sync across devices — works even without internet.',
      accent: AppColors.success,
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — top right (Shopify pattern: always let users skip)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated icon container
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: page.iconBg.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: page.iconBg,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: page.iconBg.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  page.icon,
                                  color: AppColors.navy,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dot indicators + CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: AppColors.gold.withValues(alpha: 0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLast ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLast
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Color accent;

  const _OnboardingPage({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
}
