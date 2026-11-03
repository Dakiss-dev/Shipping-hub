import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'package_detail_screen.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  String _searchQuery = '';
  String _paymentFilter = 'all'; // all, paid, unpaid

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;
    final currency = provider.currency == 'USD' ? '\$' : provider.currency;

    var packages = provider.packages;

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      packages = packages.where((p) {
        final customer = provider.getCustomer(p.customerId);
        final nameMatch = customer?.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ??
            false;
        final refMatch =
            p.referenceNumber.toLowerCase().contains(_searchQuery.toLowerCase());
        return nameMatch || refMatch;
      }).toList();
    }

    // Filter by payment
    if (_paymentFilter == 'paid') {
      packages =
          packages.where((p) => p.paymentStatus == PaymentStatus.paid).toList();
    } else if (_paymentFilter == 'unpaid') {
      packages = packages
          .where((p) => p.paymentStatus == PaymentStatus.unpaid)
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('packages')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '${l.t('search')} by name or ref #...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: context.semantic.cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Payment filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('✅ ${l.t('paid')}', 'paid'),
                const SizedBox(width: 8),
                _filterChip('⏳ ${l.t('unpaid')}', 'unpaid'),
                const Spacer(),
                Text(
                  '${packages.length} ${l.t('packages').toLowerCase()}',
                  style: TextStyle(
                    color: context.semantic.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: packages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          l.t('noData'),
                          style: TextStyle(
                              color: context.semantic.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: packages.length,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemBuilder: (context, index) {
                      final pkg = packages[index];
                      final customer = provider.getCustomer(pkg.customerId);
                      final isPaid =
                          pkg.paymentStatus == PaymentStatus.paid;
                      final shipment = provider.shipments
                          .where((s) => s.id == pkg.shipmentId)
                          .firstOrNull;

                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PackageDetailScreen(packageId: pkg.id),
                            ),
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isPaid
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color:
                                  isPaid ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          title: Text(
                            customer?.name ?? 'Unknown',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pkg.referenceNumber,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: context.semantic.textSecondary,
                                ),
                              ),
                              if (shipment != null)
                                Text(
                                  '${destinationFlag(shipment.destination)} ${shipment.name}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$currency${pkg.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: context.semantic.textPrimary,
                                ),
                              ),
                              if (pkg.weightKg != null)
                                Text(
                                  '${pkg.weightKg!.toStringAsFixed(1)} kg',
                                  style: TextStyle(
                                    color: context.semantic.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _paymentFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : context.semantic.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.navy : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.semantic.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
