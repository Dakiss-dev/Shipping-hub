import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/sync/row_mappers.dart';

void main() {
  test('customer phone country code round-trips through cloud rows', () {
    final customer = Customer(
      name: 'Awa',
      phone: '70123456',
      phoneCountryCode: '+226',
    );
    final row = customerToRow(customer, 'op-1');
    expect(row['phone_country_code'], '+226'); // the old code hardcoded '+1'
    expect(row['operator_id'], 'op-1');

    final restored = customerFromRow(row);
    expect(restored.phoneCountryCode, '+226');
    expect(restored.updatedAt, customer.updatedAt);
  });

  test('deleted_at round-trips as a tombstone', () {
    final customer = Customer(name: 'X', phone: '1')
      ..deletedAt = DateTime(2026, 7, 10);
    final row = customerToRow(customer, 'op-1');
    expect(row['deleted_at'], isNotNull);
    expect(customerFromRow(row).deletedAt, DateTime(2026, 7, 10));
  });

  test('package receiver fields and metadata round-trip', () {
    final pkg = ShippingPackage(
      customerId: 'c1',
      shipmentId: 's1',
      shipmentType: ShipmentType.air,
      price: 25,
      receiverName: 'Moussa',
      receiverPhone: '76000000',
      receiverPhoneCountryCode: '+223',
    );
    final row = packageToRow(pkg, 'op-1');
    final restored = packageFromRow(row);
    expect(restored.receiverPhoneCountryCode, '+223');
    expect(restored.referenceNumber, pkg.referenceNumber);
    expect(restored.updatedAt, pkg.updatedAt);
    expect(restored.deletedAt, isNull);
  });

  test('shipment dates and status round-trip', () {
    final shipment = Shipment(
      name: 'Ouaga Container',
      type: ShipmentType.sea,
      destination: 'Ouagadougou',
      status: ShipmentStatus.inTransit,
      departureDate: DateTime(2026, 7, 1),
    );
    final restored = shipmentFromRow(shipmentToRow(shipment, 'op-1'));
    expect(restored.status, ShipmentStatus.inTransit);
    expect(restored.departureDate, DateTime(2026, 7, 1));
  });
}
