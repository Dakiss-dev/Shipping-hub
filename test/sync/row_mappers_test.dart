import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/sync/row_mappers.dart';

void main() {
  test('packageToRow only pushes a real storage URL as photo_url', () {
    ShippingPackage pkg({String? photo}) => ShippingPackage(
          customerId: 'c1',
          shipmentId: 's1',
          shipmentType: ShipmentType.air,
          price: 25,
          photoPath: photo,
        );

    // A device-local path or web blob must NOT reach the cloud column.
    expect(packageToRow(pkg(photo: '/data/user/0/cache/img.jpg'), 'op')['photo_url'],
        isNull);
    expect(packageToRow(pkg(photo: 'blob:http://localhost/abc'), 'op')['photo_url'],
        isNull);
    expect(packageToRow(pkg(photo: null), 'op')['photo_url'], isNull);

    // A real storage URL is pushed through.
    const url = 'https://x.supabase.co/storage/v1/object/public/package-photos/op/p.jpg';
    expect(packageToRow(pkg(photo: url), 'op')['photo_url'], url);
  });

  test('tracking token round-trips through cloud rows', () {
    final pkg = ShippingPackage(
      customerId: 'c1',
      shipmentId: 's1',
      shipmentType: ShipmentType.sea,
      price: 80,
    );
    final row = packageToRow(pkg, 'op');
    expect(row['tracking_token'], pkg.trackingToken);
    expect(packageFromRow(row).trackingToken, pkg.trackingToken);
  });

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

  test('toRow serializes instants in UTC with explicit Z suffix', () {
    final customer = Customer(name: 'Awa', phone: '1');
    final row = customerToRow(customer, 'op-1');
    expect((row['created_at'] as String).endsWith('Z'), isTrue);
    expect((row['updated_at'] as String).endsWith('Z'), isTrue);
    expect((row['synced_at'] as String).endsWith('Z'), isTrue);
    // The instant survives: parsing the UTC string equals the original moment.
    expect(DateTime.parse(row['created_at'] as String),
        customer.createdAt.toUtc());
  });

  test('fromRow parses a wire-shaped PostgREST payload', () {
    final restored = packageFromRow({
      'id': 'p1',
      'reference_number': 'SH-260710-AB12',
      'customer_id': 'c1',
      'shipment_id': 's1',
      'shipment_type': 'sea',
      'photo_url': null,
      'description': 'Barrel',
      'weight_kg': 5, // PostgREST sends whole doubles as JSON ints
      'sea_item_type': 'smallBarrel',
      'preset_item_name': null,
      'price': 80, // ditto
      'payment_status': 'unpaid',
      'notes': null,
      'receiver_name': null,
      'receiver_phone': null,
      'receiver_phone_country_code': null,
      'created_at': '2026-07-10T14:00:00+00:00', // offset-bearing wire format
      'updated_at': '2026-07-10T15:30:00Z',
      'deleted_at': null,
    });
    expect(restored.weightKg, 5.0);
    expect(restored.price, 80.0);
    expect(restored.seaItemType, SeaItemType.smallBarrel);
    expect(restored.updatedAt.isUtc, isFalse);
    expect(restored.updatedAt, DateTime.utc(2026, 7, 10, 15, 30).toLocal());
  });

  test('unknown enum strings currently throw StateError (documented gap)', () {
    // Version-skew guard: per-row isolation happens in SupabaseBackend.pullAll
    // (Task 7), which skips rows that fail to map instead of crashing the pull.
    expect(
      () => shipmentFromRow({
        'id': 's1',
        'name': 'X',
        'type': 'teleport', // not a ShipmentType
        'destination': 'Ouaga',
        'status': 'open',
        'created_at': '2026-07-10T14:00:00Z',
        'updated_at': '2026-07-10T14:00:00Z',
        'deleted_at': null,
        'departure_date': null,
        'estimated_arrival': null,
        'notes': null,
      }),
      throwsStateError,
    );
  });
}
