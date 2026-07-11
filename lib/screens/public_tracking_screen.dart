import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../widgets/package_photo.dart';

/// Public, no-auth package tracking page reached via a receipt link
/// (`?t=<tracking_token>`). Shows a clean, branded status timeline sourced
/// from the safe `track_package` RPC.
class PublicTrackingScreen extends StatefulWidget {
  final String token;

  const PublicTrackingScreen({super.key, required this.token});

  @override
  State<PublicTrackingScreen> createState() => _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends State<PublicTrackingScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.instance.trackPackage(widget.token);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _loading
                ? const _CenteredSpinner()
                : _data == null
                    ? _NotFound(onRetry: _load, hadError: _error != null)
                    : _TrackingBody(data: _data!),
          ),
        ),
      ),
    );
  }
}

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      );
}

class _NotFound extends StatelessWidget {
  final VoidCallback onRetry;
  final bool hadError;
  const _NotFound({required this.onRetry, required this.hadError});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.help_outline_rounded,
              color: AppColors.gold, size: 56),
          const SizedBox(height: AppSpacing.lg),
          Text(
            hadError ? 'Something went wrong' : 'Package not found',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hadError
                ? 'Please check your connection and try again.'
                : 'This tracking link is invalid or the package was removed.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TrackingBody({required this.data});

  DateTime? _date(String key) {
    final v = data[key];
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final ref = (data['reference_number'] ?? '').toString();
    final operator = (data['operator_name'] ?? '').toString();
    final destination = (data['destination'] ?? '').toString();
    final type = (data['shipment_type'] ?? '').toString();
    final status = (data['status'] ?? 'open').toString();
    final photoUrl = data['photo_url']?.toString();
    final departure = _date('departure_date');
    final eta = _date('estimated_arrival');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand header
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: AppColors.navy, size: 30),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                operator.isEmpty ? 'Shipping Hub' : operator,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text('Tracking $ref',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Status card
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.cardBgDark,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(type == 'air' ? '✈️' : '🚢',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${destinationFlag(destination)} $destination',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _Timeline(status: status),
                if (departure != null || eta != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      if (departure != null)
                        Expanded(
                            child: _DateChip(
                                label: 'Departed', value: _fmt(departure))),
                      if (eta != null)
                        Expanded(
                            child: _DateChip(
                                label: 'Est. arrival', value: _fmt(eta))),
                    ],
                  ),
                ],
                if (photoUrl != null && photoUrl.startsWith('http')) ...[
                  const SizedBox(height: AppSpacing.xl),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: PackagePhoto(
                        photoPath: photoUrl, height: 180, width: double.infinity),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text('Powered by Shipping Hub',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String value;
  const _DateChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Customer-facing 3-step journey. Maps the operator statuses
/// (open/closed/inTransit/delivered) to Preparing → In Transit → Delivered.
class _Timeline extends StatelessWidget {
  final String status;
  const _Timeline({required this.status});

  int get _activeStep {
    switch (status) {
      case 'inTransit':
        return 1;
      case 'delivered':
        return 2;
      default: // open, closed
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Preparing', Icons.inventory_2_rounded),
      ('In Transit', Icons.flight_takeoff_rounded),
      ('Delivered', Icons.check_circle_rounded),
    ];
    final active = _activeStep;
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _Node(
            label: steps[i].$1,
            icon: steps[i].$2,
            reached: i <= active,
            current: i == active,
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 22),
                color: i < active
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
        ],
      ],
    );
  }
}

class _Node extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool reached;
  final bool current;
  const _Node({
    required this.label,
    required this.icon,
    required this.reached,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final color = reached ? AppColors.gold : Colors.white.withValues(alpha: 0.25);
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: current ? AppColors.gold : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon,
              size: 22, color: current ? AppColors.navy : color),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: 70,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: reached
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
