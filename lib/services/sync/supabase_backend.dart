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
