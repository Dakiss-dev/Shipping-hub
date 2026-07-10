import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_hub/models/models.dart';

void main() {
  group('sync metadata', () {
    test('Customer round-trips updatedAt and deletedAt through JSON', () {
      final updated = DateTime(2026, 7, 10, 12, 30);
      final deleted = DateTime(2026, 7, 10, 13, 0);
      final customer = Customer(
        name: 'Awa',
        phone: '70123456',
        phoneCountryCode: '+226',
        updatedAt: updated,
        deletedAt: deleted,
      );
      final copy = Customer.fromJson(customer.toJson());
      expect(copy.updatedAt, updated);
      expect(copy.deletedAt, deleted);
      expect(copy.phoneCountryCode, '+226');
    });

    test('legacy JSON without updatedAt falls back to createdAt', () {
      final created = DateTime(2026, 2, 10);
      final legacy = {
        'id': 'c1',
        'name': 'Issa',
        'phone': '5551234',
        'createdAt': created.toIso8601String(),
      };
      final customer = Customer.fromJson(legacy);
      expect(customer.updatedAt, created);
      expect(customer.deletedAt, isNull);
    });

    test('Shipment and ShippingPackage carry sync metadata', () {
      final shipment = Shipment(
        name: 'Ouaga Feb',
        type: ShipmentType.sea,
        destination: 'Ouagadougou',
      );
      final pkg = ShippingPackage(
        customerId: 'c1',
        shipmentId: shipment.id,
        shipmentType: ShipmentType.sea,
        price: 80,
      );
      expect(shipment.deletedAt, isNull);
      expect(pkg.deletedAt, isNull);
      final shipmentCopy = Shipment.fromJson(shipment.toJson());
      final pkgCopy = ShippingPackage.fromJson(pkg.toJson());
      expect(shipmentCopy.updatedAt, shipment.updatedAt);
      expect(pkgCopy.updatedAt, pkg.updatedAt);
    });

    test('freshReference produces the SH-YYMMDD-XXXX format', () {
      final ref = ShippingPackage.freshReference();
      expect(RegExp(r'^SH-\d{6}-[A-Z0-9]{4}$').hasMatch(ref), isTrue);
    });
  });
}
