import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'supabase_config.dart';

/// Supabase service layer for all cloud operations.
/// Handles auth, CRUD, and real-time subscriptions.
class SupabaseService {
  static SupabaseService? _instance;
  SupabaseClient? _client;
  bool _initialized = false;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  bool get isInitialized => _initialized;
  bool get isConfigured => SupabaseConfig.isConfigured;
  SupabaseClient? get client => _client;

  String? get currentUserId => _client?.auth.currentUser?.id;
  bool get isAuthenticated => _client?.auth.currentUser != null;

  /// Initialize Supabase - call once at app startup
  Future<bool> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint('[Supabase] Not configured - running in offline mode');
      }
      return false;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[Supabase] Initialized successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Supabase] Init failed: $e');
      }
      return false;
    }
  }

  // ==================== AUTH ====================

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? businessName,
  }) async {
    final response = await _client!.auth.signUp(
      email: email,
      password: password,
      data: {'business_name': businessName ?? 'My Shipping Business'},
    );
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  Future<void> signOut() async {
    await _client!.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client!.auth.resetPasswordForEmail(email);
  }

  // ==================== OPERATOR PROFILE ====================

  Future<Map<String, dynamic>?> getOperatorProfile() async {
    if (!isAuthenticated) return null;
    try {
      final response = await _client!
          .from('operators')
          .select()
          .eq('id', currentUserId!)
          .maybeSingle();
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Get profile error: $e');
      return null;
    }
  }

  Future<void> updateOperatorProfile(Map<String, dynamic> data) async {
    if (!isAuthenticated) return;
    await _client!
        .from('operators')
        .update(data)
        .eq('id', currentUserId!);
  }

  // ==================== CUSTOMERS ====================

  Future<List<Map<String, dynamic>>> getCustomers() async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client!
          .from('customers')
          .select()
          .eq('operator_id', currentUserId!)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Get customers error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> upsertCustomer(Customer customer, {String? countryCode}) async {
    if (!isAuthenticated) return null;
    try {
      final data = {
        'id': customer.id,
        'operator_id': currentUserId!,
        'name': customer.name,
        'phone': customer.phone,
        'phone_country_code': countryCode ?? '+1',
        'email': customer.email,
        'created_at': customer.createdAt.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      };
      final response = await _client!
          .from('customers')
          .upsert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Upsert customer error: $e');
      return null;
    }
  }

  Future<void> deleteCustomer(String id) async {
    if (!isAuthenticated) return;
    try {
      await _client!.from('customers').delete().eq('id', id);
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Delete customer error: $e');
    }
  }

  // ==================== SHIPMENTS ====================

  Future<List<Map<String, dynamic>>> getShipments() async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client!
          .from('shipments')
          .select()
          .eq('operator_id', currentUserId!)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Get shipments error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> upsertShipment(Shipment shipment) async {
    if (!isAuthenticated) return null;
    try {
      final data = {
        'id': shipment.id,
        'operator_id': currentUserId!,
        'name': shipment.name,
        'type': shipment.type.name,
        'destination': shipment.destination,
        'status': shipment.status.name,
        'departure_date': shipment.departureDate?.toIso8601String(),
        'estimated_arrival': shipment.estimatedArrival?.toIso8601String(),
        'notes': shipment.notes,
        'created_at': shipment.createdAt.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      };
      final response = await _client!
          .from('shipments')
          .upsert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Upsert shipment error: $e');
      return null;
    }
  }

  Future<void> deleteShipment(String id) async {
    if (!isAuthenticated) return;
    try {
      // Delete packages first (cascade might handle it, but be safe)
      await _client!.from('packages').delete().eq('shipment_id', id);
      await _client!.from('shipments').delete().eq('id', id);
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Delete shipment error: $e');
    }
  }

  // ==================== PACKAGES ====================

  Future<List<Map<String, dynamic>>> getPackages() async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client!
          .from('packages')
          .select()
          .eq('operator_id', currentUserId!)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Get packages error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> upsertPackage(ShippingPackage package) async {
    if (!isAuthenticated) return null;
    try {
      final data = {
        'id': package.id,
        'operator_id': currentUserId!,
        'customer_id': package.customerId,
        'shipment_id': package.shipmentId,
        'reference_number': package.referenceNumber,
        'shipment_type': package.shipmentType.name,
        'photo_url': package.photoPath,
        'description': package.description,
        'weight_kg': package.weightKg,
        'sea_item_type': package.seaItemType?.name,
        'preset_item_name': package.presetItemName,
        'price': package.price,
        'payment_status': package.paymentStatus.name,
        'notes': package.notes,
        'receiver_name': package.receiverName,
        'receiver_phone': package.receiverPhone,
        'receiver_phone_country_code': package.receiverPhoneCountryCode,
        'created_at': package.createdAt.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      };
      final response = await _client!
          .from('packages')
          .upsert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Upsert package error: $e');
      return null;
    }
  }

  Future<void> deletePackage(String id) async {
    if (!isAuthenticated) return;
    try {
      await _client!.from('packages').delete().eq('id', id);
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Delete package error: $e');
    }
  }

  // ==================== PUBLIC TRACKING ====================

  /// Look up a package by reference number - no auth needed
  Future<Map<String, dynamic>?> trackPackage(String referenceNumber) async {
    try {
      final response = await _client!
          .from('public_package_tracking')
          .select()
          .eq('reference_number', referenceNumber)
          .maybeSingle();
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Track package error: $e');
      return null;
    }
  }

  // ==================== BATCH SYNC ====================

  /// Pull all data from Supabase for the current operator
  Future<Map<String, List<Map<String, dynamic>>>> pullAllData() async {
    if (!isAuthenticated) return {};
    try {
      final results = await Future.wait([
        getCustomers(),
        getShipments(),
        getPackages(),
      ]);
      return {
        'customers': results[0],
        'shipments': results[1],
        'packages': results[2],
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Pull all data error: $e');
      return {};
    }
  }
}
