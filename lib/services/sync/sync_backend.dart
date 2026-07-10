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
