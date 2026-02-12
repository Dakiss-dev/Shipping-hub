import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/packages_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/business_setup_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShippingHubApp());
}

class ShippingHubApp extends StatelessWidget {
  const ShippingHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'Shipping Hub',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: provider.isLoading
                ? const _SplashScreen()
                : const _AppRouter(),
          );
        },
      ),
    );
  }
}

/// Smart router: decides which screen to show based on app state.
/// Flow: Splash → Onboarding (first-run) → Auth → Business Setup → Dashboard
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _checking = true;
  bool _hasSeenOnboarding = false;
  bool _needsBusinessSetup = false;

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('has_seen_onboarding') ?? false;
    final setupDone = prefs.getBool('business_setup_done') ?? false;
    final provider = context.read<AppProvider>();

    setState(() {
      _hasSeenOnboarding = seen;
      // Only show business setup if authenticated AND hasn't done setup yet
      _needsBusinessSetup = provider.isAuthenticated && !setupDone;
      _checking = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    setState(() => _hasSeenOnboarding = true);
  }

  Future<void> _completeBusinessSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('business_setup_done', true);
    setState(() => _needsBusinessSetup = false);
  }

  void _onAuthComplete() {
    // After successful auth, check if business setup is needed
    setState(() => _needsBusinessSetup = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashScreen();

    // Step 1: First-time users see onboarding
    if (!_hasSeenOnboarding) {
      return OnboardingScreen(
        onComplete: () async {
          await _completeOnboarding();
        },
      );
    }

    final provider = context.watch<AppProvider>();

    // Step 2: Show auth if not authenticated and Supabase is configured
    if (!provider.isAuthenticated && provider.isSupabaseConfigured) {
      return AuthScreen(
        startWithSignUp: true,
        onAuthComplete: _onAuthComplete,
      );
    }

    // Step 3: Business setup wizard (after first signup)
    if (_needsBusinessSetup) {
      return BusinessSetupScreen(
        onComplete: () async {
          await _completeBusinessSetup();
        },
      );
    }

    // Step 4: Main app
    return const MainNavigationScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: AppColors.navy,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Shipping Hub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Package Management for Operators',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.gold.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    PackagesScreen(),
    CustomersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: l.t('dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2_outlined),
            activeIcon: const Icon(Icons.inventory_2),
            label: l.t('packages'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            activeIcon: const Icon(Icons.people),
            label: l.t('customers'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: l.t('settings'),
          ),
        ],
      ),
    );
  }
}
