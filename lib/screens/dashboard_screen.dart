import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/upgrade_sheet.dart';
import 'shipment_detail_screen.dart';
import 'new_shipment_screen.dart';
import 'analytics_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// Opens the new-shipment form, or the upgrade sheet when a free operator is
  /// already at the active-shipment cap.
  void _startNewShipment(
      BuildContext context, AppProvider provider, ShipmentType type) {
    if (!provider.canAddShipment) {
      showUpgradeSheet(
        context,
        reason:
            "You've reached the free plan's ${AppProvider.freeActiveShipmentLimit}-shipment limit. Upgrade for unlimited shipments.",
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewShipmentScreen(preselectedType: type),
      ),
    );
  }

  /// Opens the Pro analytics dashboard, or the upgrade sheet for free operators.
  void _openAnalytics(BuildContext context, AppProvider provider) {
    if (!provider.isPro) {
      showUpgradeSheet(
        context,
        reason: 'Revenue analytics is a Pro feature. Upgrade to see what your '
            'business is earning.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;
    final currency = provider.currency == 'USD' ? '\$' : provider.currency;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping,
                  color: AppColors.navy, size: 20),
            ),
            const SizedBox(width: 10),
            Text(l.t('appName')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Analytics',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.insights_rounded, color: AppColors.gold),
                if (!provider.isPro)
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: Icon(Icons.lock, size: 11, color: AppColors.gold),
                  ),
              ],
            ),
            onPressed: () => _openAnalytics(context, provider),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () =>
                  provider.setLanguage(provider.languageCode == 'en' ? 'fr' : 'en'),
              icon: const Icon(Icons.language, color: AppColors.gold, size: 18),
              label: Text(
                provider.languageCode == 'en' ? 'FR' : 'EN',
                style: const TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        // Pull-to-refresh runs a real cloud sync (no-op when signed out).
        onRefresh: () => context.read<AppProvider>().manualSync(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Stats Header
            _buildStatsHeader(context, provider, currency),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                l.t('selectShipmentType'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.semantic.textPrimary,
                ),
              ),
            ),
            _buildShipmentTypeCards(context, provider),

            // Active Shipments
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.t('activeShipments'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.semantic.textPrimary,
                    ),
                  ),
                  Text(
                    '${provider.activeShipments.length}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.semantic.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            if (provider.activeShipments.isEmpty)
              _buildEmptyState(context, l)
            else
              ...provider.activeShipments
                  .map((s) => _buildShipmentCard(context, s, provider, currency)),

            // Past Shipments
            if (provider.pastShipments.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Past Shipments',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.semantic.textSecondary,
                  ),
                ),
              ),
              ...provider.pastShipments
                  .take(3)
                  .map((s) => _buildShipmentCard(context, s, provider, currency)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(
      BuildContext context, AppProvider provider, String currency) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyLight],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statItem(
                  Icons.inventory_2_outlined,
                  provider.packages.length.toString(),
                  provider.l10n.t('totalPackages'),
                ),
              ),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2)),
              Expanded(
                child: _statItem(
                  Icons.attach_money,
                  '$currency${provider.totalRevenue.toStringAsFixed(0)}',
                  provider.l10n.t('totalRevenue'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statItem(
                  Icons.check_circle_outline,
                  '$currency${provider.totalCollected.toStringAsFixed(0)}',
                  provider.l10n.t('collected'),
                  valueColor: AppColors.success,
                ),
              ),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2)),
              Expanded(
                child: _statItem(
                  Icons.pending_outlined,
                  '$currency${provider.totalOutstanding.toStringAsFixed(0)}',
                  provider.l10n.t('outstanding'),
                  valueColor: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label,
      {Color? valueColor}) {
    return Column(
      children: [
        Icon(icon, color: valueColor ?? AppColors.gold, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildShipmentTypeCards(BuildContext context, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _shipmentTypeCard(
              context,
              icon: Icons.flight_takeoff,
              title: provider.l10n.t('air'),
              subtitle: '✈️ ${provider.l10n.t('airShipment')}',
              color: context.semantic.airText,
              bgColor: context.semantic.airBg,
              onTap: () =>
                  _startNewShipment(context, provider, ShipmentType.air),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _shipmentTypeCard(
              context,
              icon: Icons.directions_boat,
              title: provider.l10n.t('sea'),
              subtitle: '🚢 ${provider.l10n.t('seaShipment')}',
              color: context.semantic.seaText,
              bgColor: context.semantic.seaBg,
              onTap: () =>
                  _startNewShipment(context, provider, ShipmentType.sea),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shipmentTypeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.semantic.cardBg,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: context.semantic.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShipmentCard(BuildContext context, Shipment shipment,
      AppProvider provider, String currency) {
    final packages = provider.getPackagesForShipment(shipment.id);
    final totalWeight = provider.getTotalWeightForShipment(shipment.id);
    final totalRevenue = provider.getTotalRevenueForShipment(shipment.id);
    final outstanding = provider.getOutstandingForShipment(shipment.id);
    final flag = destinationFlag(shipment.destination);
    final isAir = shipment.type == ShipmentType.air;

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShipmentDetailScreen(shipmentId: shipment.id),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAir ? context.semantic.airBg : context.semantic.seaBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAir ? Icons.flight : Icons.directions_boat,
                          size: 14,
                          color: isAir ? context.semantic.airText : context.semantic.seaText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAir ? 'AIR' : 'SEA',
                          style: TextStyle(
                            color:
                                isAir ? context.semantic.airText : context.semantic.seaText,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(shipment.status),
                  const Spacer(),
                  if (outstanding > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$currency${outstanding.toStringAsFixed(0)} due',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shipment.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          shipment.destination,
                          style: TextStyle(
                            color: context.semantic.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: context.semantic.textSecondary),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.semantic.scaffold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniStat(context, '📦', '${packages.length}', 'Packages'),
                    _miniStat(context, '⚖️',
                        '${totalWeight.toStringAsFixed(1)}kg', 'Weight'),
                    _miniStat(context, '💰',
                        '$currency${totalRevenue.toStringAsFixed(0)}', 'Value'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(
      BuildContext context, String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.semantic.textPrimary),
        ),
        Text(
          label,
          style: TextStyle(
              color: context.semantic.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _statusBadge(ShipmentStatus status) {
    Color color;
    String text;
    switch (status) {
      case ShipmentStatus.open:
        color = AppColors.success;
        text = 'OPEN';
        break;
      case ShipmentStatus.closed:
        color = AppColors.info;
        text = 'CLOSED';
        break;
      case ShipmentStatus.inTransit:
        color = AppColors.warning;
        text = 'IN TRANSIT';
        break;
      case ShipmentStatus.delivered:
        color = AppColors.navy;
        text = 'DELIVERED';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.semantic.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.semantic.border),
      ),
      child: Column(
        children: [
          // Illustration area
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 40,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ready to ship!',
            style: TextStyle(
              color: context.semantic.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first Air or Sea shipment above\nto start tracking packages and customers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.semantic.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Quick guide steps
          _guideStep(context, '1', 'Create a shipment (Air or Sea)'),
          _guideStep(context, '2', 'Add packages for your customers'),
          _guideStep(context, '3', 'Share receipts via WhatsApp'),
        ],
      ),
    );
  }

  Widget _guideStep(BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: context.semantic.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: context.semantic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
