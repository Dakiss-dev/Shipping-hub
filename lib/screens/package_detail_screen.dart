import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class PackageDetailScreen extends StatelessWidget {
  final String packageId;

  const PackageDetailScreen({super.key, required this.packageId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;
    final currency = provider.currency == 'USD' ? '\$' : provider.currency;
    final pkg = provider.packages.where((p) => p.id == packageId).firstOrNull;

    if (pkg == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Package')),
        body: const Center(child: Text('Package not found')),
      );
    }

    final customer = provider.getCustomer(pkg.customerId);
    final shipment =
        provider.shipments.where((s) => s.id == pkg.shipmentId).firstOrNull;
    final isPaid = pkg.paymentStatus == PaymentStatus.paid;

    return Scaffold(
      appBar: AppBar(
        title: Text(pkg.referenceNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deletePackage(context, provider, pkg),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Reference & Status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2, color: AppColors.gold, size: 40),
                const SizedBox(height: 12),
                Text(
                  pkg.referenceNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                if (shipment != null)
                  Text(
                    '${destinationFlag(shipment.destination)} ${shipment.name}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$currency${pkg.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment Toggle
          Card(
            child: InkWell(
              onTap: () => provider.togglePaymentStatus(pkg),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPaid ? Icons.check_circle : Icons.pending,
                        color: isPaid ? AppColors.success : AppColors.danger,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.t('paymentStatus'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            isPaid ? l.t('paid') : l.t('unpaid'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isPaid
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Tap to toggle',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.touch_app,
                        color: AppColors.textSecondary, size: 16),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Customer Info (Sender)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.navy, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${l.t('customers')} (${l.t('sendToSender').replaceAll('Send to ', '')})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _detailRow(Icons.person_outline, l.t('customerName'),
                      customer?.name ?? 'Unknown'),
                  _detailRow(
                      Icons.phone_outlined, l.t('phone'), customer?.fullPhone ?? 'N/A'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Receiver Info
          if (pkg.receiverName != null || pkg.receiverPhone != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_circle,
                            color: AppColors.navy, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l.t('receiver'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (pkg.receiverName != null)
                      _detailRow(Icons.person_outline,
                          l.t('receiverName'), pkg.receiverName!),
                    if (pkg.receiverPhone != null)
                      _detailRow(Icons.phone_outlined,
                          l.t('receiverPhone'), _fullReceiverPhone(pkg)),
                  ],
                ),
              ),
            ),

          if (pkg.receiverName != null || pkg.receiverPhone != null)
            const SizedBox(height: 8),

          // Package Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.navy, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l.t('packages'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _detailRow(
                    pkg.shipmentType == ShipmentType.air
                        ? Icons.flight
                        : Icons.directions_boat,
                    'Type',
                    pkg.shipmentType == ShipmentType.air
                        ? 'Air Shipment'
                        : 'Sea Shipment',
                  ),
                  if (pkg.weightKg != null)
                    _detailRow(Icons.scale, l.t('weight'),
                        '${pkg.weightKg!.toStringAsFixed(1)} kg'),
                  if (pkg.presetItemName != null)
                    _detailRow(Icons.category, 'Item', pkg.presetItemName!),
                  if (pkg.seaItemType != null)
                    _detailRow(Icons.category, 'Item',
                        seaItemTypeLabel(pkg.seaItemType!)),
                  if (pkg.description.isNotEmpty)
                    _detailRow(
                        Icons.description, l.t('description'), pkg.description),
                  if (pkg.notes != null && pkg.notes!.isNotEmpty)
                    _detailRow(Icons.notes, l.t('notes'), pkg.notes!),
                  _detailRow(Icons.calendar_today, 'Date',
                      '${pkg.createdAt.month}/${pkg.createdAt.day}/${pkg.createdAt.year} at ${pkg.createdAt.hour}:${pkg.createdAt.minute.toString().padLeft(2, '0')}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Share via generic share
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _shareReceipt(context, provider, pkg),
              icon: const Icon(Icons.share),
              label: Text(l.t('shareReceipt')),
            ),
          ),

          const SizedBox(height: 12),

          // WhatsApp Share Options
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF25D366).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'WhatsApp',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF25D366),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Send to Sender
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareViaWhatsApp(
                        context, provider, pkg, null, false),
                    icon: const Icon(Icons.person, size: 18),
                    label: Text(
                        '${l.t('sendToSender')} ${customer != null ? '(${customer.name})' : ''}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                // Send to Receiver (only if receiver exists)
                if (pkg.receiverPhone != null &&
                    pkg.receiverPhone!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _shareViaWhatsApp(
                          context, provider, pkg, null, true),
                      icon: const Icon(Icons.person_pin_circle, size: 18),
                      label: Text(
                          '${l.t('sendToReceiver')} ${pkg.receiverName != null ? '(${pkg.receiverName})' : ''}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF128C7E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _shareViaWhatsApp(
                            context, provider, pkg, null, false);
                        Future.delayed(const Duration(seconds: 2), () {
                          if (pkg.receiverPhone != null) {
                            _shareViaWhatsApp(context, provider, pkg,
                                null, true);
                          }
                        });
                      },
                      icon: const Icon(Icons.group, size: 18),
                      label: Text(l.t('sendToBoth')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareReceipt(
      BuildContext context, AppProvider provider, ShippingPackage pkg) {
    final receipt = provider.generateReceipt(pkg);
    SharePlus.instance.share(ShareParams(text: receipt));
  }

  /// Build the full international receiver phone number
  String _fullReceiverPhone(ShippingPackage pkg) {
    final digits = (pkg.receiverPhone ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return pkg.receiverPhone ?? '';
    // If already has a country code stored, use it
    final code = pkg.receiverPhoneCountryCode ?? '+1';
    return '$code$digits';
  }

  /// Build the full international phone for WhatsApp (digits only, no + for wa.me)
  String _whatsAppPhone(String fullPhone) {
    // wa.me expects digits only (no + sign)
    return fullPhone.replaceAll(RegExp(r'[^\d]'), '');
  }

  void _shareViaWhatsApp(BuildContext context, AppProvider provider,
      ShippingPackage pkg, String? rawPhoneOverride, bool isReceiver) {
    final receipt = isReceiver
        ? provider.generateReceiverReceipt(pkg)
        : provider.generateReceipt(pkg);

    String fullPhone = '';
    if (isReceiver) {
      // Receiver: build from country code + digits
      fullPhone = _fullReceiverPhone(pkg);
    } else {
      // Sender (customer): use the Customer.fullPhone which includes country code
      final customer = provider.getCustomer(pkg.customerId);
      fullPhone = customer?.fullPhone ?? rawPhoneOverride ?? '';
    }

    final waPhone = _whatsAppPhone(fullPhone);
    final encodedText = Uri.encodeComponent(receipt);

    final whatsappUrl = waPhone.isNotEmpty
        ? 'https://wa.me/$waPhone?text=$encodedText'
        : 'https://wa.me/?text=$encodedText';

    launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
  }

  void _deletePackage(
      BuildContext context, AppProvider provider, ShippingPackage pkg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Package?'),
        content: Text('Delete package ${pkg.referenceNumber}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              provider.deletePackage(pkg.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
