import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_ns_test');
    Hive.init(tempDir.path);
    storage = StorageService();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
  });

  test('namespaces isolate data between accounts', () async {
    await storage.initForTest(namespace: 'user-a');
    await storage.saveCustomer(Customer(name: 'A', phone: '1'));
    expect(storage.getCustomers(), hasLength(1));

    await storage.switchNamespace('user-b');
    expect(storage.getCustomers(), isEmpty);

    await storage.switchNamespace('user-a');
    expect(storage.getCustomers(), hasLength(1));
  });

  test('legacy bare boxes migrate into the active namespace once', () async {
    // Simulate a pre-namespacing install.
    final legacy = await Hive.openBox('customers');
    final customer = Customer(name: 'Legacy', phone: '5');
    await legacy.put(customer.id, customer.toJson());
    await legacy.close();

    await storage.initForTest(namespace: 'local');
    expect(storage.getCustomers().single.name, 'Legacy');
    expect(await Hive.boxExists('customers'), isFalse); // legacy removed
  });

  test('settings are per-namespace', () async {
    await storage.initForTest(namespace: 'user-a');
    await storage.setOperatorName('Business A');
    await storage.switchNamespace('user-b');
    expect(storage.getOperatorName(), 'My Shipping Business'); // default
  });
}
