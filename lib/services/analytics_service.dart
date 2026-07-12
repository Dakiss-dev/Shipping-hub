import '../models/models.dart';

/// One month's revenue, used to draw the trend bars. [total] is the sum of
/// package prices created in that calendar month (operator's local time).
class MonthRevenue {
  final int year;
  final int month; // 1-12
  final double total;
  const MonthRevenue(this.year, this.month, this.total);

  /// Short label like "Feb". Purely for the axis; no locale month names yet.
  String get shortLabel {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}

/// A customer ranked by how much business they've brought in.
class CustomerRevenue {
  final String name;
  final double total;
  final int packageCount;
  const CustomerRevenue(this.name, this.total, this.packageCount);
}

/// The four headline money figures. Filled by [AnalyticsService._computeMoneyTotals].
class MoneyTotals {
  final double totalBilled; // every non-deleted package's price
  final double collected; // already paid
  final double outstanding; // billed but not paid
  final double atRisk; // the slice of outstanding that needs chasing
  const MoneyTotals({
    required this.totalBilled,
    required this.collected,
    required this.outstanding,
    required this.atRisk,
  });
}

/// Immutable snapshot the analytics dashboard renders. Everything is derived;
/// nothing here is persisted.
class AnalyticsSummary {
  final MoneyTotals money;
  final int packageCount;
  final int activeShipmentCount;
  final Map<ShipmentType, double> revenueByType;
  final List<MonthRevenue> revenueByMonth; // chronological, oldest first
  final List<CustomerRevenue> topCustomers; // highest revenue first
  const AnalyticsSummary({
    required this.money,
    required this.packageCount,
    required this.activeShipmentCount,
    required this.revenueByType,
    required this.revenueByMonth,
    required this.topCustomers,
  });

  bool get isEmpty => packageCount == 0;

  /// The tallest month, used to scale the trend bars. Never zero (avoids /0).
  double get peakMonthRevenue {
    var peak = 0.0;
    for (final m in revenueByMonth) {
      if (m.total > peak) peak = m.total;
    }
    return peak == 0 ? 1 : peak;
  }
}

/// Pure aggregation of an operator's ledger into an [AnalyticsSummary].
/// No IO, no state — safe to unit-test and cheap to recompute on every build.
class AnalyticsService {
  static const int _trendMonths = 6;
  static const int _topCustomerCount = 5;

  /// Rolls [packages] (already excluding tombstoned rows) up into a summary.
  /// [shipments] and [customers] provide the joins for per-type, per-customer,
  /// and shipment-status logic.
  static AnalyticsSummary summarize({
    required List<ShippingPackage> packages,
    required List<Shipment> shipments,
    required List<Customer> customers,
    DateTime? now,
  }) {
    final shipmentsById = {for (final s in shipments) s.id: s};
    final customersById = {for (final c in customers) c.id: c};
    final asOf = now ?? DateTime.now();

    // --- per shipment type ---
    final byType = <ShipmentType, double>{};
    for (final p in packages) {
      byType[p.shipmentType] = (byType[p.shipmentType] ?? 0) + p.price;
    }

    // --- trend: last _trendMonths months, oldest first ---
    final months = <MonthRevenue>[];
    for (int i = _trendMonths - 1; i >= 0; i--) {
      final anchor = DateTime(asOf.year, asOf.month - i, 1);
      final total = packages
          .where((p) {
            final d = p.createdAt.toLocal();
            return d.year == anchor.year && d.month == anchor.month;
          })
          .fold<double>(0, (sum, p) => sum + p.price);
      months.add(MonthRevenue(anchor.year, anchor.month, total));
    }

    // --- top customers by revenue ---
    final revByCustomer = <String, double>{};
    final countByCustomer = <String, int>{};
    for (final p in packages) {
      revByCustomer[p.customerId] = (revByCustomer[p.customerId] ?? 0) + p.price;
      countByCustomer[p.customerId] = (countByCustomer[p.customerId] ?? 0) + 1;
    }
    final topCustomers = revByCustomer.entries
        .map((e) => CustomerRevenue(
              customersById[e.key]?.name ?? 'Unknown',
              e.value,
              countByCustomer[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final activeShipmentCount = shipments
        .where((s) =>
            s.deletedAt == null &&
            (s.status == ShipmentStatus.open || s.status == ShipmentStatus.closed))
        .length;

    return AnalyticsSummary(
      money: _computeMoneyTotals(packages, shipmentsById),
      packageCount: packages.length,
      activeShipmentCount: activeShipmentCount,
      revenueByType: byType,
      revenueByMonth: months,
      topCustomers: topCustomers.take(_topCustomerCount).toList(),
    );
  }

  /// Rolls every package's price into the four headline money figures.
  ///
  /// `atRisk` is the operator's chosen definition: unpaid money on a shipment
  /// that has already left (in transit or delivered) is work done but not paid
  /// for, so it needs chasing. Unpaid money on an open/closed shipment is not
  /// due yet and stays out of `atRisk`.
  static MoneyTotals _computeMoneyTotals(
    List<ShippingPackage> packages,
    Map<String, Shipment> shipmentsById,
  ) {
    var totalBilled = 0.0;
    var collected = 0.0;
    var outstanding = 0.0;
    var atRisk = 0.0;

    for (final p in packages) {
      totalBilled += p.price;
      if (p.paymentStatus == PaymentStatus.paid) {
        collected += p.price;
      } else {
        outstanding += p.price;
        final status = shipmentsById[p.shipmentId]?.status;
        if (status == ShipmentStatus.inTransit ||
            status == ShipmentStatus.delivered) {
          atRisk += p.price;
        }
      }
    }

    return MoneyTotals(
      totalBilled: totalBilled,
      collected: collected,
      outstanding: outstanding,
      atRisk: atRisk,
    );
  }
}
