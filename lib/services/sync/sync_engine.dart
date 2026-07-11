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
/// - Queue entries are removed ONLY after the cloud write is confirmed,
///   and only when their version still matches the pushed snapshot
///   (removeIfVersion) — a mid-push coalesced edit stays queued.
/// - Flush is FIFO and stops at the first failure (FK ordering).
/// - Pulls never overwrite a record that has a queued local edit.
/// - Deletes are tombstones: hidden locally at once, hard-deleted locally
///   only after the cloud acknowledges the tombstone.
class SyncEngine {
  final StorageService _storage;
  final SyncBackend _backend;
  final SyncQueue _queue;

  bool _isSyncing = false;
  bool _flushRequestedWhileSyncing = false;
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
    // Seed the initial state: onConnectivityChanged does not reliably emit
    // on subscribe, so an app launched offline would otherwise report online.
    final initial = await Connectivity().checkConnectivity();
    _hasConnectivity = initial.any((r) => r != ConnectivityResult.none);
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
    if (_backend.isAuthenticated && _hasConnectivity) unawaited(flush());
  }

  Future<void> saveShipment(Shipment shipment) async {
    shipment.updatedAt = DateTime.now();
    await _storage.saveShipment(shipment);
    await _queue.enqueue(
        table: 'shipments', recordId: shipment.id, data: shipment.toJson());
    if (_backend.isAuthenticated && _hasConnectivity) unawaited(flush());
  }

  Future<void> savePackage(ShippingPackage package) async {
    package.updatedAt = DateTime.now();
    await _storage.savePackage(package);
    await _queue.enqueue(
        table: 'packages', recordId: package.id, data: package.toJson());
    if (_backend.isAuthenticated && _hasConnectivity) unawaited(flush());
  }

  Future<void> deleteCustomer(String id) async {
    final customer = _storage.getCustomer(id);
    if (customer == null) return;
    _tombstone(customer);
    await _storage.saveCustomer(customer);
    await _queue.enqueue(
        table: 'customers', recordId: id, data: customer.toJson());
    if (_backend.isAuthenticated && _hasConnectivity) unawaited(flush());
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
    if (_backend.isAuthenticated && _hasConnectivity) unawaited(flush());
  }

  Future<void> deletePackage(String id) async {
    final package = _storage.getPackage(id);
    if (package == null) return;
    _tombstone(package);
    await _storage.savePackage(package);
    await _queue.enqueue(
        table: 'packages', recordId: id, data: package.toJson());
    if (_backend.isAuthenticated && _hasConnectivity) unawaited(flush());
  }

  void _tombstone(dynamic record) {
    final now = DateTime.now();
    record.deletedAt = now;
    record.updatedAt = now;
  }

  // ==================== FLUSH ====================

  Future<void> flush() async {
    if (_isSyncing) {
      // A round is already running: remember the request instead of dropping
      // it, so a write landing mid-push is flushed by the running call.
      _flushRequestedWhileSyncing = true;
      return;
    }
    if (!_backend.isAuthenticated || _queue.isEmpty) return;
    _isSyncing = true;
    onSyncStarted?.call();
    try {
      do {
        _flushRequestedWhileSyncing = false;
        await _flushQueue();
      } while (_flushRequestedWhileSyncing && !_queue.isEmpty);
      lastError = null;
      lastSyncedAt = DateTime.now();
      onSyncCompleted?.call();
    } catch (e) {
      // Catch-all, not just SyncBackendException: a corrupt queue entry that
      // fails to parse must surface as a visible sync error, never wedge the
      // queue silently.
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
      } catch (e) {
        await _queue.recordFailure(entry, e.toString());
        rethrow;
      }
      // Version guard: if the record was re-edited while this push was in
      // flight, the coalesced newer entry stays queued for the next round
      // instead of being dropped by an unconditional remove.
      final removed = await _queue.removeIfVersion(entry);
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
      default:
        // Acking an unknown entry would silently lose data; fail loudly and
        // keep it queued instead.
        throw StateError('Unknown sync table: ${entry.table}');
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

  // ==================== FULL SYNC ====================

  /// Push-then-pull under one lock. A flush failure records the error but
  /// does not block the pull: merging is safe because records with queued
  /// local edits are skipped. On success, a flush requested mid-sync (a
  /// write landing during the pull) is chained immediately instead of
  /// waiting for the next external trigger.
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

      // Bind this sync to the namespace it started in. If a sign-out/sign-in
      // switches namespaces while pullAll is in flight (e.g. _quiesceSync
      // timed out on a slow network), the merge must NOT write another
      // account's records into the now-active namespace.
      final boundNamespace = _storage.namespace;
      final snapshot = await _backend.pullAll();
      await _mergeSnapshot(snapshot, boundNamespace);

      if (!flushErrored) lastError = null;
      lastSyncedAt = DateTime.now();
      onSyncCompleted?.call();
    } catch (e) {
      lastError = e.toString();
      onSyncError?.call(lastError!);
    } finally {
      _isSyncing = false;
      if (_flushRequestedWhileSyncing && lastError == null) {
        _flushRequestedWhileSyncing = false;
        unawaited(flush());
      }
    }
  }

  Future<void> _mergeSnapshot(
    CloudSnapshot snapshot,
    String boundNamespace,
  ) async {
    // The merge runs many awaits; a namespace switch can interleave, so the
    // guard is re-checked per record, not just once up front.
    bool stillBound() => _storage.namespace == boundNamespace;

    final pendingCustomers = _queue.pendingRecordIds('customers');
    for (final cloud in snapshot.customers) {
      if (!stillBound()) return;
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
      if (!stillBound()) return;
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
      if (!stillBound()) return;
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
}
