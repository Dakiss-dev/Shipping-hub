import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_test');
    Hive.init(tempDir.path);
    storage = StorageService();
    await storage.initForTest();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
  });

  test('tombstoned records are hidden from list getters', () async {
    final live = Customer(name: 'Live', phone: '1');
    final dead = Customer(name: 'Dead', phone: '2')
      ..deletedAt = DateTime.now();
    await storage.saveCustomer(live);
    await storage.saveCustomer(dead);
    expect(storage.getCustomers().map((c) => c.name), ['Live']);

    final liveShipment =
        Shipment(name: 'S1', type: ShipmentType.air, destination: 'Bamako');
    final deadShipment =
        Shipment(name: 'S2', type: ShipmentType.sea, destination: 'Ouaga')
          ..deletedAt = DateTime.now();
    await storage.saveShipment(liveShipment);
    await storage.saveShipment(deadShipment);
    expect(storage.getShipments().map((s) => s.name), ['S1']);

    final livePkg = ShippingPackage(
        customerId: live.id,
        shipmentId: liveShipment.id,
        shipmentType: ShipmentType.air,
        price: 10);
    final deadPkg = ShippingPackage(
        customerId: live.id,
        shipmentId: liveShipment.id,
        shipmentType: ShipmentType.air,
        price: 20)
      ..deletedAt = DateTime.now();
    await storage.savePackage(livePkg);
    await storage.savePackage(deadPkg);
    expect(storage.getPackages().map((p) => p.id), [livePkg.id]);
  });

  test('singular getters return null for tombstones', () async {
    final dead = Customer(name: 'Dead', phone: '2')
      ..deletedAt = DateTime.now();
    await storage.saveCustomer(dead);
    expect(storage.getCustomer(dead.id), isNull);

    final deadShipment =
        Shipment(name: 'S2', type: ShipmentType.sea, destination: 'Ouaga')
          ..deletedAt = DateTime.now();
    await storage.saveShipment(deadShipment);
    expect(storage.getShipment(deadShipment.id), isNull);

    final deadPkg = ShippingPackage(
        customerId: 'c', shipmentId: 's', shipmentType: ShipmentType.air, price: 1)
      ..deletedAt = DateTime.now();
    await storage.savePackage(deadPkg);
    expect(storage.getPackage(deadPkg.id), isNull);
  });

  test('getPackage returns live packages', () async {
    final pkg = ShippingPackage(
        customerId: 'c', shipmentId: 's', shipmentType: ShipmentType.sea, price: 80);
    await storage.savePackage(pkg);
    expect(storage.getPackage(pkg.id)!.id, pkg.id);
  });
}
