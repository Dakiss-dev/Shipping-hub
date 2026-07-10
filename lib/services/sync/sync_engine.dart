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
