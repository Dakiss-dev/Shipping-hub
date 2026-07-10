import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final SyncService _sync = SyncService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  // State
  List<Customer> _customers = [];
  List<Shipment> _shipments = [];
  List<ShippingPackage> _packages = [];
  AppLocalizations _l10n = AppLocalizations();
  AirPricingConfig _airPricing = AirPricingConfig();
  SeaPricingConfig _seaPricing = SeaPricingConfig();
  String _operatorName = 'My Shipping Business';
  String _currency = 'USD';
  bool _isLoading = true;
  bool _isSyncing = false;

  // Getters
  List<Customer> get customers => _customers;
  List<Shipment> get shipments => _shipments;
  List<ShippingPackage> get packages => _packages;
  AppLocalizations get l10n => _l10n;
  AirPricingConfig get airPricing => _airPricing;
  SeaPricingConfig get seaPricing => _seaPricing;
  String get operatorName => _operatorName;
  String get currency => _currency;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String get languageCode => _l10n.languageCode;
  
  // Auth state
  bool get isAuthenticated => _supabase.isAuthenticated;
  bool get isSupabaseConfigured => _supabase.isConfigured;
  bool get isEmailConfirmed => _supabase.isEmailConfirmed;
  String? get currentUserEmail => _supabase.client?.auth.currentUser?.email;
  int get pendingSyncCount => _sync.pendingSyncCount;

  List<Shipment> get activeShipments => _shipments
      .where(
          (s) => s.status == ShipmentStatus.open || s.status == ShipmentStatus.closed)
      .toList();

  List<Shipment> get pastShipments => _shipments
      .where((s) =>
          s.status == ShipmentStatus.inTransit ||
          s.status == ShipmentStatus.delivered)
      .toList();

  // ==================== INIT ====================

  Future<void> init() async {
    await _storage.init();
    await _sync.init();
    
    // Set up sync callbacks
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

    // Try to init Supabase (non-blocking)
    await _supabase.initialize();
    
    _loadAll();
    _isLoading = false;
    notifyListeners();

    // If already authenticated, do a background sync
    if (_supabase.isAuthenticated) {
      _sync.fullSync();
    }
  }

  void _loadAll() {
    _customers = _storage.getCustomers();
    _shipments = _storage.getShipments();
    _packages = _storage.getPackages();
    _l10n = AppLocalizations(languageCode: _storage.getLanguage());
    _airPricing = _storage.getAirPricing();
    _seaPricing = _storage.getSeaPricing();
    _operatorName = _storage.getOperatorName();
    _currency = _storage.getCurrency();
  }

  // ==================== AUTH ====================

  Future<String?> signUp({
    required String email,
    required String password,
    String? businessName,
  }) async {
    if (!_supabase.isConfigured) return 'Supabase not configured';
    try {
      // Store the business name to local storage IMMEDIATELY so it's
      // available in Settings and receipts even before sync completes.
      final bName = (businessName != null && businessName.trim().isNotEmpty)
          ? businessName.trim()
          : 'My Shipping Business';
      await _storage.setOperatorName(bName);
      _operatorName = bName;

      await _supabase.signUp(
        email: email,
        password: password,
        businessName: bName,
      );
      // After signup, sync local data to cloud
      if (_supabase.isAuthenticated) {
        await _sync.fullSync();
        _loadAll();
        notifyListeners();
      }
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_supabase.isConfigured) return 'Supabase not configured';
    try {
      await _supabase.signIn(email: email, password: password);
      // After login, pull cloud data and merge
      if (_supabase.isAuthenticated) {
        // Pull operator profile FIRST so business name is correct immediately
        await _pullOperatorProfile();
        await _sync.fullSync();
        _loadAll();
        notifyListeners();
      }
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  /// Pull operator profile from Supabase and store locally.
  /// Ensures the business name, currency, language etc. are
  /// correct in Settings and receipts from the moment the user logs in.
  Future<void> _pullOperatorProfile() async {
    try {
      final profile = await _supabase.getOperatorProfile();
      if (profile != null) {
        if (profile['business_name'] != null) {
          final name = profile['business_name'] as String;
          await _storage.setOperatorName(name);
          _operatorName = name;
        }
        if (profile['currency'] != null) {
          await _storage.setCurrency(profile['currency'] as String);
        }
        if (profile['language'] != null) {
          await _storage.setLanguage(profile['language'] as String);
        }
      }
    } catch (_) {
      // Non-fatal — sync will catch it later
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.signOut();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] Sign out error: $e');
    }
  }

  Future<String?> resetPassword(String email) async {
    if (!_supabase.isConfigured) return 'Supabase not configured';
    try {
      await _supabase.resetPassword(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    if (!_supabase.isConfigured) return false;
    try {
      final success = await _supabase.signInWithGoogle();
      if (success) {
        notifyListeners();
      }
      return success;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] Google sign-in error: $e');
      return false;
    }
  }

  /// Resend email confirmation
  Future<String?> resendConfirmation(String email) async {
    try {
      await _supabase.resendConfirmationEmail(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Refresh session to check if email was confirmed
  Future<bool> checkEmailConfirmation() async {
    try {
      await _supabase.refreshSession();
      notifyListeners();
      return _supabase.isEmailConfirmed;
    } catch (e) {
      return false;
    }
  }

  // ==================== MANUAL SYNC ====================

  Future<void> manualSync() async {
    if (!_supabase.isAuthenticated) return;
    _isSyncing = true;
    notifyListeners();
    await _sync.fullSync();
    _loadAll();
    _isSyncing = false;
    notifyListeners();
  }

  // ==================== CUSTOMERS ====================

  Future<void> addCustomer(Customer customer) async {
    await _sync.saveCustomer(customer);
    _customers = _storage.getCustomers();
    notifyListeners();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _sync.saveCustomer(customer);
    _customers = _storage.getCustomers();
    notifyListeners();
  }

  Future<void> deleteCustomer(String id) async {
    await _sync.deleteCustomer(id);
    _customers = _storage.getCustomers();
    notifyListeners();
  }

  Customer? getCustomer(String id) => _storage.getCustomer(id);

  // ==================== SHIPMENTS ====================

  Future<void> addShipment(Shipment shipment) async {
    await _sync.saveShipment(shipment);
    _shipments = _storage.getShipments();
    notifyListeners();
  }

  Future<void> updateShipment(Shipment shipment) async {
    await _sync.saveShipment(shipment);
    _shipments = _storage.getShipments();
    notifyListeners();
  }

  Future<void> deleteShipment(String id) async {
    await _sync.deleteShipment(id);
    _shipments = _storage.getShipments();
    _packages = _storage.getPackages();
    notifyListeners();
  }

  // ==================== PACKAGES ====================

  List<ShippingPackage> getPackagesForShipment(String shipmentId) {
    return _packages.where((p) => p.shipmentId == shipmentId).toList();
  }

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
    if (existingRefs.contains(package.referenceNumber)) {
      if (kDebugMode) {
        debugPrint('[Packages] Reference collision persisted after 10 retries: ${package.referenceNumber}');
      }
    }
    await _sync.savePackage(package);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  Future<void> updatePackage(ShippingPackage package) async {
    await _sync.savePackage(package);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  Future<void> deletePackage(String id) async {
    await _sync.deletePackage(id);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  Future<void> togglePaymentStatus(ShippingPackage package) async {
    package.paymentStatus = package.paymentStatus == PaymentStatus.paid
        ? PaymentStatus.unpaid
        : PaymentStatus.paid;
    await _sync.savePackage(package);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  // ==================== PRICING ====================

  double calculateAirPrice({double? weightKg, String? presetItem}) {
    if (presetItem != null && _airPricing.presetItems.containsKey(presetItem)) {
      return _airPricing.presetItems[presetItem]!;
    }
    if (weightKg != null) {
      return weightKg * _airPricing.pricePerKg;
    }
    return 0.0;
  }

  double calculateSeaPrice({SeaItemType? itemType, double? weightKg}) {
    if (itemType != null && itemType != SeaItemType.customWeight) {
      return _seaPricing.itemPrices[itemType] ?? 0.0;
    }
    if (weightKg != null) {
      return weightKg * _seaPricing.pricePerKg;
    }
    return 0.0;
  }

  // ==================== STATS ====================

  double getTotalRevenueForShipment(String shipmentId) {
    final pkgs = getPackagesForShipment(shipmentId);
    return pkgs.fold(0.0, (sum, p) => sum + p.price);
  }

  double getTotalWeightForShipment(String shipmentId) {
    final pkgs = getPackagesForShipment(shipmentId);
    return pkgs.fold(0.0, (sum, p) => sum + (p.weightKg ?? 0));
  }

  double getCollectedForShipment(String shipmentId) {
    final pkgs = getPackagesForShipment(shipmentId);
    return pkgs
        .where((p) => p.paymentStatus == PaymentStatus.paid)
        .fold(0.0, (sum, p) => sum + p.price);
  }

  double getOutstandingForShipment(String shipmentId) {
    return getTotalRevenueForShipment(shipmentId) -
        getCollectedForShipment(shipmentId);
  }

  double get totalRevenue => _packages.fold(0.0, (sum, p) => sum + p.price);
  double get totalCollected => _packages
      .where((p) => p.paymentStatus == PaymentStatus.paid)
      .fold(0.0, (sum, p) => sum + p.price);
  double get totalOutstanding => totalRevenue - totalCollected;

  // ==================== SETTINGS ====================

  Future<void> setLanguage(String lang) async {
    await _storage.setLanguage(lang);
    _l10n = AppLocalizations(languageCode: lang);
    _sync.syncSettings(language: lang);
    notifyListeners();
  }

  Future<void> setOperatorName(String name) async {
    await _storage.setOperatorName(name);
    _operatorName = name;
    _sync.syncSettings(businessName: name);
    notifyListeners();
  }

  Future<void> setCurrency(String cur) async {
    await _storage.setCurrency(cur);
    _currency = cur;
    _sync.syncSettings(currency: cur);
    notifyListeners();
  }

  Future<void> updateAirPricing(AirPricingConfig config) async {
    await _storage.setAirPricing(config);
    _airPricing = config;
    _sync.syncSettings(airPricing: config);
    notifyListeners();
  }

  Future<void> updateSeaPricing(SeaPricingConfig config) async {
    await _storage.setSeaPricing(config);
    _seaPricing = config;
    _sync.syncSettings(seaPricing: config);
    notifyListeners();
  }

  // ==================== RECEIPT ====================

  String generateReceipt(ShippingPackage pkg) {
    final customer = getCustomer(pkg.customerId);
    final shipment =
        _shipments.where((s) => s.id == pkg.shipmentId).firstOrNull;
    final currSymbol = _currency == 'USD' ? '\$' : _currency;

    final buffer = StringBuffer();
    buffer.writeln(_operatorName);
    buffer.writeln('---');
    buffer.writeln('Ref: ${pkg.referenceNumber}');
    buffer.writeln('Customer: ${customer?.name ?? 'Unknown'}');
    buffer.writeln('Phone: ${customer?.fullPhone ?? 'N/A'}');
    buffer.writeln('');
    if (shipment != null) {
      buffer.writeln(
          '${pkg.shipmentType == ShipmentType.air ? 'AIR' : 'SEA'} - ${shipment.name}');
      buffer.writeln(
          'Destination: ${destinationFlag(shipment.destination)} ${shipment.destination}');
    }
    buffer.writeln('');
    if (pkg.description.isNotEmpty) {
      buffer.writeln('Description: ${pkg.description}');
    }
    if (pkg.weightKg != null) {
      buffer.writeln('Weight: ${pkg.weightKg!.toStringAsFixed(1)} kg');
    }
    if (pkg.presetItemName != null) {
      buffer.writeln('Item: ${pkg.presetItemName}');
    }
    if (pkg.seaItemType != null) {
      buffer.writeln('Item: ${seaItemTypeLabel(pkg.seaItemType!)}');
    }
    buffer.writeln('');
    buffer.writeln('*Price: $currSymbol${pkg.price.toStringAsFixed(2)}*');
    buffer.writeln(
        'Payment: ${pkg.paymentStatus == PaymentStatus.paid ? 'PAID' : 'UNPAID'}');
    if (pkg.receiverName != null) {
      buffer.writeln('');
      buffer.writeln('Receiver: ${pkg.receiverName}');
      if (pkg.receiverPhone != null) {
        final rCode = pkg.receiverPhoneCountryCode ?? '+1';
        final rDigits = pkg.receiverPhone!.replaceAll(RegExp(r'[^\d]'), '');
        buffer.writeln('Receiver Phone: $rCode$rDigits');
      }
    }
    buffer.writeln('');
    buffer.writeln(
        'Date: ${pkg.createdAt.day}/${pkg.createdAt.month}/${pkg.createdAt.year}');
    buffer.writeln('');
    buffer.writeln('Thank you for shipping with us!');

    return buffer.toString();
  }

  /// Generate a receipt specifically for the receiver/destinataire
  String generateReceiverReceipt(ShippingPackage pkg) {
    final customer = getCustomer(pkg.customerId);
    final shipment =
        _shipments.where((s) => s.id == pkg.shipmentId).firstOrNull;

    final buffer = StringBuffer();
    buffer.writeln(_operatorName);
    buffer.writeln('---');
    buffer.writeln('*A package is on its way to you!*');
    buffer.writeln('');
    buffer.writeln('Ref: ${pkg.referenceNumber}');
    buffer.writeln('Sent by: ${customer?.name ?? 'Unknown'}');
    if (pkg.receiverName != null) {
      buffer.writeln('For: ${pkg.receiverName}');
    }
    buffer.writeln('');
    if (shipment != null) {
      buffer.writeln(
          '${pkg.shipmentType == ShipmentType.air ? 'AIR' : 'SEA'} - ${shipment.name}');
      buffer.writeln(
          'Destination: ${destinationFlag(shipment.destination)} ${shipment.destination}');
    }
    buffer.writeln('');
    if (pkg.description.isNotEmpty) {
      buffer.writeln('Contents: ${pkg.description}');
    }
    if (pkg.weightKg != null) {
      buffer.writeln('Weight: ${pkg.weightKg!.toStringAsFixed(1)} kg');
    }
    buffer.writeln('');
    buffer.writeln(
        'Shipped: ${pkg.createdAt.day}/${pkg.createdAt.month}/${pkg.createdAt.year}');
    if (shipment?.departureDate != null) {
      buffer.writeln(
          'Departure: ${shipment!.departureDate!.day}/${shipment.departureDate!.month}/${shipment.departureDate!.year}');
    }
    buffer.writeln('');
    buffer.writeln(
        'Please keep this reference number for pickup. We will notify you when the package arrives.');
    buffer.writeln('');
    buffer.writeln(_operatorName);

    return buffer.toString();
  }
}
