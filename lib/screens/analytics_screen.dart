import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../services/export_service.dart';
import '../theme.dart';

/// Pro-only revenue dashboard. Entry points gate on [AppProvider.isPro] and show
/// the upgrade sheet for free operators, so by the time we get here the operator
/// is Pro — but we recompute purely from the ledger, so it's safe either way.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final symbol = provider.currency == 'USD' ? '\$' : provider.currency;
    final summary = AnalyticsService.summarize(
      packages: provider.packages,
      shipments: provider.shipments,
      customers: provider.customers,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download_rounded, color: AppColors.gold),
            onPressed: summary.isEmpty ? null : () => _exportCsv(context, provider),
          ),
        ],
      ),
      body: summary.isEmpty
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                _MoneyGrid(money: summary.money, symbol: symbol),
                const SizedBox(height: AppSpacing.xl),
                _SectionCard(
                  title: 'Revenue trend',
                  subtitle: 'Last 6 months',
                  child: _TrendChart(summary: summary, symbol: symbol),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'By shipment type',
                  child: _TypeSplit(
                      byType: summary.revenueByType, symbol: symbol),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Top customers',
                  child: _TopCustomers(
                      customers: summary.topCustomers, symbol: symbol),
                ),
              ],
            ),
    );
  }

  Future<void> _exportCsv(BuildContext context, AppProvider provider) async {
    final csv = ExportService.packagesToCsv(
      provider.packages,
      customersById: {for (final c in provider.customers) c.id: c},
      shipmentsById: {for (final s in provider.shipments) s.id: s},
    );
    // Anchor the share popover (required on iPad/macOS, ignored on phones).
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await ExportService.shareCsv(
        csv,
        filename: 'shipments.csv',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export: $e')),
        );
      }
    }
  }
}

/// The four headline figures: a wide "collected" hero over three smaller cards.
class _MoneyGrid extends StatelessWidget {
  final MoneyTotals money;
  final String symbol;
  const _MoneyGrid({required this.money, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroCard(
          label: 'Collected',
          value: fmtMoney(money.collected, symbol),
          caption: '${fmtMoney(money.totalBilled, symbol)} billed in total',
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Outstanding',
                value: fmtMoney(money.outstanding, symbol),
                color: AppColors.warning,
                icon: Icons.schedule_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                label: 'At risk',
                value: fmtMoney(money.atRisk, symbol),
                color: AppColors.danger,
                icon: Icons.priority_high_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  const _HeroCard(
      {required this.label, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 34,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text(caption,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// A titled white card wrapper for each chart section.
class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard(
      {required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(subtitle!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// Bar-per-month trend, scaled to the tallest month.
class _TrendChart extends StatelessWidget {
  final AnalyticsSummary summary;
  final String symbol;
  const _TrendChart({required this.summary, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final peak = summary.peakMonthRevenue;
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in summary.revenueByMonth)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    m.total == 0 ? '' : fmtMoneyCompact(m.total, symbol),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: (100 * (m.total / peak)).clamp(2, 100).toDouble(),
                    margin:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gold, AppColors.goldDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.sm)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(m.shortLabel,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Proportional Air vs Sea revenue split.
class _TypeSplit extends StatelessWidget {
  final Map<ShipmentType, double> byType;
  final String symbol;
  const _TypeSplit({required this.byType, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final air = byType[ShipmentType.air] ?? 0;
    final sea = byType[ShipmentType.sea] ?? 0;
    final total = air + sea;
    return Column(
      children: [
        _typeRow('Air', air, total, AppColors.airText, AppColors.airBg),
        const SizedBox(height: AppSpacing.md),
        _typeRow('Sea', sea, total, AppColors.seaText, AppColors.seaBg),
      ],
    );
  }

  Widget _typeRow(
      String label, double value, double total, Color fg, Color bg) {
    final frac = total == 0 ? 0.0 : value / total;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label,
              style: TextStyle(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 10,
              backgroundColor: bg,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 72,
          child: Text(fmtMoney(value, symbol),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _TopCustomers extends StatelessWidget {
  final List<CustomerRevenue> customers;
  final String symbol;
  const _TopCustomers({required this.customers, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < customers.length; i++) ...[
          if (i > 0) const Divider(height: AppSpacing.lg),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.navy,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customers[i].name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text('${customers[i].packageCount} packages',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(fmtMoney(customers[i].total, symbol),
                  style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded,
                size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.lg),
            const Text('No revenue yet',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Add packages to your shipments and your revenue analytics will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// "$1,250.00" — manual grouping so we don't pull in the intl package for one
/// formatter. Symbol precedes the amount (fine for $, €, and the XOF code).
///
/// Rounds to whole cents FIRST, then splits, so a value like 19.9952 becomes
/// 2000 cents -> "$20.00" rather than a carry-less "$19.100".
String fmtMoney(double value, String symbol) {
  final negative = value < 0;
  final totalCents = (value.abs() * 100).round();
  final whole = totalCents ~/ 100;
  final cents = (totalCents % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '${negative ? '-' : ''}$symbol$grouped.$cents';
}

/// "$1.2k" for tight spaces like bar labels. Gates on the ROUNDED magnitude so
/// 999.6 compacts to "$1.0k" instead of leaking through as "$1000".
String fmtMoneyCompact(double value, String symbol) {
  if (value.abs().round() >= 1000) {
    return '$symbol${(value / 1000).toStringAsFixed(1)}k';
  }
  return '$symbol${value.toStringAsFixed(0)}';
}
