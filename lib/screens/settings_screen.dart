import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';

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
          _sectionTitle(l.t('operatorName')),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.navy,
                child: Icon(Icons.store, color: AppColors.gold),
              ),
              title: Text(provider.operatorName),
              subtitle: const Text('Tap to change'),
              trailing: const Icon(Icons.edit, color: AppColors.textSecondary),
              onTap: () => _editOperatorName(context, provider),
            ),
          ),

          const SizedBox(height: 20),

          // Language
          _sectionTitle(l.t('language')),
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
          _sectionTitle(l.t('currency')),
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
          _sectionTitle(l.t('airPricing')),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                    onTap: () =>
                        _editPricePerKg(context, provider, isAir: true),
                  ),
                  const Divider(),
                  const Text(
                    'Preset Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
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
          _sectionTitle(l.t('seaPricing')),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                    onTap: () =>
                        _editPricePerKg(context, provider, isAir: false),
                  ),
                  const Divider(),
                  const Text(
                    'Item Prices',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
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

          // About
          _sectionTitle(l.t('aboutApp')),
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
                  const Text(
                    'Shipping Hub',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Package intake & shipment management\nfor diaspora shipping operators.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.textSecondary,
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
