import 'package:flutter/material.dart';

import '../theme.dart';

/// Friendly "Upgrade to Pro" bottom sheet shown when a free operator hits a
/// Pro boundary (e.g. the active-shipment cap). Never a dead end — it explains
/// the value and offers to upgrade.
Future<void> showUpgradeSheet(BuildContext context, {String? reason}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UpgradeSheet(reason: reason),
  );
}

class _UpgradeSheet extends StatelessWidget {
  final String? reason;
  const _UpgradeSheet({this.reason});

  static const _benefits = [
    ('Unlimited shipments', Icons.all_inclusive_rounded),
    ('Sync across all your devices', Icons.devices_rounded),
    ('Customer tracking links', Icons.share_location_rounded),
    ('CSV & PDF exports', Icons.download_rounded),
    ('Revenue analytics', Icons.insights_rounded),
    ('Your branding on receipts', Icons.workspace_premium_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: AppColors.navy, size: 26),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Text(
                    'Upgrade to Pro',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                reason!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            for (final b in _benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(b.$2, color: AppColors.gold, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(b.$1,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Stripe checkout arrives in the billing step; until then this
                // is an honest placeholder rather than a dead button.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Paid plans are launching soon — thanks for your interest!'),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text('Upgrade to Pro'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.6)),
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    );
  }
}
