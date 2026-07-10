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
