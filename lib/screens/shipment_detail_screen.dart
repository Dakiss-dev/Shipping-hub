import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'new_package_screen.dart';
import 'package_detail_screen.dart';

class ShipmentDetailScreen extends StatelessWidget {
  final String shipmentId;

  const ShipmentDetailScreen({super.key, required this.shipmentId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;
    final currency = provider.currency == 'USD' ? '\$' : provider.currency;
    final shipment =
        provider.shipments.where((s) => s.id == shipmentId).firstOrNull;

    if (shipment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shipment')),
        body: const Center(child: Text('Shipment not found')),
      );
    }

    final packages = provider.getPackagesForShipment(shipmentId);
    final totalWeight = provider.getTotalWeightForShipment(shipmentId);
    final totalRevenue = provider.getTotalRevenueForShipment(shipmentId);
    final collected = provider.getCollectedForShipment(shipmentId);
    final outstanding = provider.getOutstandingForShipment(shipmentId);
    final flag = destinationFlag(shipment.destination);
    final isAir = shipment.type == ShipmentType.air;

    return Scaffold(
      appBar: AppBar(
        title: Text(shipment.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'close':
                  _updateStatus(context, provider, shipment, ShipmentStatus.closed);
                  break;
                case 'transit':
                  _updateStatus(
                      context, provider, shipment, ShipmentStatus.inTransit);
                  break;
                case 'delivered':
                  _updateStatus(
                      context, provider, shipment, ShipmentStatus.delivered);
                  break;
                case 'reopen':
                  _updateStatus(context, provider, shipment, ShipmentStatus.open);
                  break;
                case 'delete':
                  _deleteShipment(context, provider, shipment);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (shipment.status == ShipmentStatus.open)
                const PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                      leading: Icon(Icons.lock_outline, color: AppColors.info),
                      title: Text('Close Shipment'),
                      dense: true,
                    )),
              if (shipment.status == ShipmentStatus.closed)
                const PopupMenuItem(
                    value: 'transit',
                    child: ListTile(
                      leading: Icon(Icons.local_shipping, color: AppColors.warning),
                      title: Text('Mark In Transit'),
                      dense: true,
                    )),
              if (shipment.status == ShipmentStatus.inTransit)
                const PopupMenuItem(
                    value: 'delivered',
                    child: ListTile(
                      leading:
                          Icon(Icons.check_circle, color: AppColors.success),
                      title: Text('Mark Delivered'),
                      dense: true,
                    )),
              if (shipment.status != ShipmentStatus.open)
                const PopupMenuItem(
                    value: 'reopen',
                    child: ListTile(
                      leading:
                          Icon(Icons.refresh, color: AppColors.info),
                      title: Text('Reopen'),
                      dense: true,
                    )),
              const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: AppColors.danger),
                    title:
                        Text('Delete', style: TextStyle(color: AppColors.danger)),
                    dense: true,
                  )),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Shipment Info Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shipment.destination,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAir
                                  ? AppColors.airText.withValues(alpha: 0.3)
                                  : AppColors.seaText.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isAir ? '✈️ Air Shipment' : '🚢 Sea Shipment',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _headerStat('📦', '${packages.length}', l.t('packages')),
                    _headerStat(
                        '⚖️', '${totalWeight.toStringAsFixed(1)}', 'kg'),
                    _headerStat(
                        '💰', '$currency${totalRevenue.toStringAsFixed(0)}', l.t('total')),
                  ],
                ),
                const SizedBox(height: 12),
                // Payment progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalRevenue > 0 ? collected / totalRevenue : 0,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.success),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '✅ ${l.t('collected')}: $currency${collected.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12),
                    ),
                    Text(
                      '⏳ ${l.t('outstanding')}: $currency${outstanding.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Package List Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l.t('packages')} (${packages.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (shipment.status == ShipmentStatus.open)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewPackageScreen(shipment: shipment),
                      ),
                    ),
                    icon:
                        const Icon(Icons.add_circle, color: AppColors.gold, size: 20),
                    label: Text(l.t('addPackage'),
                        style: const TextStyle(
                            color: AppColors.gold, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),

          if (packages.isEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      size: 48, color: AppColors.gold),
                  const SizedBox(height: 12),
                  const Text(
                    'No packages yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap + to add your first package',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (shipment.status == ShipmentStatus.open)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NewPackageScreen(shipment: shipment),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(l.t('addPackage')),
                    ),
                ],
              ),
            )
          else
            ...packages.map(
                (pkg) => _packageCard(context, pkg, provider, currency)),
        ],
      ),
      floatingActionButton: shipment.status == ShipmentStatus.open
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewPackageScreen(shipment: shipment),
                ),
              ),
              icon: const Icon(Icons.camera_alt),
              label: Text(l.t('newPackage')),
            )
          : null,
    );
  }

  Widget _headerStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style:
              TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
        ),
      ],
    );
  }

  Widget _packageCard(BuildContext context, ShippingPackage pkg,
      AppProvider provider, String currency) {
    final customer = provider.getCustomer(pkg.customerId);
    final isPaid = pkg.paymentStatus == PaymentStatus.paid;

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PackageDetailScreen(packageId: pkg.id),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: pkg.photoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          pkg.photoPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2,
                              color: AppColors.textSecondary),
                        ),
                      )
                    : const Icon(Icons.inventory_2,
                        color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer?.name ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '$currency${pkg.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          pkg.referenceNumber,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (pkg.weightKg != null) ...[
                          const Text(' • ',
                              style: TextStyle(color: AppColors.textSecondary)),
                          Text(
                            '${pkg.weightKg!.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => provider.togglePaymentStatus(pkg),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPaid
                                      ? Icons.check_circle
                                      : Icons.pending,
                                  size: 12,
                                  color: isPaid
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isPaid ? 'PAID' : 'UNPAID',
                                  style: TextStyle(
                                    color: isPaid
                                        ? AppColors.success
                                        : AppColors.danger,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (pkg.receiverName != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '→ ${pkg.receiverName}',
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else if (pkg.description.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pkg.description,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, AppProvider provider,
      Shipment shipment, ShipmentStatus status) {
    shipment.status = status;
    provider.updateShipment(shipment);
  }

  void _deleteShipment(
      BuildContext context, AppProvider provider, Shipment shipment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shipment?'),
        content: const Text(
            'This will delete the shipment and all its packages. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              provider.deleteShipment(shipment.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
