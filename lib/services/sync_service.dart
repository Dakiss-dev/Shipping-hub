import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import 'supabase_service.dart';
import 'storage_service.dart';

/// Offline-first sync engine.
/// Hive is ALWAYS the primary data store. Supabase syncs in the background.
/// 
/// Architecture:
/// 1. All writes go to Hive FIRST (instant, works offline)
/// 2. Writes are queued in a "pending sync" box
/// 3. When connectivity is detected, queue is flushed to Supabase
/// 4. On login, full pull from Supabase merges with local data
class SyncService {
  static SyncService? _instance;
  final StorageService _storage = StorageService();
  final SupabaseService _supabase = SupabaseService.instance;
  
  late Box _syncQueueBox;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  bool _initialized = false;

  // Callbacks for UI updates
  VoidCallback? onSyncStarted;
  VoidCallback? onSyncCompleted;
  Function(String)? onSyncError;

  SyncService._();

  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  bool get isOnline => _supabase.isAuthenticated;
  bool get isSyncing => _isSyncing;

  /// Initialize sync service
  Future<void> init() async {
    if (_initialized) return;
    _syncQueueBox = await Hive.openBox('sync_queue');
    _initialized = true;

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((result) {
      // result is a List<ConnectivityResult>
      final hasConnection = result.any((r) => r != ConnectivityResult.none);
      if (hasConnection && _supabase.isAuthenticated) {
        _flushSyncQueue();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  // ==================== SYNC QUEUE ====================

  /// Add an operation to the sync queue
  Future<void> _enqueueSync(String table, String operation, String id, Map<String, dynamic> data) async {
    final entry = {
      'table': table,
      'operation': operation, // 'upsert' or 'delete'
      'id': id,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _syncQueueBox.add(entry);
    
    // Try to sync immediately if online
    if (_supabase.isAuthenticated) {
      _flushSyncQueue();
    }
  }

  /// Flush pending sync queue to Supabase
  Future<void> _flushSyncQueue() async {
    if (_isSyncing || !_supabase.isAuthenticated) return;
    if (_syncQueueBox.isEmpty) return;

    _isSyncing = true;
    onSyncStarted?.call();

    try {
      final keys = _syncQueueBox.keys.toList();
      
      for (final key in keys) {
        final entry = Map<String, dynamic>.from(_syncQueueBox.get(key) as Map);
        final table = entry['table'] as String;
        final operation = entry['operation'] as String;
        final id = entry['id'] as String;

        try {
          if (operation == 'delete') {
            switch (table) {
              case 'customers':
                await _supabase.deleteCustomer(id);
                break;
              case 'shipments':
                await _supabase.deleteShipment(id);
                break;
              case 'packages':
                await _supabase.deletePackage(id);
                break;
            }
          } else if (operation == 'upsert') {
            switch (table) {
              case 'customers':
                final customer = Customer.fromJson(Map<String, dynamic>.from(entry['data'] as Map));
                await _supabase.upsertCustomer(customer);
                break;
              case 'shipments':
                final shipment = Shipment.fromJson(Map<String, dynamic>.from(entry['data'] as Map));
                await _supabase.upsertShipment(shipment);
                break;
              case 'packages':
                final pkg = ShippingPackage.fromJson(Map<String, dynamic>.from(entry['data'] as Map));
                await _supabase.upsertPackage(pkg);
                break;
            }
          }
          // Successfully synced - remove from queue
          await _syncQueueBox.delete(key);
        } catch (e) {
          if (kDebugMode) debugPrint('[Sync] Failed to sync $table/$id: $e');
          // Leave in queue for retry
        }
      }

      onSyncCompleted?.call();
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] Flush error: $e');
      onSyncError?.call(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  // ==================== CUSTOMER OPERATIONS ====================

  Future<void> saveCustomer(Customer customer) async {
    // Write to Hive first (always works)
    await _storage.saveCustomer(customer);
    // Queue for cloud sync
    await _enqueueSync('customers', 'upsert', customer.id, customer.toJson());
  }

  Future<void> deleteCustomer(String id) async {
    await _storage.deleteCustomer(id);
    await _enqueueSync('customers', 'delete', id, {});
  }

  // ==================== SHIPMENT OPERATIONS ====================

  Future<void> saveShipment(Shipment shipment) async {
    await _storage.saveShipment(shipment);
    await _enqueueSync('shipments', 'upsert', shipment.id, shipment.toJson());
  }

  Future<void> deleteShipment(String id) async {
    // Delete packages in this shipment first
    final packages = _storage.getPackagesForShipment(id);
    for (final pkg in packages) {
      await deletePackage(pkg.id);
    }
    await _storage.deleteShipment(id);
    await _enqueueSync('shipments', 'delete', id, {});
  }

  // ==================== PACKAGE OPERATIONS ====================

  Future<void> savePackage(ShippingPackage package) async {
    await _storage.savePackage(package);
    await _enqueueSync('packages', 'upsert', package.id, package.toJson());
  }

  Future<void> deletePackage(String id) async {
    await _storage.deletePackage(id);
    await _enqueueSync('packages', 'delete', id, {});
  }

  // ==================== FULL SYNC ====================

  /// Pull all data from Supabase and merge with local Hive data.
  /// Called on login or manual refresh.
  Future<void> fullSync() async {
    if (!_supabase.isAuthenticated) return;
    
    _isSyncing = true;
    onSyncStarted?.call();

    try {
      // First, flush any pending local changes to cloud
      await _flushSyncQueue();

      // Then pull all cloud data
      final cloudData = await _supabase.pullAllData();
      
      // Merge customers
      final cloudCustomers = cloudData['customers'] ?? [];
      for (final data in cloudCustomers) {
        try {
          final customer = Customer(
            id: data['id'] as String,
            name: data['name'] as String,
            phone: data['phone'] as String,
            email: data['email'] as String?,
            createdAt: DateTime.parse(data['created_at'] as String),
          );
          // Save to Hive (overwrites if exists)
          await _storage.saveCustomer(customer);
        } catch (e) {
          if (kDebugMode) debugPrint('[Sync] Customer merge error: $e');
        }
      }

      // Merge shipments
      final cloudShipments = cloudData['shipments'] ?? [];
      for (final data in cloudShipments) {
        try {
          final shipment = Shipment(
            id: data['id'] as String,
            name: data['name'] as String,
            type: ShipmentType.values.firstWhere((e) => e.name == data['type']),
            destination: data['destination'] as String,
            status: ShipmentStatus.values.firstWhere((e) => e.name == data['status']),
            createdAt: DateTime.parse(data['created_at'] as String),
            departureDate: data['departure_date'] != null
                ? DateTime.parse(data['departure_date'] as String)
                : null,
            estimatedArrival: data['estimated_arrival'] != null
                ? DateTime.parse(data['estimated_arrival'] as String)
                : null,
            notes: data['notes'] as String?,
          );
          await _storage.saveShipment(shipment);
        } catch (e) {
          if (kDebugMode) debugPrint('[Sync] Shipment merge error: $e');
        }
      }

      // Merge packages
      final cloudPackages = cloudData['packages'] ?? [];
      for (final data in cloudPackages) {
        try {
          final pkg = ShippingPackage(
            id: data['id'] as String,
            referenceNumber: data['reference_number'] as String,
            customerId: data['customer_id'] as String,
            shipmentId: data['shipment_id'] as String,
            shipmentType: ShipmentType.values.firstWhere((e) => e.name == data['shipment_type']),
            photoPath: data['photo_url'] as String?,
            description: data['description'] as String? ?? '',
            weightKg: (data['weight_kg'] as num?)?.toDouble(),
            seaItemType: data['sea_item_type'] != null
                ? SeaItemType.values.firstWhere((e) => e.name == data['sea_item_type'])
                : null,
            presetItemName: data['preset_item_name'] as String?,
            price: (data['price'] as num).toDouble(),
            paymentStatus: PaymentStatus.values.firstWhere((e) => e.name == data['payment_status']),
            createdAt: DateTime.parse(data['created_at'] as String),
            notes: data['notes'] as String?,
            receiverName: data['receiver_name'] as String?,
            receiverPhone: data['receiver_phone'] as String?,
            receiverPhoneCountryCode: data['receiver_phone_country_code'] as String?,
          );
          await _storage.savePackage(pkg);
        } catch (e) {
          if (kDebugMode) debugPrint('[Sync] Package merge error: $e');
        }
      }

      // Sync operator profile/settings
      final profile = await _supabase.getOperatorProfile();
      if (profile != null) {
        if (profile['business_name'] != null) {
          await _storage.setOperatorName(profile['business_name'] as String);
        }
        if (profile['currency'] != null) {
          await _storage.setCurrency(profile['currency'] as String);
        }
        if (profile['language'] != null) {
          await _storage.setLanguage(profile['language'] as String);
        }
        if (profile['air_pricing'] != null) {
          final airData = Map<String, dynamic>.from(profile['air_pricing'] as Map);
          await _storage.setAirPricing(AirPricingConfig.fromJson(airData));
        }
        if (profile['sea_pricing'] != null) {
          final seaData = Map<String, dynamic>.from(profile['sea_pricing'] as Map);
          await _storage.setSeaPricing(SeaPricingConfig.fromJson(seaData));
        }
      }

      onSyncCompleted?.call();
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] Full sync error: $e');
      onSyncError?.call(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync operator settings to cloud
  Future<void> syncSettings({
    String? businessName,
    String? currency,
    String? language,
    AirPricingConfig? airPricing,
    SeaPricingConfig? seaPricing,
  }) async {
    if (!_supabase.isAuthenticated) return;
    try {
      final data = <String, dynamic>{};
      if (businessName != null) data['business_name'] = businessName;
      if (currency != null) data['currency'] = currency;
      if (language != null) data['language'] = language;
      if (airPricing != null) data['air_pricing'] = airPricing.toJson();
      if (seaPricing != null) data['sea_pricing'] = seaPricing.toJson();
      
      if (data.isNotEmpty) {
        await _supabase.updateOperatorProfile(data);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] Settings sync error: $e');
    }
  }

  /// Get pending sync count
  int get pendingSyncCount => _syncQueueBox.length;

  /// Force retry sync
  Future<void> retrySync() async {
    await _flushSyncQueue();
  }
}
