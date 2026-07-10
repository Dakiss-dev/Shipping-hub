# Shipping Hub Foundation (Plan 1 of 5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the silently-lossy sync engine with a tested, correct one; fix the schema security holes; provision a live Supabase backend; and put CI in place.

**Architecture:** Hive stays the primary offline-first store. A new `SyncEngine` (behind a `SyncBackend` interface so tests use a fake) pushes a persistent FIFO queue where entries are removed only on confirmed success, flushes before every pull, merges by `updatedAt`, and propagates deletions via `deleted_at` tombstones. Hive boxes are namespaced per account. Schema v2 drops the RLS-bypassing public view, locks down the operators update policy, and adds `subscriptions`/`devices` tables for later plans.

**Tech Stack:** Flutter/Dart, Hive, Supabase (PostgreSQL + RLS), GitHub Actions.

**Working directory:** `/Users/alidakissaga/shipping-hub` on branch `feature/freemium-flagship`. Run every command from there.

**Baseline (verified 2026-07-10, corrected during Task 1):** `flutter analyze` reports 36 info-level issues plus 1 warning (unused import in `business_setup_screen.dart`, removed in Task 1) and zero errors; `flutter test` passes (1 smoke test). Info-level cleanup belongs to Plan 5, so CI runs analyze with `--no-fatal-infos`; warnings stay fatal.

**Spec:** `docs/superpowers/specs/2026-07-10-shipping-hub-freemium-design.md` (this plan covers the spec's Sections 1-2 plus CI from Section 7; Plans 2-5 cover the rest).

---

### Task 1: CI workflow + dependency cleanup

The repo has four dependencies with zero imports in `lib/` (`http`, `intl`, `path_provider`, `path`) and no CI. Establish a green baseline that every later task must keep green.

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Remove unused dependencies**

In `pubspec.yaml`, delete these four lines from `dependencies:`:

```yaml
  http: 1.5.0
  intl: ^0.20.2
  path_provider: ^2.1.5
  path: ^1.9.1
```

- [ ] **Step 2: Remove the warning-level unused import, then verify**

Delete line 4 (`import '../models/models.dart';` — flagged as unused_import, warning level) from `lib/screens/business_setup_screen.dart`.

Run: `flutter pub get && flutter analyze --no-fatal-infos && flutter test`
Expected: pub get succeeds, analyze ends with `36 issues found.` and exit code 0 (infos only — warnings are fatal, and the only warning is now gone), test output ends with `All tests passed!`

- [ ] **Step 3: Create the CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main, 'feature/**']
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze --no-fatal-infos
      - run: flutter test
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml pubspec.yaml pubspec.lock lib/screens/business_setup_screen.dart
git commit -m "chore: add CI workflow, remove unused deps, drop unused import"
```

---

### Task 2: Sync metadata on models + tombstone-aware storage

Every syncable model gains `updatedAt` (for merge decisions) and `deletedAt` (tombstones). `ShippingPackage.referenceNumber` becomes mutable so a rare local collision can be regenerated before first sync. Storage getters hide tombstoned records and gain the missing `getPackage(id)`.

**Files:**
- Modify: `lib/models/models.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `lib/providers/app_provider.dart` (addPackage collision guard)
- Test: `test/models_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/models_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models_test.dart`
Expected: FAIL — compile errors (`updatedAt` / `deletedAt` / `freshReference` not defined).

- [ ] **Step 3: Add the metadata to all three models**

In `lib/models/models.dart`, replace the `Customer` class fields/constructor/serialization with:

```dart
class Customer {
  final String id;
  String name;
  String phone;
  String phoneCountryCode;
  String? email;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;

  Customer({
    String? id,
    required this.name,
    required this.phone,
    this.phoneCountryCode = '+1',
    this.email,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  /// Full international phone number
  String get fullPhone {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return phone;
    if (phone.startsWith('+')) return phone; // Already international
    return '$phoneCountryCode$digits';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'phoneCountryCode': phoneCountryCode,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['createdAt'] as String);
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      phoneCountryCode: json['phoneCountryCode'] as String? ?? '+1',
      email: json['email'] as String?,
      createdAt: created,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : created,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }
}
```

Apply the same pattern to `Shipment`: add fields `DateTime updatedAt;` and `DateTime? deletedAt;`, constructor params `DateTime? updatedAt, this.deletedAt` with the same initializer (`updatedAt = updatedAt ?? createdAt ?? DateTime.now()`), add `'updatedAt': updatedAt.toIso8601String(), 'deletedAt': deletedAt?.toIso8601String(),` to `toJson`, and in `fromJson` parse them exactly like Customer (extract `final created = DateTime.parse(json['createdAt'] as String);` first and use it as the fallback).

Apply the same pattern to `ShippingPackage`, and additionally change its `referenceNumber` field from `final String` to mutable `String`, and add the static helper right after `_generateRefNumber()`:

```dart
  /// Public regeneration hook used when a local reference collision is
  /// detected before first sync.
  static String freshReference() => _generateRefNumber();
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Hide tombstones in storage and add the missing getter**

In `lib/services/storage_service.dart`:

Replace `getCustomers()`, `getShipments()`, `getPackages()` bodies so each filters tombstones. Example for customers (apply the same `.where((x) => x.deletedAt == null)` to all three):

```dart
  List<Customer> getCustomers() {
    final box = Hive.box(_customersBox);
    return box.values
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.deletedAt == null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
```

Replace `getCustomer()` and `getShipment()` so they return null for tombstones, and add the missing `getPackage()`. Pattern (apply to all three):

```dart
  Customer? getCustomer(String id) {
    final box = Hive.box(_customersBox);
    final data = box.get(id);
    if (data == null) return null;
    final customer = Customer.fromJson(Map<String, dynamic>.from(data as Map));
    return customer.deletedAt == null ? customer : null;
  }

  ShippingPackage? getPackage(String id) {
    final box = Hive.box(_packagesBox);
    final data = box.get(id);
    if (data == null) return null;
    final pkg = ShippingPackage.fromJson(Map<String, dynamic>.from(data as Map));
    return pkg.deletedAt == null ? pkg : null;
  }
```

Also split `init()` so tests can open boxes without `Hive.initFlutter()` (which needs platform channels):

```dart
  Future<void> init() async {
    await Hive.initFlutter();
    await _openBoxes();
  }

  /// Test hook: callers must run Hive.init(<temp dir>) first.
  Future<void> initForTest() async {
    await _openBoxes();
  }

  Future<void> _openBoxes() async {
    await Hive.openBox(_customersBox);
    await Hive.openBox(_shipmentsBox);
    await Hive.openBox(_packagesBox);
    await Hive.openBox(_settingsBox);
  }
```

- [ ] **Step 6: Add the reference-collision guard to AppProvider**

In `lib/providers/app_provider.dart`, replace `addPackage` with:

```dart
  Future<void> addPackage(ShippingPackage package) async {
    // Reference numbers only need to be unique per operator, and all of this
    // operator's packages are local — so collisions are caught here, before
    // the DB unique constraint ever fires.
    final existingRefs = {
      for (final p in _packages)
        if (p.id != package.id) p.referenceNumber,
    };
    var guard = 0;
    while (existingRefs.contains(package.referenceNumber) && guard < 10) {
      package.referenceNumber = ShippingPackage.freshReference();
      guard++;
    }
    await _sync.savePackage(package);
    _packages = _storage.getPackages();
    notifyListeners();
  }
```

- [ ] **Step 7: Verify everything still passes**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: analyze exit 0, `All tests passed!` (5 tests total).

- [ ] **Step 8: Commit**

```bash
git add lib/models/models.dart lib/services/storage_service.dart lib/providers/app_provider.dart test/models_test.dart
git commit -m "feat: sync metadata (updatedAt/deletedAt) on models, tombstone-aware storage"
```

---

### Task 3: Persistent SyncQueue with in-place coalescing

A dedicated queue class replaces the ad-hoc `sync_queue` handling. Coalescing in place (same Hive key) keeps one entry per record while preserving FIFO order — critical because a package must never be pushed before the customer it references.

**Files:**
- Create: `lib/services/sync/sync_queue.dart`
- Test: `test/sync/sync_queue_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/sync/sync_queue_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shipping_hub/services/sync/sync_queue.dart';

void main() {
  late Directory tempDir;
  late Box box;
  late SyncQueue queue;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_queue_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox('sync_queue');
    queue = SyncQueue(() => box);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
  });

  test('enqueue appends entries in FIFO order', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 1});
    await queue.enqueue(table: 'packages', recordId: 'p1', data: {'v': 1});
    final entries = queue.entries();
    expect(entries.map((e) => e.recordId).toList(), ['c1', 'p1']);
  });

  test('re-enqueueing a record coalesces in place, keeping its position', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 1});
    await queue.enqueue(table: 'packages', recordId: 'p1', data: {'v': 1});
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 2});
    final entries = queue.entries();
    expect(entries.length, 2);
    expect(entries.first.recordId, 'c1'); // still first — order preserved
    expect(entries.first.data['v'], 2); // but carries the latest data
  });

  test('remove deletes an entry; recordFailure tracks attempts and error', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {});
    final entry = queue.entries().single;
    await queue.recordFailure(entry.key, 'network down');
    final failed = queue.entries().single;
    expect(failed.attempts, 1);
    expect(failed.lastError, 'network down');
    expect(queue.firstError, 'network down');
    await queue.remove(failed.key);
    expect(queue.isEmpty, isTrue);
  });

  test('pendingRecordIds returns queued ids for one table only', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {});
    await queue.enqueue(table: 'packages', recordId: 'p1', data: {});
    expect(queue.pendingRecordIds('customers'), {'c1'});
    expect(queue.pendingRecordIds('shipments'), isEmpty);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/sync/sync_queue_test.dart`
Expected: FAIL — `sync_queue.dart` does not exist.

- [ ] **Step 3: Implement SyncQueue**

Create `lib/services/sync/sync_queue.dart`:

```dart
import 'package:hive/hive.dart';

/// One queued cloud write. Immutable snapshot of a Hive entry.
class SyncQueueEntry {
  final int key;
  final String table;
  final String recordId;
  final Map<String, dynamic> data;
  final int attempts;
  final String? lastError;

  SyncQueueEntry({
    required this.key,
    required this.table,
    required this.recordId,
    required this.data,
    required this.attempts,
    this.lastError,
  });

  factory SyncQueueEntry.fromBox(int key, Map raw) => SyncQueueEntry(
        key: key,
        table: raw['table'] as String,
        recordId: raw['recordId'] as String,
        data: Map<String, dynamic>.from(raw['data'] as Map),
        attempts: raw['attempts'] as int? ?? 0,
        lastError: raw['lastError'] as String?,
      );
}

/// Persistent FIFO queue of pending cloud writes.
///
/// Entries are removed only after the cloud write is confirmed. Re-enqueueing
/// a record coalesces IN PLACE (same Hive key) so the queue stays bounded and
/// FIFO order still reflects creation order — a package can never be flushed
/// before the customer it references.
///
/// The box is resolved through a getter so the active box can change when the
/// storage namespace switches (sign-in/sign-out) without rebuilding the queue.
class SyncQueue {
  final Box Function() _boxGetter;

  SyncQueue(this._boxGetter);

  Box get _box => _boxGetter();

  int get length => _box.length;
  bool get isEmpty => _box.isEmpty;

  Future<void> enqueue({
    required String table,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    final value = {
      'table': table,
      'recordId': recordId,
      'data': data,
      'attempts': 0,
      'lastError': null,
      'enqueuedAt': DateTime.now().toIso8601String(),
    };
    for (final key in _box.keys) {
      final raw = _box.get(key) as Map;
      if (raw['table'] == table && raw['recordId'] == recordId) {
        await _box.put(key, value);
        return;
      }
    }
    await _box.add(value);
  }

  List<SyncQueueEntry> entries() {
    final keys = _box.keys.cast<int>().toList()..sort();
    return [
      for (final k in keys) SyncQueueEntry.fromBox(k, _box.get(k) as Map),
    ];
  }

  Set<String> pendingRecordIds(String table) => {
        for (final e in entries())
          if (e.table == table) e.recordId,
      };

  Future<void> remove(int key) => _box.delete(key);

  Future<void> recordFailure(int key, String message) async {
    final raw = Map<String, dynamic>.from(_box.get(key) as Map);
    raw['attempts'] = (raw['attempts'] as int? ?? 0) + 1;
    raw['lastError'] = message;
    await _box.put(key, raw);
  }

  /// The oldest recorded failure, for surfacing in the sync status UI.
  String? get firstError {
    for (final e in entries()) {
      if (e.lastError != null) return e.lastError;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/sync/sync_queue_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/sync/sync_queue.dart test/sync/sync_queue_test.dart
git commit -m "feat: persistent sync queue with in-place coalescing"
```

---

### Task 4: SyncBackend contract + Supabase row mappers

The engine talks to an abstract `SyncBackend` (fake in tests, Supabase in production). Row mappers live in their own file so the country-code fix is directly unit-testable. This kills the bug where `upsertCustomer` hardcoded `'+1'` and the pull dropped the column.

**Files:**
- Create: `lib/services/sync/sync_backend.dart`
- Create: `lib/services/sync/row_mappers.dart`
- Test: `test/sync/row_mappers_test.dart`

- [ ] **Step 1: Create the contract (no test — pure interface)**

Create `lib/services/sync/sync_backend.dart`:

```dart
import '../../models/models.dart';

/// Everything the current operator has in the cloud, already parsed into
/// models (with updatedAt/deletedAt populated from the cloud columns).
class CloudSnapshot {
  final List<Customer> customers;
  final List<Shipment> shipments;
  final List<ShippingPackage> packages;

  const CloudSnapshot({
    this.customers = const [],
    this.shipments = const [],
    this.packages = const [],
  });
}

/// Thrown when a cloud operation fails. The sync queue keeps the entry.
class SyncBackendException implements Exception {
  final String table;
  final String recordId;
  final Object cause;

  SyncBackendException(this.table, this.recordId, this.cause);

  @override
  String toString() => 'Sync failed ($table/$recordId): $cause';
}

/// Cloud persistence used by SyncEngine. Implemented by SupabaseBackend in
/// production and FakeBackend in tests. Deletions are tombstone upserts
/// (deletedAt set), so there are no delete methods.
abstract class SyncBackend {
  bool get isAuthenticated;
  String? get currentUserId;

  Future<void> upsertCustomer(Customer customer);
  Future<void> upsertShipment(Shipment shipment);
  Future<void> upsertPackage(ShippingPackage package);
  Future<CloudSnapshot> pullAll();
}
```

- [ ] **Step 2: Write the failing mapper tests**

Create `test/sync/row_mappers_test.dart`:

```dart
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/sync/row_mappers_test.dart`
Expected: FAIL — `row_mappers.dart` does not exist.

- [ ] **Step 4: Implement the mappers**

Create `lib/services/sync/row_mappers.dart`:

```dart
import '../../models/models.dart';

/// Model <-> Postgres row mapping (snake_case columns).
///
/// The pushed updated_at is advisory: the DB trigger overwrites it with
/// NOW() on conflicting upserts. That is safe — the merge protects unflushed
/// local edits via the pending-queue check, not clock comparison.
///
/// All timestamps are serialized in UTC ('Z' suffix): Dart's
/// toIso8601String() on a local DateTime carries no offset, and Postgres
/// timestamptz would misread it as UTC, corrupting the instant.
///
/// Parsing converts back to local time: the app's display sites (receipts,
/// detail screens) format zone-sensitive fields and expect local DateTimes.

Map<String, dynamic> customerToRow(Customer c, String operatorId) => {
      'id': c.id,
      'operator_id': operatorId,
      'name': c.name,
      'phone': c.phone,
      'phone_country_code': c.phoneCountryCode,
      'email': c.email,
      'created_at': c.createdAt.toUtc().toIso8601String(),
      'updated_at': c.updatedAt.toUtc().toIso8601String(),
      'deleted_at': c.deletedAt?.toUtc().toIso8601String(),
      'synced_at': DateTime.now().toUtc().toIso8601String(),
    };

Customer customerFromRow(Map<String, dynamic> row) => Customer(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String,
      phoneCountryCode: row['phone_country_code'] as String? ?? '+1',
      email: row['email'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String).toLocal()
          : null,
    );

Map<String, dynamic> shipmentToRow(Shipment s, String operatorId) => {
      'id': s.id,
      'operator_id': operatorId,
      'name': s.name,
      'type': s.type.name,
      'destination': s.destination,
      'status': s.status.name,
      'departure_date': s.departureDate?.toUtc().toIso8601String(),
      'estimated_arrival': s.estimatedArrival?.toUtc().toIso8601String(),
      'notes': s.notes,
      'created_at': s.createdAt.toUtc().toIso8601String(),
      'updated_at': s.updatedAt.toUtc().toIso8601String(),
      'deleted_at': s.deletedAt?.toUtc().toIso8601String(),
      'synced_at': DateTime.now().toUtc().toIso8601String(),
    };

Shipment shipmentFromRow(Map<String, dynamic> row) => Shipment(
      id: row['id'] as String,
      name: row['name'] as String,
      type: ShipmentType.values.firstWhere((e) => e.name == row['type']),
      destination: row['destination'] as String,
      status:
          ShipmentStatus.values.firstWhere((e) => e.name == row['status']),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      departureDate: row['departure_date'] != null
          ? DateTime.parse(row['departure_date'] as String).toLocal()
          : null,
      estimatedArrival: row['estimated_arrival'] != null
          ? DateTime.parse(row['estimated_arrival'] as String).toLocal()
          : null,
      notes: row['notes'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String).toLocal()
          : null,
    );

Map<String, dynamic> packageToRow(ShippingPackage p, String operatorId) => {
      'id': p.id,
      'operator_id': operatorId,
      'customer_id': p.customerId,
      'shipment_id': p.shipmentId,
      'reference_number': p.referenceNumber,
      'shipment_type': p.shipmentType.name,
      'photo_url': p.photoPath,
      'description': p.description,
      'weight_kg': p.weightKg,
      'sea_item_type': p.seaItemType?.name,
      'preset_item_name': p.presetItemName,
      'price': p.price,
      'payment_status': p.paymentStatus.name,
      'notes': p.notes,
      'receiver_name': p.receiverName,
      'receiver_phone': p.receiverPhone,
      'receiver_phone_country_code': p.receiverPhoneCountryCode,
      'created_at': p.createdAt.toUtc().toIso8601String(),
      'updated_at': p.updatedAt.toUtc().toIso8601String(),
      'deleted_at': p.deletedAt?.toUtc().toIso8601String(),
      'synced_at': DateTime.now().toUtc().toIso8601String(),
    };

ShippingPackage packageFromRow(Map<String, dynamic> row) => ShippingPackage(
      id: row['id'] as String,
      referenceNumber: row['reference_number'] as String,
      customerId: row['customer_id'] as String,
      shipmentId: row['shipment_id'] as String,
      shipmentType: ShipmentType.values
          .firstWhere((e) => e.name == row['shipment_type']),
      photoPath: row['photo_url'] as String?,
      description: row['description'] as String? ?? '',
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      seaItemType: row['sea_item_type'] != null
          ? SeaItemType.values
              .firstWhere((e) => e.name == row['sea_item_type'])
          : null,
      presetItemName: row['preset_item_name'] as String?,
      price: (row['price'] as num).toDouble(),
      paymentStatus: PaymentStatus.values
          .firstWhere((e) => e.name == row['payment_status']),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      notes: row['notes'] as String?,
      receiverName: row['receiver_name'] as String?,
      receiverPhone: row['receiver_phone'] as String?,
      receiverPhoneCountryCode:
          row['receiver_phone_country_code'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String).toLocal()
          : null,
    );
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/sync/row_mappers_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/services/sync/sync_backend.dart lib/services/sync/row_mappers.dart test/sync/row_mappers_test.dart
git commit -m "feat: SyncBackend contract and row mappers (fixes phone country code loss)"
```

---

### Task 5: SyncEngine — writes, tombstone deletes, flush

The heart of the fix. Writes stamp `updatedAt`, land in Hive, enqueue, and trigger a fire-and-forget flush. The flush removes queue entries ONLY on confirmed success and stops at the first failure (preserving FK order). Deletes are tombstones: hidden locally immediately, hard-deleted locally only after the cloud acknowledges.

**Files:**
- Create: `lib/services/sync/sync_engine.dart`
- Create: `test/sync/fake_backend.dart`
- Test: `test/sync/sync_engine_test.dart`

- [ ] **Step 1: Create the fake backend**

Create `test/sync/fake_backend.dart`:

```dart
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/sync/sync_backend.dart';

/// In-memory SyncBackend with failure injection and a call log.
class FakeBackend implements SyncBackend {
  bool authenticated = true;
  String? userId = 'op-1';

  final List<String> callLog = [];
  final Map<String, Customer> customers = {};
  final Map<String, Shipment> shipments = {};
  final Map<String, ShippingPackage> packages = {};

  /// When set, every UPSERT throws a SyncBackendException wrapping it.
  /// pullAll is controlled separately by failPullWith, so tests can verify
  /// that a failed flush does not block the pull.
  Object? failUpsertsWith;

  /// When set, pullAll() throws a SyncBackendException wrapping it.
  Object? failPullWith;

  /// Returned by the next pullAll() call.
  CloudSnapshot nextSnapshot = const CloudSnapshot();

  @override
  bool get isAuthenticated => authenticated;

  @override
  String? get currentUserId => userId;

  @override
  Future<void> upsertCustomer(Customer customer) async {
    callLog.add('upsertCustomer:${customer.id}');
    if (failUpsertsWith != null) {
      throw SyncBackendException('customers', customer.id, failUpsertsWith!);
    }
    customers[customer.id] = customer;
  }

  @override
  Future<void> upsertShipment(Shipment shipment) async {
    callLog.add('upsertShipment:${shipment.id}');
    if (failUpsertsWith != null) {
      throw SyncBackendException('shipments', shipment.id, failUpsertsWith!);
    }
    shipments[shipment.id] = shipment;
  }

  @override
  Future<void> upsertPackage(ShippingPackage package) async {
    callLog.add('upsertPackage:${package.id}');
    if (failUpsertsWith != null) {
      throw SyncBackendException('packages', package.id, failUpsertsWith!);
    }
    packages[package.id] = package;
  }

  @override
  Future<CloudSnapshot> pullAll() async {
    callLog.add('pullAll');
    if (failPullWith != null) {
      throw SyncBackendException('pull_all', '-', failPullWith!);
    }
    return nextSnapshot;
  }
}
```

- [ ] **Step 2: Write the failing engine tests**

Create `test/sync/sync_engine_test.dart`:

```dart
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/sync/sync_engine_test.dart`
Expected: FAIL — `sync_engine.dart` does not exist.

- [ ] **Step 4: Implement SyncEngine (flush half)**

Create `lib/services/sync/sync_engine.dart`:

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../models/models.dart';
import '../storage_service.dart';
import 'sync_backend.dart';
import 'sync_queue.dart';

/// Offline-first sync engine v2.
///
/// Invariants:
/// - Hive is the primary store; every write lands locally first.
/// - Queue entries are removed ONLY after the cloud write is confirmed.
/// - Flush is FIFO and stops at the first failure (FK ordering).
/// - fullSync flushes BEFORE pulling, under the same lock.
/// - Pulls never overwrite a record that has a queued local edit.
/// - Deletes are tombstones: hidden locally at once, hard-deleted locally
///   only after the cloud acknowledges the tombstone.
class SyncEngine {
  final StorageService _storage;
  final SyncBackend _backend;
  final SyncQueue _queue;

  bool _isSyncing = false;
  bool _hasConnectivity = true;
  DateTime? lastSyncedAt;
  String? lastError;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void Function()? onSyncStarted;
  void Function()? onSyncCompleted;
  void Function(String message)? onSyncError;

  SyncEngine(this._storage, this._backend, this._queue);

  bool get isSyncing => _isSyncing;
  bool get isOnline => _hasConnectivity;
  int get pendingSyncCount => _queue.length;
  String? get firstQueueError => _queue.firstError;

  Future<void> init() async {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      _hasConnectivity = results.any((r) => r != ConnectivityResult.none);
      if (_hasConnectivity && _backend.isAuthenticated) {
        unawaited(flush());
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  // ==================== WRITES ====================

  Future<void> saveCustomer(Customer customer) async {
    customer.updatedAt = DateTime.now();
    await _storage.saveCustomer(customer);
    await _queue.enqueue(
        table: 'customers', recordId: customer.id, data: customer.toJson());
    if (_backend.isAuthenticated) unawaited(flush());
  }

  Future<void> saveShipment(Shipment shipment) async {
    shipment.updatedAt = DateTime.now();
    await _storage.saveShipment(shipment);
    await _queue.enqueue(
        table: 'shipments', recordId: shipment.id, data: shipment.toJson());
    if (_backend.isAuthenticated) unawaited(flush());
  }

  Future<void> savePackage(ShippingPackage package) async {
    package.updatedAt = DateTime.now();
    await _storage.savePackage(package);
    await _queue.enqueue(
        table: 'packages', recordId: package.id, data: package.toJson());
    if (_backend.isAuthenticated) unawaited(flush());
  }

  Future<void> deleteCustomer(String id) async {
    final customer = _storage.getCustomer(id);
    if (customer == null) return;
    _tombstone(customer);
    await _storage.saveCustomer(customer);
    await _queue.enqueue(
        table: 'customers', recordId: id, data: customer.toJson());
    if (_backend.isAuthenticated) unawaited(flush());
  }

  Future<void> deleteShipment(String id) async {
    for (final pkg in _storage.getPackagesForShipment(id)) {
      await deletePackage(pkg.id);
    }
    final shipment = _storage.getShipment(id);
    if (shipment == null) return;
    _tombstone(shipment);
    await _storage.saveShipment(shipment);
    await _queue.enqueue(
        table: 'shipments', recordId: id, data: shipment.toJson());
    if (_backend.isAuthenticated) unawaited(flush());
  }

  Future<void> deletePackage(String id) async {
    final package = _storage.getPackage(id);
    if (package == null) return;
    _tombstone(package);
    await _storage.savePackage(package);
    await _queue.enqueue(
        table: 'packages', recordId: id, data: package.toJson());
    if (_backend.isAuthenticated) unawaited(flush());
  }

  void _tombstone(dynamic record) {
    final now = DateTime.now();
    record.deletedAt = now;
    record.updatedAt = now;
  }

  // ==================== FLUSH ====================

  Future<void> flush() async {
    if (_isSyncing || !_backend.isAuthenticated || _queue.isEmpty) return;
    _isSyncing = true;
    onSyncStarted?.call();
    try {
      await _flushQueue();
      lastError = null;
      lastSyncedAt = DateTime.now();
      onSyncCompleted?.call();
    } on SyncBackendException catch (e) {
      lastError = e.toString();
      onSyncError?.call(lastError!);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _flushQueue() async {
    for (final entry in _queue.entries()) {
      try {
        await _pushEntry(entry);
      } on SyncBackendException catch (e) {
        await _queue.recordFailure(entry.key, e.toString());
        rethrow;
      }
      // Version guard: if the record was re-edited while this push was in
      // flight, the coalesced newer entry stays queued for the next round
      // instead of being dropped by an unconditional remove.
      final removed = await _queue.removeIfVersion(entry.key, entry.version);
      if (removed) {
        await _hardDeleteIfTombstone(entry);
      }
    }
  }

  Future<void> _pushEntry(SyncQueueEntry entry) async {
    switch (entry.table) {
      case 'customers':
        await _backend.upsertCustomer(Customer.fromJson(entry.data));
      case 'shipments':
        await _backend.upsertShipment(Shipment.fromJson(entry.data));
      case 'packages':
        await _backend.upsertPackage(ShippingPackage.fromJson(entry.data));
    }
  }

  Future<void> _hardDeleteIfTombstone(SyncQueueEntry entry) async {
    if (entry.data['deletedAt'] == null) return;
    switch (entry.table) {
      case 'customers':
        await _storage.deleteCustomer(entry.recordId);
      case 'shipments':
        await _storage.deleteShipment(entry.recordId);
      case 'packages':
        await _storage.deletePackage(entry.recordId);
    }
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/sync/sync_engine_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/services/sync/sync_engine.dart test/sync/fake_backend.dart test/sync/sync_engine_test.dart
git commit -m "feat: SyncEngine with confirmed-success queue and tombstone deletes"
```

---

### Task 6: SyncEngine — fullSync with timestamp merge

`fullSync` flushes first (under the same lock — the old `_isSyncing` guard-ordering bug is regression-tested here), then pulls and merges: queued records win, cloud tombstones remove local copies, otherwise newest `updatedAt` wins. A flush failure no longer blocks the pull — merging is safe because queued records are skipped.

**Files:**
- Modify: `lib/services/sync/sync_engine.dart`
- Test: `test/sync/sync_engine_test.dart` (add a group)

- [ ] **Step 1: Write the failing tests**

Append this group inside `main()` in `test/sync/sync_engine_test.dart` (before the closing `}`):

```dart
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
      expect(Hive.box('customers').get('c1'), isNull);
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
  });
```

- [ ] **Step 2: Run tests to verify the new group fails**

Run: `flutter test test/sync/sync_engine_test.dart`
Expected: FAIL — `fullSync` not defined (the Task 5 tests still pass).

- [ ] **Step 3: Implement fullSync and the merge**

Add to `lib/services/sync/sync_engine.dart`, after the `_hardDeleteIfTombstone` method (still inside the class):

```dart
  // ==================== FULL SYNC ====================

  /// Push-then-pull under one lock. A flush failure records the error but
  /// does not block the pull: merging is safe because records with queued
  /// local edits are skipped.
  Future<void> fullSync() async {
    if (_isSyncing || !_backend.isAuthenticated) return;
    _isSyncing = true;
    onSyncStarted?.call();
    var flushErrored = false;
    try {
      try {
        await _flushQueue();
      } catch (e) {
        // Catch-all mirrors flush(): a corrupt entry must surface, not wedge.
        flushErrored = true;
        lastError = e.toString();
        onSyncError?.call(lastError!);
      }

      final snapshot = await _backend.pullAll();
      await _mergeSnapshot(snapshot);

      if (!flushErrored) lastError = null;
      lastSyncedAt = DateTime.now();
      onSyncCompleted?.call();
    } catch (e) {
      lastError = e.toString();
      onSyncError?.call(lastError!);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _mergeSnapshot(CloudSnapshot snapshot) async {
    final pendingCustomers = _queue.pendingRecordIds('customers');
    for (final cloud in snapshot.customers) {
      if (pendingCustomers.contains(cloud.id)) continue;
      if (cloud.deletedAt != null) {
        await _storage.deleteCustomer(cloud.id);
        continue;
      }
      final local = _storage.getCustomer(cloud.id);
      if (local == null || cloud.updatedAt.isAfter(local.updatedAt)) {
        await _storage.saveCustomer(cloud);
      }
    }

    final pendingShipments = _queue.pendingRecordIds('shipments');
    for (final cloud in snapshot.shipments) {
      if (pendingShipments.contains(cloud.id)) continue;
      if (cloud.deletedAt != null) {
        await _storage.deleteShipment(cloud.id);
        continue;
      }
      final local = _storage.getShipment(cloud.id);
      if (local == null || cloud.updatedAt.isAfter(local.updatedAt)) {
        await _storage.saveShipment(cloud);
      }
    }

    final pendingPackages = _queue.pendingRecordIds('packages');
    for (final cloud in snapshot.packages) {
      if (pendingPackages.contains(cloud.id)) continue;
      if (cloud.deletedAt != null) {
        await _storage.deletePackage(cloud.id);
        continue;
      }
      final local = _storage.getPackage(cloud.id);
      if (local == null || cloud.updatedAt.isAfter(local.updatedAt)) {
        await _storage.savePackage(cloud);
      }
    }
  }
```

- [ ] **Step 4: Run the full sync test file**

Run: `flutter test test/sync/sync_engine_test.dart`
Expected: PASS (13 tests).

- [ ] **Step 5: Run everything**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: analyze exit 0, `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/services/sync/sync_engine.dart test/sync/sync_engine_test.dart
git commit -m "feat: fullSync with flush-before-pull and timestamp merge"
```

---

### Task 7: SupabaseBackend + slim SupabaseService

Wire the contract to Supabase. CRUD moves out of `SupabaseService` into `SupabaseBackend` (which throws instead of swallowing); `SupabaseService` keeps auth and operator profile only. The dead `trackPackage` (which queried the soon-to-be-dropped insecure view) and `pullAllData` are deleted.

**Files:**
- Create: `lib/services/sync/supabase_backend.dart`
- Modify: `lib/services/supabase_service.dart`

- [ ] **Step 1: Implement SupabaseBackend**

Create `lib/services/sync/supabase_backend.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import 'row_mappers.dart';
import 'sync_backend.dart';

/// Production SyncBackend over Supabase PostgREST.
///
/// Every operation THROWS SyncBackendException on failure — the engine's
/// queue depends on that to keep unconfirmed entries. Never swallow here.
///
/// The client is resolved through a getter because Supabase.initialize()
/// completes after this object is constructed.
class SupabaseBackend implements SyncBackend {
  final SupabaseClient? Function() _clientGetter;

  SupabaseBackend(this._clientGetter);

  SupabaseClient? get _client => _clientGetter();

  @override
  bool get isAuthenticated => _client?.auth.currentUser != null;

  @override
  String? get currentUserId => _client?.auth.currentUser?.id;

  @override
  Future<void> upsertCustomer(Customer customer) async {
    try {
      await _client!
          .from('customers')
          .upsert(customerToRow(customer, currentUserId!));
    } catch (e) {
      throw SyncBackendException('customers', customer.id, e);
    }
  }

  @override
  Future<void> upsertShipment(Shipment shipment) async {
    try {
      await _client!
          .from('shipments')
          .upsert(shipmentToRow(shipment, currentUserId!));
    } catch (e) {
      throw SyncBackendException('shipments', shipment.id, e);
    }
  }

  @override
  Future<void> upsertPackage(ShippingPackage package) async {
    try {
      await _client!
          .from('packages')
          .upsert(packageToRow(package, currentUserId!));
    } catch (e) {
      throw SyncBackendException('packages', package.id, e);
    }
  }

  @override
  Future<CloudSnapshot> pullAll() async {
    try {
      final uid = currentUserId!;
      final results = await Future.wait([
        _client!.from('customers').select().eq('operator_id', uid),
        _client!.from('shipments').select().eq('operator_id', uid),
        _client!.from('packages').select().eq('operator_id', uid),
      ]);
      return CloudSnapshot(
        customers: _mapRows(results[0], customerFromRow, 'customers'),
        shipments: _mapRows(results[1], shipmentFromRow, 'shipments'),
        packages: _mapRows(results[2], packageFromRow, 'packages'),
      );
    } catch (e) {
      throw SyncBackendException('pull_all', '-', e);
    }
  }

  /// Version-skew guard: one malformed row (e.g. an enum value written by a
  /// newer app build) must not crash the whole pull. Bad rows are skipped
  /// and logged; everything else still syncs.
  List<T> _mapRows<T>(
    dynamic rows,
    T Function(Map<String, dynamic>) fromRow,
    String table,
  ) {
    final mapped = <T>[];
    for (final r in rows as List) {
      try {
        mapped.add(fromRow(Map<String, dynamic>.from(r as Map)));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Sync] Skipping unparseable $table row: $e');
        }
      }
    }
    return mapped;
  }
}
```

- [ ] **Step 2: Slim down SupabaseService**

In `lib/services/supabase_service.dart`, delete these members entirely (they moved to `SupabaseBackend` or die with the insecure view):

- the `// ==================== CUSTOMERS ====================` section (`getCustomers`, `upsertCustomer`, `deleteCustomer`)
- the `// ==================== SHIPMENTS ====================` section (`getShipments`, `upsertShipment`, `deleteShipment`)
- the `// ==================== PACKAGES ====================` section (`getPackages`, `upsertPackage`, `deletePackage`)
- the `// ==================== PUBLIC TRACKING ====================` section (`trackPackage`)
- the `// ==================== BATCH SYNC ====================` section (`pullAllData`)
- the now-unused `import '../models/models.dart';` line

Keep: `initialize`, all auth methods, `getOperatorProfile`, `updateOperatorProfile`, `_ensureOperatorProfile`. Also update the class doc comment (line 6-7) to be honest:

```dart
/// Supabase service layer for auth and the operator profile.
/// Entity CRUD lives in SupabaseBackend (lib/services/sync/supabase_backend.dart).
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze --no-fatal-infos`
Expected: errors in `lib/services/sync_service.dart` and possibly `lib/providers/app_provider.dart` referencing removed methods are NOT acceptable — but at this point the old `sync_service.dart` still calls `_supabase.upsertCustomer` etc. That file dies in Task 9. To keep this task compiling, delete the old engine now:

```bash
git rm lib/services/sync_service.dart
```

Then stub the provider so it compiles: in `lib/providers/app_provider.dart`, replace the line

```dart
import '../services/sync_service.dart';
```

with

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../services/sync/supabase_backend.dart';
import '../services/sync/sync_engine.dart';
import '../services/sync/sync_queue.dart';
```

and replace the field

```dart
  final SyncService _sync = SyncService.instance;
```

with

```dart
  late final SyncEngine _sync;
```

then in `init()`, replace

```dart
    await _storage.init();
    await _sync.init();
```

with

```dart
    await _storage.init();
    final queueBox = await Hive.openBox('sync_queue');
    _sync = SyncEngine(
      _storage,
      SupabaseBackend(() => _supabase.client),
      SyncQueue(() => queueBox),
    );
    await _sync.init();
```

and replace the body of `syncSettings` usage: the old engine had `syncSettings`; the new one does not. Replace the five `_sync.syncSettings(...)` calls in `setLanguage`, `setOperatorName`, `setCurrency`, `updateAirPricing`, `updateSeaPricing` with `unawaited(_syncSettings(...))` using the same named arguments (e.g. `unawaited(_syncSettings(language: lang));`), add `import 'dart:async';` at the top, and add this private method after `manualSync`:

```dart
  /// Settings sync is direct (not queued): last write wins is correct for
  /// profile fields, and failures surface through _settingsSyncError.
  String? _settingsSyncError;

  Future<void> _syncSettings({
    String? businessName,
    String? currency,
    String? language,
    AirPricingConfig? airPricing,
    SeaPricingConfig? seaPricing,
  }) async {
    if (!_supabase.isAuthenticated) return;
    final data = <String, dynamic>{};
    if (businessName != null) data['business_name'] = businessName;
    if (currency != null) data['currency'] = currency;
    if (language != null) data['language'] = language;
    if (airPricing != null) data['air_pricing'] = airPricing.toJson();
    if (seaPricing != null) data['sea_pricing'] = seaPricing.toJson();
    if (data.isEmpty) return;
    try {
      await _supabase.updateOperatorProfile(data);
      _settingsSyncError = null;
    } catch (e) {
      _settingsSyncError = e.toString();
      notifyListeners();
    }
  }
```

(The full provider rewiring — namespaces, status getters — is Task 9; this step only keeps the build green.)

- [ ] **Step 4: Verify**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: analyze exit 0 (info-level only), `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add -A lib/services lib/providers/app_provider.dart
git commit -m "feat: SupabaseBackend (throwing CRUD), slim SupabaseService, drop dead tracking code"
```

---

### Task 8: Account-namespaced storage with legacy migration

Hive boxes become `<namespace>_customers` etc., where namespace is the Supabase user id or `local`. A one-time migration moves pre-namespacing bare boxes into the active namespace. This kills cross-account data bleed on shared devices.

Known limitation (accepted in spec review): data in the `local` namespace does not auto-import into an account namespace on sign-in — that migration UX ships with Plan 2's local-only mode. There are no distributed installs today, so no real user hits this.

**Files:**
- Modify: `lib/services/storage_service.dart` (full rewrite)
- Test: `test/storage_namespace_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/storage_namespace_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/storage_namespace_test.dart`
Expected: FAIL — `initForTest` has no `namespace` parameter, `switchNamespace` not defined.

- [ ] **Step 3: Rewrite StorageService**

Replace the entire contents of `lib/services/storage_service.dart` with:

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Hive-backed primary store, namespaced per account.
///
/// Box names are '<namespace>_customers' etc., where namespace is the
/// Supabase user id or 'local' when signed out. Namespacing prevents one
/// account's data (or queued sync writes) from leaking into another account
/// on a shared device.
class StorageService {
  static const List<String> _baseBoxes = [
    'customers',
    'shipments',
    'packages',
    'settings',
    'sync_queue',
  ];

  String _namespace = 'local';
  String get namespace => _namespace;

  String _name(String base) => '${_namespace}_$base';

  Box get _customersBox => Hive.box(_name('customers'));
  Box get _shipmentsBox => Hive.box(_name('shipments'));
  Box get _packagesBox => Hive.box(_name('packages'));
  Box get _settingsBox => Hive.box(_name('settings'));

  /// The sync queue box for the active namespace. SyncQueue resolves this
  /// through a getter so namespace switches apply transparently.
  Box get syncQueueBox => Hive.box(_name('sync_queue'));

  Future<void> init({String namespace = 'local'}) async {
    await Hive.initFlutter();
    await _openNamespace(namespace);
  }

  /// Test hook: callers must run Hive.init(<temp dir>) first.
  Future<void> initForTest({String namespace = 'local'}) async {
    await _openNamespace(namespace);
  }

  Future<void> switchNamespace(String namespace) async {
    if (namespace == _namespace) return;
    await _openNamespace(namespace);
  }

  Future<void> _openNamespace(String namespace) async {
    _namespace = namespace;
    for (final base in _baseBoxes) {
      await Hive.openBox(_name(base));
    }
    await _migrateLegacyBoxes();
  }

  /// One-time migration: pre-namespacing installs stored data in bare boxes
  /// ('customers', ...). Copy into the active namespace, then delete.
  Future<void> _migrateLegacyBoxes() async {
    for (final base in _baseBoxes) {
      if (!await Hive.boxExists(base)) continue;
      final legacy = await Hive.openBox(base);
      final target = Hive.box(_name(base));
      if (legacy.isNotEmpty && target.isEmpty) {
        for (final key in legacy.keys) {
          await target.put(key, legacy.get(key));
        }
      }
      await legacy.deleteFromDisk();
    }
  }

  // ==================== CUSTOMERS ====================

  List<Customer> getCustomers() {
    return _customersBox.values
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.deletedAt == null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> saveCustomer(Customer customer) async {
    await _customersBox.put(customer.id, customer.toJson());
  }

  Future<void> deleteCustomer(String id) async {
    await _customersBox.delete(id);
  }

  Customer? getCustomer(String id) {
    final data = _customersBox.get(id);
    if (data == null) return null;
    final customer = Customer.fromJson(Map<String, dynamic>.from(data as Map));
    return customer.deletedAt == null ? customer : null;
  }

  // ==================== SHIPMENTS ====================

  List<Shipment> getShipments() {
    return _shipmentsBox.values
        .map((e) => Shipment.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((s) => s.deletedAt == null)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Shipment> getActiveShipments() {
    return getShipments()
        .where((s) =>
            s.status == ShipmentStatus.open ||
            s.status == ShipmentStatus.closed)
        .toList();
  }

  Future<void> saveShipment(Shipment shipment) async {
    await _shipmentsBox.put(shipment.id, shipment.toJson());
  }

  Future<void> deleteShipment(String id) async {
    await _shipmentsBox.delete(id);
  }

  Shipment? getShipment(String id) {
    final data = _shipmentsBox.get(id);
    if (data == null) return null;
    final shipment = Shipment.fromJson(Map<String, dynamic>.from(data as Map));
    return shipment.deletedAt == null ? shipment : null;
  }

  // ==================== PACKAGES ====================

  List<ShippingPackage> getPackages() {
    return _packagesBox.values
        .map(
            (e) => ShippingPackage.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.deletedAt == null)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ShippingPackage> getPackagesForShipment(String shipmentId) {
    return getPackages().where((p) => p.shipmentId == shipmentId).toList();
  }

  Future<void> savePackage(ShippingPackage package) async {
    await _packagesBox.put(package.id, package.toJson());
  }

  Future<void> deletePackage(String id) async {
    await _packagesBox.delete(id);
  }

  ShippingPackage? getPackage(String id) {
    final data = _packagesBox.get(id);
    if (data == null) return null;
    final pkg =
        ShippingPackage.fromJson(Map<String, dynamic>.from(data as Map));
    return pkg.deletedAt == null ? pkg : null;
  }

  // ==================== SETTINGS ====================

  String getLanguage() =>
      _settingsBox.get('language', defaultValue: 'en') as String;

  Future<void> setLanguage(String lang) async {
    await _settingsBox.put('language', lang);
  }

  String getOperatorName() => _settingsBox.get('operatorName',
      defaultValue: 'My Shipping Business') as String;

  Future<void> setOperatorName(String name) async {
    await _settingsBox.put('operatorName', name);
  }

  String getCurrency() =>
      _settingsBox.get('currency', defaultValue: 'USD') as String;

  Future<void> setCurrency(String currency) async {
    await _settingsBox.put('currency', currency);
  }

  AirPricingConfig getAirPricing() {
    final data = _settingsBox.get('airPricing');
    if (data == null) return AirPricingConfig();
    return AirPricingConfig.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> setAirPricing(AirPricingConfig config) async {
    await _settingsBox.put('airPricing', config.toJson());
  }

  SeaPricingConfig getSeaPricing() {
    final data = _settingsBox.get('seaPricing');
    if (data == null) return SeaPricingConfig();
    return SeaPricingConfig.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> setSeaPricing(SeaPricingConfig config) async {
    await _settingsBox.put('seaPricing', config.toJson());
  }
}
```

- [ ] **Step 4: Update the engine tests' box references**

Task 5/6 tests reference bare box names. In `test/sync/sync_engine_test.dart`:
- change `await storage.initForTest();` to `await storage.initForTest(namespace: 'local');`
- change `final queueBox = await Hive.openBox('sync_queue');` and the `SyncQueue(() => queueBox)` line to use the storage-owned box: `queue = SyncQueue(() => storage.syncQueueBox);` (delete the `queueBox` line)
- change both `Hive.box('customers')` assertions to `Hive.box('local_customers')`

- [ ] **Step 5: Run all tests**

Run: `flutter test`
Expected: `All tests passed!` (models 4, queue 4, mappers 4, engine 13, namespace 3, widget 1 = 29 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/services/storage_service.dart test/storage_namespace_test.dart test/sync/sync_engine_test.dart
git commit -m "feat: account-namespaced Hive storage with legacy migration"
```

---

### Task 9: AppProvider rewiring — namespaces on auth change, sync status

The provider constructs the engine against the namespaced queue box, switches namespaces on sign-in/up/out, pulls pricing with the profile, and exposes sync status to the UI.

**Files:**
- Modify: `lib/providers/app_provider.dart`

- [ ] **Step 1: Rewire init to namespace-aware order**

Replace the whole `init()` method with (Supabase first, so the namespace is known before boxes open):

```dart
  Future<void> init() async {
    // Supabase first: the storage namespace is the signed-in user id.
    await _supabase.initialize();
    await _storage.init(namespace: _supabase.currentUserId ?? 'local');

    _sync = SyncEngine(
      _storage,
      SupabaseBackend(() => _supabase.client),
      SyncQueue(() => _storage.syncQueueBox),
    );
    await _sync.init();

    _sync.onSyncStarted = () {
      _isSyncing = true;
      notifyListeners();
    };
    _sync.onSyncCompleted = () {
      _isSyncing = false;
      _loadAll(); // Reload from Hive after sync
      notifyListeners();
    };
    _sync.onSyncError = (error) {
      _isSyncing = false;
      notifyListeners();
    };

    _loadAll();
    _isLoading = false;
    notifyListeners();

    // If already authenticated, do a background sync
    if (_supabase.isAuthenticated) {
      unawaited(_sync.fullSync());
    }
  }
```

Also change the `_sync` field declaration from `late final SyncEngine _sync;` (Task 7) to `late SyncEngine _sync;` if the analyzer complains about reassignment (it should not — init runs once).

Remove the now-obsolete `Hive.openBox('sync_queue')` line added in Task 7 and its `import 'package:hive_flutter/hive_flutter.dart';` if no longer referenced.

- [ ] **Step 2: Switch namespaces on auth transitions**

In `signUp`, after `await _supabase.signUp(...)`, replace the `if (_supabase.isAuthenticated) { ... }` block with:

```dart
      if (_supabase.isAuthenticated) {
        await _storage.switchNamespace(_supabase.currentUserId!);
        // Re-persist the business name into the fresh account namespace.
        await _storage.setOperatorName(bName);
        await _sync.fullSync();
        _loadAll();
        notifyListeners();
      }
```

In `signIn`, replace the `if (_supabase.isAuthenticated) { ... }` block with:

```dart
      if (_supabase.isAuthenticated) {
        await _storage.switchNamespace(_supabase.currentUserId!);
        // Pull operator profile FIRST so business name is correct immediately
        await _pullOperatorProfile();
        await _sync.fullSync();
        _loadAll();
        notifyListeners();
      }
```

Replace `signOut` with:

```dart
  Future<void> signOut() async {
    try {
      await _supabase.signOut();
      await _storage.switchNamespace('local');
      _loadAll();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] Sign out error: $e');
    }
  }
```

- [ ] **Step 3: Pull pricing with the profile**

In `_pullOperatorProfile`, add before the closing brace of the `if (profile != null) {` block:

```dart
        if (profile['air_pricing'] != null) {
          final airData =
              Map<String, dynamic>.from(profile['air_pricing'] as Map);
          await _storage.setAirPricing(AirPricingConfig.fromJson(airData));
        }
        if (profile['sea_pricing'] != null) {
          final seaData =
              Map<String, dynamic>.from(profile['sea_pricing'] as Map);
          await _storage.setSeaPricing(SeaPricingConfig.fromJson(seaData));
        }
```

- [ ] **Step 4: Expose sync status**

Replace the `int get pendingSyncCount => _sync.pendingSyncCount;` getter area (the auth-state getters block) so it reads:

```dart
  int get pendingSyncCount => _isLoading ? 0 : _sync.pendingSyncCount;
  DateTime? get lastSyncedAt => _isLoading ? null : _sync.lastSyncedAt;
  String? get syncError => _isLoading
      ? null
      : _settingsSyncError ?? _sync.lastError ?? _sync.firstQueueError;
```

And replace `manualSync` with:

```dart
  Future<void> manualSync() async {
    if (!_supabase.isAuthenticated) return;
    await _sync.fullSync();
    _loadAll();
    notifyListeners();
  }
```

(The engine's callbacks now drive `_isSyncing`; manualSync no longer sets it directly.)

- [ ] **Step 5: Verify**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: analyze exit 0, `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/providers/app_provider.dart
git commit -m "feat: namespace-aware AppProvider with visible sync status"
```

---

### Task 10: Sync status in Settings

The operator must never wrongly believe data is backed up. Settings' Cloud Sync card gains a last-synced label and an error row with retry.

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Show last-synced time on the Sync Now tile**

In `lib/screens/settings_screen.dart`, the Sync Now `ListTile` (currently around line 233) has this subtitle:

```dart
                      subtitle: provider.pendingSyncCount > 0
                          ? Text('${provider.pendingSyncCount} changes pending',
                              style: const TextStyle(color: AppColors.warning, fontSize: 12))
                          : const Text('All data synced', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
```

Replace it with:

```dart
                      subtitle: provider.pendingSyncCount > 0
                          ? Text('${provider.pendingSyncCount} changes pending',
                              style: const TextStyle(color: AppColors.warning, fontSize: 12))
                          : Text(
                              provider.lastSyncedAt != null
                                  ? 'All synced • ${_clock(provider.lastSyncedAt!)}'
                                  : 'All data synced',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
```

And add this helper as a top-level function at the bottom of the file:

```dart
String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
```

- [ ] **Step 2: Add the error row**

Directly after the closing `),` of that same Sync Now `ListTile` (before the `const Divider(),` that precedes the Sign Out tile), insert:

```dart
                    if (provider.syncError != null) ...[
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sync_problem,
                            color: AppColors.danger),
                        title: const Text('Sync issue',
                            style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          provider.syncError!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: TextButton(
                          onPressed:
                              provider.isSyncing ? null : () => provider.manualSync(),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
```

- [ ] **Step 3: Verify**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: analyze exit 0, `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: sync status and retry surfaced in Settings"
```

---

### Task 11: Schema v2

Full rewrite of `supabase/schema.sql`: the anon-readable view dies, `operators` updates are column-restricted, tombstone and tracking columns arrive, and `subscriptions`/`devices` land (RLS-locked; enforcement triggers come in Plan 3).

**Files:**
- Modify: `supabase/schema.sql` (full replacement)

- [ ] **Step 1: Replace supabase/schema.sql entirely with:**

```sql
-- ============================================================
-- SHIPPING HUB - Supabase Multi-Tenant Schema v2
-- Fresh project: run whole file in SQL Editor (or apply_migration).
-- Upgrading from v1: this file is idempotent-ish via IF NOT EXISTS,
-- and the DROP VIEW below removes v1's insecure tracking view.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- v1 cleanup: this view bypassed RLS and exposed every tenant's data to anon.
DROP VIEW IF EXISTS public_package_tracking;

-- ==================== OPERATORS (profiles) ====================
CREATE TABLE IF NOT EXISTS operators (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  business_name TEXT NOT NULL DEFAULT 'My Shipping Business',
  phone TEXT,
  currency TEXT NOT NULL DEFAULT 'USD',
  language TEXT NOT NULL DEFAULT 'en',
  air_pricing JSONB NOT NULL DEFAULT '{
    "pricePerKg": 8.0,
    "presetItems": {
      "Phone": 25.0,
      "Laptop": 50.0,
      "Tablet": 35.0,
      "Small Electronics": 20.0,
      "Documents/Envelope": 15.0,
      "Shoes (pair)": 15.0,
      "Clothing Bundle": 20.0
    }
  }'::jsonb,
  sea_pricing JSONB NOT NULL DEFAULT '{
    "pricePerKg": 3.0,
    "itemPrices": {
      "smallBarrel": 80.0,
      "largeBarrel": 150.0,
      "car": 1500.0,
      "mattress": 100.0,
      "television": 75.0,
      "furniture": 120.0,
      "electronics": 60.0
    }
  }'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==================== CUSTOMERS ====================
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  phone_country_code TEXT NOT NULL DEFAULT '+1',
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  local_id TEXT,
  synced_at TIMESTAMPTZ
);

-- ==================== SHIPMENTS ====================
CREATE TABLE IF NOT EXISTS shipments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('air', 'sea')),
  destination TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'inTransit', 'delivered')),
  departure_date TIMESTAMPTZ,
  estimated_arrival TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  local_id TEXT,
  synced_at TIMESTAMPTZ
);

-- ==================== PACKAGES ====================
CREATE TABLE IF NOT EXISTS packages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  reference_number TEXT NOT NULL,
  -- Unguessable capability for the Plan 4 public tracking page. Never
  -- exposed through an anon-readable view; lookups go through a
  -- rate-limited Edge Function.
  tracking_token UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
  shipment_type TEXT NOT NULL CHECK (shipment_type IN ('air', 'sea')),
  photo_url TEXT,
  description TEXT DEFAULT '',
  weight_kg DOUBLE PRECISION,
  sea_item_type TEXT,
  preset_item_name TEXT,
  price DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid')),
  notes TEXT,
  receiver_name TEXT,
  receiver_phone TEXT,
  receiver_phone_country_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  local_id TEXT,
  synced_at TIMESTAMPTZ,
  UNIQUE (operator_id, reference_number)
);

-- ==================== SUBSCRIPTIONS (entitlements) ====================
-- Written ONLY by the service-role Stripe webhook (Plan 3). Clients can
-- read their own row and nothing else — a client-writable plan column
-- would be self-upgradable via raw PostgREST.
CREATE TABLE IF NOT EXISTS subscriptions (
  operator_id UUID PRIMARY KEY REFERENCES operators(id) ON DELETE CASCADE,
  plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'past_due', 'canceled')),
  current_period_end TIMESTAMPTZ,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==================== DEVICES ====================
-- Free plan: one registered device (transferable). Enforcement trigger
-- ships with Plan 3; the table exists now so the schema is stable.
CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  operator_id UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  label TEXT,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (operator_id, device_id)
);

-- ==================== INDEXES ====================
CREATE INDEX IF NOT EXISTS idx_customers_operator ON customers(operator_id);
CREATE INDEX IF NOT EXISTS idx_shipments_operator ON shipments(operator_id);
CREATE INDEX IF NOT EXISTS idx_packages_operator ON packages(operator_id);
CREATE INDEX IF NOT EXISTS idx_packages_shipment ON packages(shipment_id);
CREATE INDEX IF NOT EXISTS idx_packages_customer ON packages(customer_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(operator_id, phone);

-- ==================== ROW LEVEL SECURITY ====================

ALTER TABLE operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- Anon gets nothing, ever. RLS already denies (no anon policies), but
-- revoking the default table grants removes the entire surface.
REVOKE ALL ON operators, customers, shipments, packages, subscriptions, devices FROM anon;

-- OPERATORS
CREATE POLICY "operators_select_own" ON operators
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "operators_insert_own" ON operators
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "operators_update_own" ON operators
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Column-restrict operator updates: clients may edit profile fields only.
-- (id/email stay immutable from the client; entitlements never live here.)
REVOKE UPDATE ON operators FROM authenticated;
GRANT UPDATE (business_name, phone, currency, language, air_pricing, sea_pricing)
  ON operators TO authenticated;

-- CUSTOMERS
CREATE POLICY "customers_select_own" ON customers
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "customers_insert_own" ON customers
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "customers_update_own" ON customers
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "customers_delete_own" ON customers
  FOR DELETE USING (auth.uid() = operator_id);

-- SHIPMENTS
CREATE POLICY "shipments_select_own" ON shipments
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "shipments_insert_own" ON shipments
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "shipments_update_own" ON shipments
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "shipments_delete_own" ON shipments
  FOR DELETE USING (auth.uid() = operator_id);

-- PACKAGES
CREATE POLICY "packages_select_own" ON packages
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "packages_insert_own" ON packages
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "packages_update_own" ON packages
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "packages_delete_own" ON packages
  FOR DELETE USING (auth.uid() = operator_id);

-- SUBSCRIPTIONS: read-only for the owner; ALL writes via service role.
CREATE POLICY "subscriptions_select_own" ON subscriptions
  FOR SELECT USING (auth.uid() = operator_id);

REVOKE INSERT, UPDATE, DELETE ON subscriptions FROM authenticated;

-- DEVICES: owner manages their own device registrations.
CREATE POLICY "devices_select_own" ON devices
  FOR SELECT USING (auth.uid() = operator_id);

CREATE POLICY "devices_insert_own" ON devices
  FOR INSERT WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "devices_update_own" ON devices
  FOR UPDATE USING (auth.uid() = operator_id) WITH CHECK (auth.uid() = operator_id);

CREATE POLICY "devices_delete_own" ON devices
  FOR DELETE USING (auth.uid() = operator_id);

-- ==================== TRIGGERS ====================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_operators_updated_at
  BEFORE UPDATE ON operators
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_shipments_updated_at
  BEFORE UPDATE ON shipments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_packages_updated_at
  BEFORE UPDATE ON packages
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- NOTE: no trigger on auth.users — Supabase hosted projects block them.
-- Operator profiles are created app-side (_ensureOperatorProfile), and a
-- default subscriptions row is created by the Plan 3 entitlement flow.
```

- [ ] **Step 2: Sanity-check the SQL locally (static)**

Run: `grep -c "CREATE POLICY" supabase/schema.sql`
Expected: `20` (operators 3, customers 4, shipments 4, packages 4, subscriptions 1, devices 4)

Run: `grep -n "public_package_tracking" supabase/schema.sql`
Expected: exactly one match — the `DROP VIEW` line.

- [ ] **Step 3: Commit**

```bash
git add supabase/schema.sql
git commit -m "feat: schema v2 - drop insecure tracking view, tombstones, tracking tokens, subscriptions/devices, hardened RLS"
```

---

### Task 12: Provision the live backend + end-to-end verification

Create the fresh Supabase project, apply schema v2, wire env config, and verify the whole foundation against the real backend.

**Files:**
- Create: `env.example.json`
- Create: `env.json` (gitignored — real values)
- Modify: `.gitignore`
- Modify: `README.md`

- [ ] **Step 1: Create the Supabase project**

Using the Supabase MCP tools (available in this session):
1. `list_organizations` → pick Ali's org.
2. `get_cost` for a new project → expect free tier ($0), then `confirm_cost`.
3. `create_project` with name `shipping-hub`, the confirmed cost id, and region `us-east-1`.
4. Wait for the project to become active (`get_project`), then `apply_migration` with name `schema_v2` and the full contents of `supabase/schema.sql`.
5. `get_project_url` and `get_publishable_keys` → note the URL and anon key.

Fallback without MCP: create the project at database.new, paste `supabase/schema.sql` into the SQL Editor, and copy the URL/anon key from Project Settings > API.

- [ ] **Step 2: Configure auth for foundation testing**

In the Supabase Dashboard (Authentication > Sign In / Up > Email): temporarily **disable "Confirm email"**. Rationale: the verify-email deep-link flow ships in Plan 2; with confirmation on, mobile signups cannot complete and every e2e test stalls. Plan 2 re-enables it the moment the deep links land. Record this as a pending item in the Plan 2 handoff.

- [ ] **Step 3: Wire env config**

Create `env.example.json`:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_ANON_KEY"
}
```

Create `env.json` with the real values from Step 1 (same shape).

Append to `.gitignore`:

```
# Local Supabase credentials (anon key is public-ish, but keep the repo clean)
env.json
```

- [ ] **Step 4: Update the README run instructions**

In `README.md`, replace the `## Run it` code block with:

```bash
flutter pub get

# create a Supabase project, apply supabase/schema.sql, then:
cp env.example.json env.json   # fill in your project URL + anon key
flutter run --dart-define-from-file=env.json
```

- [ ] **Step 5: End-to-end verification (web)**

Run: `flutter run -d chrome --dart-define-from-file=env.json`

Walk this checklist in the running app:
1. Onboarding → sign up with a fresh email + password → business setup wizard → dashboard loads.
2. Add a customer with a +226 phone number; create a shipment; add a package to it with a receiver (+223).
3. In Supabase Table Editor: `operators` has 1 row; `customers.phone_country_code` = `+226` (THE bug this plan kills); `packages.receiver_phone_country_code` = `+223`; `packages.tracking_token` is populated.
4. Settings → Sync Now → "All synced • HH:MM" appears.
5. Delete the package in-app → `packages.deleted_at` is set in Table Editor (tombstone pushed), package gone from app lists.
6. DevTools > Network > Offline: add another customer → Settings shows "1 changes pending" (no crash). Back online → Sync Now → pending clears, row appears in Table Editor.
7. Sign out → sign back in → all data returns (pull + namespace switch worked).
8. Anonymous read is dead: `curl -s "https://<PROJECT_REF>.supabase.co/rest/v1/packages?select=*" -H "apikey: <ANON_KEY>"` returns a permission-denied error object (code 42501 — grants revoked from anon, not just RLS-filtered), and `.../rest/v1/public_package_tracking?select=*` returns a 404 error object (view gone).

Expected: every step passes. Any failure: stop and fix before committing.

- [ ] **Step 6: Final full check and commit**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: analyze exit 0, `All tests passed!`

```bash
git add env.example.json .gitignore README.md
git commit -m "feat: live Supabase backend provisioning + env-file config"
git push -u origin feature/freemium-flagship
```

Confirm CI goes green on GitHub for the pushed branch.

---

## Plan self-review notes

- **Spec coverage (this plan's slice):** Section 1 backend items (subscriptions, devices, tracking_token, tombstone columns, hardened operators policy, view drop, ref uniqueness) → Tasks 11-12. Section 2 sync items (no swallowed exceptions, flush-before-pull, timestamp merge, tombstone propagation, namespaced Hive, visible sync status, connectivity-based isOnline, country-code fix) → Tasks 2-10. Section 7 CI → Task 1. Storage bucket + Edge Functions intentionally deferred (Plan 3/4 per decomposition). Dashboard sync indicator deferred to Plan 4's pull-to-refresh fix (spec groups it there).
- **Known deviations, agreed during design:** local→account data migration UX deferred to Plan 2; email confirmation temporarily disabled until Plan 2's deep links; per-record retry backoff is flush-round-based, not timer-based.
- **Type consistency verified:** `SyncEngine(storage, backend, queue)`, `SyncQueue(Box Function())`, `StorageService.initForTest({namespace})`, `syncQueueBox`, `freshReference()`, `firstQueueError` used consistently across tasks.

## Review-driven amendments during execution

Logged as each task's two-stage review lands; the code blocks above have been updated in place.

- **Task 1:** baseline corrected (36 infos + 1 warning, not 37 infos); warning-level unused import removed in `business_setup_screen.dart`; CI hardened with pinned `flutter-version: '3.44.0'`, concurrency cancellation, `permissions: contents: read`, `timeout-minutes: 10`.
- **Task 2:** backfilled `test/storage_service_test.dart` (tombstone filtering, singular getters, getPackage); debugPrint on collision-guard exhaustion; `_savePackage` in `new_package_screen.dart` made async so the receipt SnackBar reads the post-guard reference number. Residual: collision-guard regeneration test lands with Task 9 when the provider becomes testable.
- **Task 3:** entry `version` field + `removeIfVersion(key, expectedVersion)` close a coalesce-during-flush data-loss race; Task 5's flush loop uses the guard and gates tombstone hard-deletes on successful removal; attempts/lastError reset on coalesce documented and tested.
- **Task 4:** all row timestamps serialized via `.toUtc()` (offset-less local ISO strings would be misread as UTC by timestamptz, corrupting instants); wire-shaped PostgREST payload test; unknown-enum StateError documented by test. Per-row crash isolation added to Task 7's `pullAll` (`_mapRows` skips unparseable rows).
- **Task 5:** four review findings fixed (commit 028263b, applied inline by the coordinator during a subagent session-limit outage, verified by gates): (1) flush() rerun flag — a flush requested mid-round reruns in the same call instead of being dropped, so mid-push edits are never stranded; (2) catch-all error handling in flush() plus `default: throw` in `_pushEntry` — corrupt or unknown queue entries surface as visible sync errors instead of wedging the queue silently; (3) `removeIfVersion`/`recordFailure` are entry-based and identity-guarded (table + recordId + version), hardening against stale snapshots across namespace switches; (4) `init()` seeds connectivity via `checkConnectivity()` and auto-flush triggers gate on `_hasConnectivity` (explicit flush stays ungated). Five tests added (engine 11, queue 8). Carried to Task 9: quiesce `_isSyncing` before namespace switch and clear engine error state on switch. Task 6's fullSync catches updated to match.
- **Task 4 (second round):** `*FromRow` normalizes all parsed timestamps via `.toLocal()` — three display sites (`package_detail_screen.dart:286`, `app_provider.dart` receipts) format zone-sensitive fields, and UTC DateTimes would print wrong calendar days on receipts after a cloud restore.
