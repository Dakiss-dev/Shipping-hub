import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/storage_service.dart';
import 'package:shipping_hub/services/sync/sync_backend.dart';
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
    await storage.initForTest(namespace: 'local');
    backend = FakeBackend();
    queue = SyncQueue(() => storage.syncQueueBox);
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
      expect(Hive.box('local_customers').get('c1'), isNull);
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

  group('flush hardening', () {
    test('an edit during an in-flight push survives and syncs in the same call',
        () async {
      backend.authenticated = false;
      final customer = makeCustomer(id: 'c1', name: 'v1');
      await engine.saveCustomer(customer);

      backend.authenticated = true;
      backend.upsertGate = Completer<void>();
      final flushFuture = engine.flush();
      await Future<void>.delayed(Duration.zero); // flush reaches the gate

      // Edit mid-push: coalesces to version 2, auto-trigger is swallowed by
      // the _isSyncing guard but sets the rerun flag.
      customer.name = 'v2';
      await engine.saveCustomer(customer);

      backend.upsertGate!.complete();
      backend.upsertGate = null;
      await flushFuture;

      // Both versions pushed in ONE flush call; the newer one wins in cloud.
      expect(backend.callLog, ['upsertCustomer:c1', 'upsertCustomer:c1']);
      expect(backend.customers['c1']!.name, 'v2');
      expect(engine.pendingSyncCount, 0);
      expect(storage.getCustomer('c1')!.name, 'v2');
    });

    test('a failed tombstone push stays hidden locally but is not hard-deleted',
        () async {
      backend.authenticated = false;
      await engine.saveCustomer(makeCustomer(id: 'c1'));
      await engine.deleteCustomer('c1');
      backend.authenticated = true;
      backend.failUpsertsWith = 'down';

      await engine.flush();

      expect(engine.pendingSyncCount, 1); // tombstone still queued
      expect(storage.getCustomers(), isEmpty); // still hidden
      expect(
          Hive.box('local_customers').get('c1'), isNotNull); // NOT hard-deleted
      expect(engine.lastError, contains('down'));
    });

    test('a corrupt queue entry surfaces an error instead of wedging silently',
        () async {
      backend.authenticated = false;
      await queue.enqueue(
          table: 'customers', recordId: 'bad', data: {'nonsense': true});
      backend.authenticated = true;

      await engine.flush();

      expect(engine.lastError, isNotNull);
      expect(engine.pendingSyncCount, 1); // kept, with the failure recorded
      expect(queue.entries().single.attempts, 1);
    });

    test('an unknown table entry errors loudly instead of being acked',
        () async {
      backend.authenticated = false;
      await queue.enqueue(table: 'widgets', recordId: 'w1', data: {});
      backend.authenticated = true;

      await engine.flush();

      expect(engine.pendingSyncCount, 1);
      expect(engine.lastError, contains('widgets'));
    });
  });

  group('fullSync', () {
    test('flushes queued writes BEFORE pulling (guard-ordering regression)',
        () async {
      backend.authenticated = false;
      await engine.saveCustomer(makeCustomer(id: 'c1'));
      backend.authenticated = true;

      await engine.fullSync();

      expect(backend.callLog.first, 'upsertCustomer:c1');
      expect(backend.callLog.last, 'pullAll');
      expect(engine.pendingSyncCount, 0);
    });

    test('cloud record newer than local overwrites it', () async {
      backend.authenticated = false;
      final local = makeCustomer(id: 'c1', name: 'Old Name');
      await engine.saveCustomer(local);
      backend.authenticated = true;
      await engine.flush(); // queue is now empty

      final cloud = makeCustomer(id: 'c1', name: 'New Name')
        ..updatedAt = DateTime.now().add(const Duration(minutes: 1));
      backend.nextSnapshot = CloudSnapshot(customers: [cloud]);

      await engine.fullSync();
      expect(storage.getCustomer('c1')!.name, 'New Name');
    });

    test('local record newer than cloud is kept', () async {
      backend.authenticated = false;
      final local = makeCustomer(id: 'c1', name: 'Fresh Local');
      await engine.saveCustomer(local);
      backend.authenticated = true;
      await engine.flush();

      final cloud = makeCustomer(id: 'c1', name: 'Stale Cloud')
        ..updatedAt = DateTime.now().subtract(const Duration(days: 1));
      backend.nextSnapshot = CloudSnapshot(customers: [cloud]);

      await engine.fullSync();
      expect(storage.getCustomer('c1')!.name, 'Fresh Local');
    });

    test('a record with a queued local edit is never overwritten', () async {
      backend.authenticated = false;
      await engine.saveCustomer(makeCustomer(id: 'c1', name: 'Queued Edit'));

      // Cloud claims to be newer, but the local edit hasn't flushed yet.
      final cloud = makeCustomer(id: 'c1', name: 'Cloud Version')
        ..updatedAt = DateTime.now().add(const Duration(hours: 1));
      backend.nextSnapshot = CloudSnapshot(customers: [cloud]);
      backend.authenticated = true;
      backend.failUpsertsWith = 'flush blocked'; // flush fails, pull proceeds

      await engine.fullSync();

      // The merge RAN (pull succeeded) but skipped c1 because its edit is
      // still queued — this is the line that protects unflushed local edits.
      expect(storage.getCustomer('c1')!.name, 'Queued Edit');
      expect(engine.pendingSyncCount, 1);
    });

    test('a cloud tombstone removes the local record', () async {
      backend.authenticated = false;
      await engine.saveCustomer(makeCustomer(id: 'c1'));
      backend.authenticated = true;
      await engine.flush();

      final tombstone = makeCustomer(id: 'c1')
        ..deletedAt = DateTime.now()
        ..updatedAt = DateTime.now();
      backend.nextSnapshot = CloudSnapshot(customers: [tombstone]);

      await engine.fullSync();
      expect(storage.getCustomer('c1'), isNull);
      expect(Hive.box('local_customers').get('c1'), isNull);
    });

    test('flush failure during fullSync still pulls (error recorded)',
        () async {
      backend.authenticated = false;
      await engine.saveCustomer(makeCustomer(id: 'c1'));
      backend.authenticated = true;
      backend.failUpsertsWith = 'network down';

      await engine.fullSync();

      expect(engine.lastError, contains('network down'));
      expect(engine.pendingSyncCount, 1);
      expect(backend.callLog, contains('pullAll'));
    });

    test('a namespace switch during the pull aborts the merge (no leak)',
        () async {
      backend.authenticated = true;
      backend.nextSnapshot =
          CloudSnapshot(customers: [makeCustomer(id: 'c1', name: 'Account A')]);
      backend.pullGate = Completer<void>();

      final syncFuture = engine.fullSync();
      await Future<void>.delayed(Duration.zero); // parks on the gated pull

      // Sign-out racing a slow pull: switch to a different namespace while the
      // merge is still pending. The pulled record must NOT land anywhere.
      await storage.switchNamespace('other');

      backend.pullGate!.complete();
      backend.pullGate = null;
      await syncFuture;

      expect(storage.getCustomer('c1'), isNull); // not in 'other'
      expect(Hive.box('other_customers').get('c1'), isNull);
      expect(Hive.box('local_customers').get('c1'), isNull); // not in 'local'
    });

    test('a write during the pull is flushed right after the sync', () async {
      backend.authenticated = true;
      backend.pullGate = Completer<void>();
      final syncFuture = engine.fullSync();
      await Future<void>.delayed(Duration.zero); // fullSync parks on the pull

      // This write's auto-trigger is swallowed (_isSyncing) but sets the
      // rerun flag; fullSync chains a flush on success so it isn't stranded.
      await engine.saveCustomer(makeCustomer(id: 'c1'));

      backend.pullGate!.complete();
      backend.pullGate = null;
      await syncFuture;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(backend.customers.containsKey('c1'), isTrue);
      expect(engine.pendingSyncCount, 0);
    });
  });
}
