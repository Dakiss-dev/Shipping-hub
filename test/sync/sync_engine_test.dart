import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/storage_service.dart';
import 'package:shipping_hub/services/sync/sync_engine.dart';
import 'package:shipping_hub/services/sync/sync_queue.dart';
import 'fake_backend.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;
  late FakeBackend backend;
  late SyncQueue queue;
  late SyncEngine engine;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_engine_test');
    Hive.init(tempDir.path);
    storage = StorageService();
    await storage.initForTest();
    final queueBox = await Hive.openBox('sync_queue');
    backend = FakeBackend();
    queue = SyncQueue(() => queueBox);
    // NOTE: engine.init() is never called in tests — it subscribes to
    // connectivity_plus, which has no platform implementation here.
    engine = SyncEngine(storage, backend, queue);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
  });

  Customer makeCustomer({String? id, String name = 'Awa'}) =>
      Customer(id: id, name: name, phone: '70123456', phoneCountryCode: '+226');

  group('writes', () {
    test('saveCustomer persists locally and enqueues even when offline',
        () async {
      backend.authenticated = false;
      final customer = makeCustomer();
      await engine.saveCustomer(customer);
      expect(storage.getCustomers().single.name, 'Awa');
      expect(engine.pendingSyncCount, 1);
      expect(backend.customers, isEmpty);
    });

    test('saveCustomer stamps updatedAt', () async {
      backend.authenticated = false;
      final customer = makeCustomer();
      final before = customer.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await engine.saveCustomer(customer);
      expect(customer.updatedAt.isAfter(before), isTrue);
    });
  });

  group('flush', () {
    test('flush pushes FIFO and clears the queue on success', () async {
      backend.authenticated = false;
      final customer = makeCustomer(id: 'c1');
      final shipment = Shipment(
          id: 's1', name: 'X', type: ShipmentType.air, destination: 'Bamako');
      await engine.saveCustomer(customer);
      await engine.saveShipment(shipment);

      backend.authenticated = true;
      await engine.flush();

      expect(engine.pendingSyncCount, 0);
      expect(backend.callLog, ['upsertCustomer:c1', 'upsertShipment:s1']);
      expect(engine.lastError, isNull);
      expect(engine.lastSyncedAt, isNotNull);
    });

    test('a failed push keeps the entry queued and records the error',
        () async {
      backend.authenticated = false;
      await engine.saveCustomer(makeCustomer(id: 'c1'));
      backend.authenticated = true;
      backend.failUpsertsWith = 'boom';

      await engine.flush();

      expect(engine.pendingSyncCount, 1); // NOT dequeued — the old bug
      expect(engine.lastError, contains('boom'));
      expect(queue.entries().single.attempts, 1);
    });

    test('flush stops at the first failure to preserve FK order', () async {
      backend.authenticated = false;
      await engine.saveCustomer(makeCustomer(id: 'c1'));
      await engine.saveShipment(Shipment(
          id: 's1', name: 'X', type: ShipmentType.air, destination: 'Lome'));
      backend.authenticated = true;
      backend.failUpsertsWith = 'down';

      await engine.flush();

      // Only the first entry was attempted; the second never ran.
      expect(backend.callLog, ['upsertCustomer:c1']);
      expect(engine.pendingSyncCount, 2);
    });
  });

  group('tombstone deletes', () {
    test('delete hides locally, pushes tombstone, hard-deletes after ack',
        () async {
      backend.authenticated = false;
      final customer = makeCustomer(id: 'c1');
      await engine.saveCustomer(customer);
      await engine.deleteCustomer('c1');

      // Hidden from getters immediately, tombstone still queued.
      expect(storage.getCustomers(), isEmpty);
      expect(engine.pendingSyncCount, 1); // coalesced with the create

      backend.authenticated = true;
      await engine.flush();

      // Cloud got the tombstone; local copy is now hard-deleted.
      expect(backend.customers['c1']!.deletedAt, isNotNull);
      expect(engine.pendingSyncCount, 0);
      expect(Hive.box('customers').get('c1'), isNull);
    });

    test('deleteShipment tombstones its packages first', () async {
      backend.authenticated = false;
      await engine.saveCustomer(makeCustomer(id: 'c1'));
      final shipment = Shipment(
          id: 's1', name: 'X', type: ShipmentType.sea, destination: 'Ouaga');
      await engine.saveShipment(shipment);
      final pkg = ShippingPackage(
          id: 'p1',
          customerId: 'c1',
          shipmentId: 's1',
          shipmentType: ShipmentType.sea,
          price: 80);
      await engine.savePackage(pkg);

      await engine.deleteShipment('s1');

      expect(storage.getPackages(), isEmpty);
      expect(storage.getShipments(), isEmpty);

      backend.authenticated = true;
      await engine.flush();
      expect(backend.packages['p1']!.deletedAt, isNotNull);
      expect(backend.shipments['s1']!.deletedAt, isNotNull);
    });
  });
}
