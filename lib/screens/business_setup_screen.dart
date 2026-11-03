import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

/// Post-signup business setup wizard — 3 quick steps.
/// Inspired by Shopify's merchant onboarding: collect just enough
/// to get the user operational, skip-friendly, instant value.
///
/// Steps:
///  1. Confirm business identity (name, currency, language)
///  2. Set your pricing (air + sea price per kg — defaults pre-filled)
///  3. Ready to go! (success animation + CTA)
class BusinessSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const BusinessSetupScreen({super.key, required this.onComplete});

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  int _step = 0;
  static const _totalSteps = 3;

  // Step 1: Identity
  late TextEditingController _nameController;
  String _currency = 'USD';
  String _language = 'en';

  // Step 2: Pricing
  late TextEditingController _airPriceController;
  late TextEditingController _seaPriceController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _nameController = TextEditingController(text: provider.operatorName);
    _currency = provider.currency;
    _language = provider.languageCode;
    _airPriceController = TextEditingController(
        text: provider.airPricing.pricePerKg.toStringAsFixed(2));
    _seaPriceController = TextEditingController(
        text: provider.seaPricing.pricePerKg.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _airPriceController.dispose();
    _seaPriceController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final provider = context.read<AppProvider>();

    // Save current step data
    if (_step == 0) {
      if (_nameController.text.isNotEmpty) {
        provider.setOperatorName(_nameController.text.trim());
      }
      provider.setCurrency(_currency);
      provider.setLanguage(_language);
    } else if (_step == 1) {
      final airPrice = double.tryParse(_airPriceController.text);
      final seaPrice = double.tryParse(_seaPriceController.text);
      if (airPrice != null && airPrice > 0) {
        final airConfig = provider.airPricing;
        airConfig.pricePerKg = airPrice;
        provider.updateAirPricing(airConfig);
      }
      if (seaPrice != null && seaPrice > 0) {
        final seaConfig = provider.seaPricing;
        seaConfig.pricePerKg = seaPrice;
        provider.updateSeaPricing(seaConfig);
      }
    }

    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      widget.onComplete();
    }
  }

  void _skipSetup() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            _buildHeader(),

            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildStep(),
              ),
            ),

            // Bottom actions
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: BoxDecoration(
        color: context.semantic.cardBg,
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Step indicator
          Row(
            children: [
              Text(
                'Step ${_step + 1} of $_totalSteps',
                style: TextStyle(
                  color: context.semantic.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_step < _totalSteps - 1)
                GestureDetector(
                  onTap: _skipSetup,
                  child: Text(
                    'Skip setup',
                    style: TextStyle(
                      color: context.semantic.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / _totalSteps,
              backgroundColor: context.semantic.scaffold,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.gold),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildIdentityStep();
      case 1:
        return _buildPricingStep();
      case 2:
        return _buildReadyStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────── STEP 1: Identity ───────────────

  Widget _buildIdentityStep() {
    return SingleChildScrollView(
      key: const ValueKey('step-identity'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.store_rounded,
                color: AppColors.gold, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Set up your business',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.semantic.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tell us a bit about your shipping operation.',
            style: TextStyle(
              fontSize: 14,
              color: context.semantic.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Business name
          Text('Business Name',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.semantic.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., SD Express',
              prefixIcon:
                  const Icon(Icons.store_rounded, size: 20),
              filled: true,
              fillColor: context.semantic.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Currency
          Text('Currency',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.semantic.textSecondary)),
          const SizedBox(height: 8),
          _buildOptionRow([
            _CurrencyOption('\$', 'USD', 'US Dollar'),
            _CurrencyOption('\u20AC', 'EUR', 'Euro'),
            _CurrencyOption('F', 'XOF', 'CFA Franc'),
          ]),
          const SizedBox(height: 24),

          // Language
          Text('Language',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.semantic.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _languageChip('English', 'en'),
              const SizedBox(width: 10),
              _languageChip('Francais', 'fr'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(List<_CurrencyOption> options) {
    return Row(
      children: options.map((opt) {
        final selected = _currency == opt.code;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _currency = opt.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.navy : context.semantic.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.navy : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    opt.symbol,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : context.semantic.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt.code,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.8)
                          : context.semantic.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _languageChip(String label, String code) {
    final selected = _language == code;
    return GestureDetector(
      onTap: () => setState(() => _language = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : context.semantic.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.navy : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code == 'en' ? '\u{1F1EC}\u{1F1E7}' : '\u{1F1EB}\u{1F1F7}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : context.semantic.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── STEP 2: Pricing ───────────────

  Widget _buildPricingStep() {
    final sym = _currencySymbol(_currency);

    return SingleChildScrollView(
      key: const ValueKey('step-pricing'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.attach_money_rounded,
                color: AppColors.info, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Set your pricing',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.semantic.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'These are your default prices. You can always adjust per-item later.',
            style: TextStyle(
              fontSize: 14,
              color: context.semantic.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Air pricing card
          _pricingCard(
            icon: Icons.flight_takeoff_rounded,
            title: 'Air Shipping',
            subtitle: 'Price per kilogram for air freight',
            color: context.semantic.airText,
            bgColor: context.semantic.airBg,
            controller: _airPriceController,
            symbol: sym,
          ),
          const SizedBox(height: 16),

          // Sea pricing card
          _pricingCard(
            icon: Icons.directions_boat_rounded,
            title: 'Sea Shipping',
            subtitle: 'Price per kilogram for sea freight',
            color: context.semantic.seaText,
            bgColor: context.semantic.seaBg,
            controller: _seaPriceController,
            symbol: sym,
          ),

          const SizedBox(height: 20),

          // Helpful tip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded,
                    color: AppColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preset items (laptops, phones, barrels) have individual prices you can customize later in Settings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.semantic.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required TextEditingController controller,
    required String symbol,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.semantic.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: color,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.semantic.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.semantic.textPrimary),
            decoration: InputDecoration(
              prefixText: '$symbol ',
              prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.semantic.textPrimary.withValues(alpha: 0.5)),
              suffixText: '/ kg',
              suffixStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.semantic.textSecondary),
              filled: true,
              fillColor: context.semantic.scaffold,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.navy, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── STEP 3: Ready ───────────────

  Widget _buildReadyStep() {
    return Center(
      key: const ValueKey('step-ready'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              "You're all set!",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: context.semantic.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your business is configured and ready.\nCreate your first shipment to start managing packages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.semantic.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Feature highlights
            _readyFeature(
              Icons.cloud_sync_rounded,
              'Cloud Sync Active',
              'Your data syncs across all devices',
            ),
            _readyFeature(
              Icons.lock_rounded,
              'Data Isolated',
              'Only you can see your business data',
            ),
            _readyFeature(
              Icons.wifi_off_rounded,
              'Works Offline',
              'Full functionality even without internet',
            ),
          ],
        ),
      ),
    );
  }

  Widget _readyFeature(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: context.semantic.textPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: context.semantic.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 20),
        ],
      ),
    );
  }

  // ─────────────── Bottom Actions ───────────────

  Widget _buildBottomActions() {
    final isLast = _step == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: context.semantic.cardBg,
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: isLast ? AppColors.success : AppColors.navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLast ? 'Go to Dashboard' : 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLast
                    ? Icons.dashboard_rounded
                    : Icons.arrow_forward_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _currencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '\u20AC';
      default:
        return 'F';
    }
  }
}

class _CurrencyOption {
  final String symbol;
  final String code;
  final String name;
  const _CurrencyOption(this.symbol, this.code, this.name);
}
