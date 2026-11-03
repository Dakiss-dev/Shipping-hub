import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Operator Info
          _sectionTitle(context, l.t('operatorName')),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.navy,
                child: Icon(Icons.store, color: AppColors.gold),
              ),
              title: Text(provider.operatorName),
              subtitle: const Text('Tap to change'),
              trailing: Icon(Icons.edit, color: context.semantic.textSecondary),
              onTap: () => _editOperatorName(context, provider),
            ),
          ),

          const SizedBox(height: 20),

          // Language
          _sectionTitle(context, l.t('language')),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'en',
                  groupValue: provider.languageCode,
                  onChanged: (v) => provider.setLanguage(v!),
                  title: const Text('🇬🇧  English'),
                  activeColor: AppColors.navy,
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'fr',
                  groupValue: provider.languageCode,
                  onChanged: (v) => provider.setLanguage(v!),
                  title: const Text('🇫🇷  Français'),
                  activeColor: AppColors.navy,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Currency
          _sectionTitle(context, l.t('currency')),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'USD',
                  groupValue: provider.currency,
                  onChanged: (v) => provider.setCurrency(v!),
                  title: const Text('\$ USD - US Dollar'),
                  activeColor: AppColors.navy,
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'EUR',
                  groupValue: provider.currency,
                  onChanged: (v) => provider.setCurrency(v!),
                  title: const Text('€ EUR - Euro'),
                  activeColor: AppColors.navy,
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'XOF',
                  groupValue: provider.currency,
                  onChanged: (v) => provider.setCurrency(v!),
                  title: const Text('XOF - CFA Franc'),
                  activeColor: AppColors.navy,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Air Pricing
          _sectionTitle(context, l.t('airPricing')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.t('pricePerKg')),
                    trailing: Text(
                      '${_currencySymbol(provider.currency)}${provider.airPricing.pricePerKg.toStringAsFixed(2)}/kg',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.semantic.textPrimary,
                      ),
                    ),
                    onTap: () =>
                        _editPricePerKg(context, provider, isAir: true),
                  ),
                  const Divider(),
                  Text(
                    'Preset Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.semantic.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...provider.airPricing.presetItems.entries.map((entry) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key, style: const TextStyle(fontSize: 14)),
                      trailing: Text(
                        '${_currencySymbol(provider.currency)}${entry.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.semantic.textPrimary,
                        ),
                      ),
                      onTap: () => _editPresetPrice(
                          context, provider, entry.key, entry.value),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Sea Pricing
          _sectionTitle(context, l.t('seaPricing')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${l.t('pricePerKg')} (custom items)'),
                    trailing: Text(
                      '${_currencySymbol(provider.currency)}${provider.seaPricing.pricePerKg.toStringAsFixed(2)}/kg',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.semantic.textPrimary,
                      ),
                    ),
                    onTap: () =>
                        _editPricePerKg(context, provider, isAir: false),
                  ),
                  const Divider(),
                  Text(
                    'Item Prices',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.semantic.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...provider.seaPricing.itemPrices.entries.map((entry) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(seaItemTypeLabel(entry.key),
                          style: const TextStyle(fontSize: 14)),
                      trailing: Text(
                        '${_currencySymbol(provider.currency)}${entry.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.semantic.textPrimary,
                        ),
                      ),
                      onTap: () => _editSeaItemPrice(
                          context, provider, entry.key, entry.value),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Cloud Sync & Account
          _sectionTitle(context, 'Cloud Sync'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (provider.isAuthenticated) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.success,
                        radius: 18,
                        child: Icon(Icons.cloud_done, color: Colors.white, size: 20),
                      ),
                      title: const Text('Connected', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        provider.currentUserEmail ?? '',
                        style: TextStyle(fontSize: 12, color: context.semantic.textSecondary),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: provider.isSyncing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.sync, color: context.semantic.textPrimary),
                      title: Text(provider.isSyncing ? 'Syncing...' : 'Sync Now'),
                      subtitle: provider.pendingSyncCount > 0
                          ? Text('${provider.pendingSyncCount} changes pending',
                              style: const TextStyle(color: AppColors.warning, fontSize: 12))
                          : Text(
                              provider.lastSyncedAt != null
                                  ? 'All synced • ${_clock(provider.lastSyncedAt!)}'
                                  : 'All data synced',
                              style: TextStyle(fontSize: 12, color: context.semantic.textSecondary)),
                      onTap: provider.isSyncing ? null : () => provider.manualSync(),
                    ),
                    if (provider.syncError != null) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sync_problem,
                            color: AppColors.danger),
                        title: const Text('Sync issue',
                            style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          provider.syncError!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: TextButton(
                          onPressed: provider.isSyncing
                              ? null
                              : () => provider.manualSync(),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout, color: AppColors.danger),
                      title: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
                      onTap: () async {
                        await provider.signOut();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Signed out. Data is still saved locally.'),
                              backgroundColor: AppColors.info,
                            ),
                          );
                        }
                      },
                    ),
                  ] else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                        radius: 18,
                        child: const Icon(Icons.cloud_off, color: AppColors.navy, size: 20),
                      ),
                      title: const Text('Offline Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Sign in to sync data across devices',
                        style: TextStyle(fontSize: 12, color: context.semantic.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AuthScreen(
                                startWithSignUp: false,
                                onAuthComplete: () => Navigator.pop(context),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Sign In / Sign Up'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // About
          _sectionTitle(context, l.t('aboutApp')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_shipping,
                        color: AppColors.navy, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Shipping Hub',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: context.semantic.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: context.semantic.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Package intake & shipment management\nfor diaspora shipping operators.',
                    style: TextStyle(
                      color: context.semantic.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Built by DAKISS Media',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: context.semantic.textSecondary,
        ),
      ),
    );
  }

  String _currencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return '$currency ';
    }
  }

  void _editOperatorName(BuildContext context, AppProvider provider) {
    final controller = TextEditingController(text: provider.operatorName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.l10n.t('operatorName')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.store),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.l10n.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.setOperatorName(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: Text(provider.l10n.t('save')),
          ),
        ],
      ),
    );
  }

  void _editPricePerKg(BuildContext context, AppProvider provider,
      {required bool isAir}) {
    final currentPrice =
        isAir ? provider.airPricing.pricePerKg : provider.seaPricing.pricePerKg;
    final controller =
        TextEditingController(text: currentPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.l10n.t('pricePerKg')),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.attach_money),
            suffixText: '/kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.l10n.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price > 0) {
                if (isAir) {
                  final config = provider.airPricing;
                  config.pricePerKg = price;
                  provider.updateAirPricing(config);
                } else {
                  final config = provider.seaPricing;
                  config.pricePerKg = price;
                  provider.updateSeaPricing(config);
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(provider.l10n.t('save')),
          ),
        ],
      ),
    );
  }

  void _editPresetPrice(BuildContext context, AppProvider provider,
      String itemName, double currentPrice) {
    final controller =
        TextEditingController(text: currentPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(itemName),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.l10n.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price > 0) {
                final config = provider.airPricing;
                config.presetItems[itemName] = price;
                provider.updateAirPricing(config);
                Navigator.pop(ctx);
              }
            },
            child: Text(provider.l10n.t('save')),
          ),
        ],
      ),
    );
  }

  void _editSeaItemPrice(BuildContext context, AppProvider provider,
      SeaItemType itemType, double currentPrice) {
    final controller =
        TextEditingController(text: currentPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(seaItemTypeLabel(itemType)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.l10n.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price > 0) {
                final config = provider.seaPricing;
                config.itemPrices[itemType] = price;
                provider.updateSeaPricing(config);
                Navigator.pop(ctx);
              }
            },
            child: Text(provider.l10n.t('save')),
          ),
        ],
      ),
    );
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
