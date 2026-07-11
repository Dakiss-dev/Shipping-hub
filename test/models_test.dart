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

  group('reference collision guard', () {
    ShippingPackage makePackage() => ShippingPackage(
          customerId: 'c1',
          shipmentId: 's1',
          shipmentType: ShipmentType.air,
          price: 10,
        );

    test('ensureUniqueReference regenerates when the reference collides', () {
      final pkg = makePackage();
      final taken = {pkg.referenceNumber};
      final unique = ShippingPackage.ensureUniqueReference(pkg, taken);
      expect(unique, isTrue);
      expect(taken.contains(pkg.referenceNumber), isFalse);
      expect(RegExp(r'^SH-\d{6}-[A-Z0-9]{4}$').hasMatch(pkg.referenceNumber),
          isTrue);
    });

    test('ensureUniqueReference leaves a non-colliding reference untouched',
        () {
      final pkg = makePackage();
      final original = pkg.referenceNumber;
      final unique =
          ShippingPackage.ensureUniqueReference(pkg, {'SH-000000-ZZZZ'});
      expect(unique, isTrue);
      expect(pkg.referenceNumber, original);
    });

    test('ensureUniqueReference reports failure when every attempt collides',
        () {
      final pkg = makePackage();
      // Force exhaustion: seed the set with the current reference AND every
      // reference freshReference could produce, by capturing them as they are
      // generated. A pre-seeded set can't do that (refs are random), so we
      // drive maxAttempts to 0 — the guard makes no attempts and reports the
      // still-colliding reference as not unique.
      final taken = {pkg.referenceNumber};
      final unique = ShippingPackage.ensureUniqueReference(
        pkg,
        taken,
        maxAttempts: 0,
      );
      expect(unique, isFalse);
    });
  });
}
