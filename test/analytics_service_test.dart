import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/analytics_service.dart';

void main() {
  Customer cust(String id, String name) =>
      Customer(id: id, name: name, phone: '700', phoneCountryCode: '+226');

  Shipment ship(String id, ShipmentStatus status) => Shipment(
        id: id,
        name: 'Shipment $id',
        type: ShipmentType.sea,
        destination: 'Ouaga',
        status: status,
      );

  ShippingPackage pkg({
    required String customerId,
    required String shipmentId,
    required double price,
    required ShipmentType type,
    required DateTime created,
    PaymentStatus payment = PaymentStatus.unpaid,
  }) =>
      ShippingPackage(
        customerId: customerId,
        shipmentId: shipmentId,
        shipmentType: type,
        price: price,
        paymentStatus: payment,
        createdAt: created,
      );

  final asOf = DateTime(2026, 7, 15);

  group('AnalyticsService.summarize plumbing', () {
    test('splits revenue by shipment type', () {
      final summary = AnalyticsService.summarize(
        now: asOf,
        customers: [cust('c1', 'Awa')],
        shipments: [ship('s1', ShipmentStatus.open)],
        packages: [
          pkg(customerId: 'c1', shipmentId: 's1', price: 100, type: ShipmentType.air, created: asOf),
          pkg(customerId: 'c1', shipmentId: 's1', price: 250, type: ShipmentType.sea, created: asOf),
          pkg(customerId: 'c1', shipmentId: 's1', price: 50, type: ShipmentType.air, created: asOf),
        ],
      );
      expect(summary.revenueByType[ShipmentType.air], 150);
      expect(summary.revenueByType[ShipmentType.sea], 250);
      expect(summary.packageCount, 3);
    });

    test('trend has 6 chronological months bucketed by created month', () {
      final summary = AnalyticsService.summarize(
        now: asOf,
        customers: [cust('c1', 'Awa')],
        shipments: [ship('s1', ShipmentStatus.open)],
        packages: [
          pkg(customerId: 'c1', shipmentId: 's1', price: 300, type: ShipmentType.sea, created: DateTime(2026, 7, 2)),
          pkg(customerId: 'c1', shipmentId: 's1', price: 200, type: ShipmentType.sea, created: DateTime(2026, 5, 20)),
          // Older than the 6-month window — excluded from the trend.
          pkg(customerId: 'c1', shipmentId: 's1', price: 999, type: ShipmentType.sea, created: DateTime(2025, 1, 1)),
        ],
      );
      expect(summary.revenueByMonth.length, 6);
      // Oldest first: Feb..Jul 2026.
      expect(summary.revenueByMonth.first.month, 2);
      expect(summary.revenueByMonth.last.month, 7);
      expect(summary.revenueByMonth.last.total, 300);
      final may = summary.revenueByMonth.firstWhere((m) => m.month == 5);
      expect(may.total, 200);
    });

    test('ranks top customers by revenue, names joined', () {
      final summary = AnalyticsService.summarize(
        now: asOf,
        customers: [cust('c1', 'Awa'), cust('c2', 'Issa')],
        shipments: [ship('s1', ShipmentStatus.open)],
        packages: [
          pkg(customerId: 'c1', shipmentId: 's1', price: 100, type: ShipmentType.sea, created: asOf),
          pkg(customerId: 'c2', shipmentId: 's1', price: 500, type: ShipmentType.sea, created: asOf),
          pkg(customerId: 'c2', shipmentId: 's1', price: 50, type: ShipmentType.sea, created: asOf),
        ],
      );
      expect(summary.topCustomers.first.name, 'Issa');
      expect(summary.topCustomers.first.total, 550);
      expect(summary.topCustomers.first.packageCount, 2);
      expect(summary.topCustomers[1].name, 'Awa');
    });

    test('counts only open/closed shipments as active', () {
      final summary = AnalyticsService.summarize(
        now: asOf,
        customers: [cust('c1', 'Awa')],
        shipments: [
          ship('s1', ShipmentStatus.open),
          ship('s2', ShipmentStatus.closed),
          ship('s3', ShipmentStatus.delivered),
        ],
        packages: [],
      );
      expect(summary.activeShipmentCount, 2);
      expect(summary.isEmpty, isTrue);
    });
  });

  group('money rollup', () {
    // Ali's definition: at risk = unpaid on a shipment that is inTransit OR
    // delivered. Unpaid on open/closed is not due yet; paid is never at risk.
    final shipments = [
      ship('open', ShipmentStatus.open),
      ship('closed', ShipmentStatus.closed),
      ship('transit', ShipmentStatus.inTransit),
      ship('delivered', ShipmentStatus.delivered),
    ];
    final packages = [
      pkg(customerId: 'c1', shipmentId: 'open', price: 100, type: ShipmentType.sea, created: asOf, payment: PaymentStatus.paid),
      pkg(customerId: 'c1', shipmentId: 'open', price: 200, type: ShipmentType.sea, created: asOf, payment: PaymentStatus.unpaid),
      pkg(customerId: 'c1', shipmentId: 'transit', price: 300, type: ShipmentType.sea, created: asOf, payment: PaymentStatus.unpaid),
      pkg(customerId: 'c1', shipmentId: 'delivered', price: 400, type: ShipmentType.sea, created: asOf, payment: PaymentStatus.unpaid),
      pkg(customerId: 'c1', shipmentId: 'delivered', price: 50, type: ShipmentType.sea, created: asOf, payment: PaymentStatus.paid),
      pkg(customerId: 'c1', shipmentId: 'closed', price: 60, type: ShipmentType.sea, created: asOf, payment: PaymentStatus.unpaid),
    ];

    final money = AnalyticsService.summarize(
      now: asOf,
      customers: [cust('c1', 'Awa')],
      shipments: shipments,
      packages: packages,
    ).money;

    test('totalBilled is the sum of every package price', () {
      expect(money.totalBilled, 1110);
    });

    test('collected sums only paid packages', () {
      expect(money.collected, 150);
    });

    test('outstanding sums only unpaid packages', () {
      expect(money.outstanding, 960);
    });

    test('atRisk counts unpaid on in-transit or delivered shipments only', () {
      // 300 (transit) + 400 (delivered) = 700; the $200 open and $60 closed
      // unpaid are not yet due, the paid ones never count.
      expect(money.atRisk, 700);
    });

    test('invariants hold: billed == collected + outstanding, atRisk <= outstanding', () {
      expect(money.collected + money.outstanding, money.totalBilled);
      expect(money.atRisk, lessThanOrEqualTo(money.outstanding));
    });

    test('empty ledger yields all zeros', () {
      final zero = AnalyticsService.summarize(
        now: asOf,
        customers: const [],
        shipments: const [],
        packages: const [],
      ).money;
      expect(zero.totalBilled, 0);
      expect(zero.collected, 0);
      expect(zero.outstanding, 0);
      expect(zero.atRisk, 0);
    });
  });
}
