import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../services/supabase_config.dart';
import '../services/sync/supabase_backend.dart';
import '../services/sync/sync_engine.dart';
import '../services/sync/sync_queue.dart';
import '../l10n/app_localizations.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  late final SyncEngine _sync;
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
  int get pendingSyncCount => _isLoading ? 0 : _sync.pendingSyncCount;
  DateTime? get lastSyncedAt => _isLoading ? null : _sync.lastSyncedAt;
  String? get syncError => _isLoading
      ? null
      : _settingsSyncError ?? _sync.lastError ?? _sync.firstQueueError;

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
    // Supabase first: the storage namespace is the signed-in user id, so we
    // must know it before opening the account's Hive boxes.
    await _supabase.initialize();
    await _storage.init(namespace: _supabase.currentUserId ?? 'local');

    _sync = SyncEngine(
      _storage,
      SupabaseBackend(() => _supabase.client),
      SyncQueue(() => _storage.syncQueueBox),
    );
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

    _loadAll();
    _isLoading = false;
    notifyListeners();

    // If already authenticated, do a background sync
    if (_supabase.isAuthenticated) {
      unawaited(_sync.fullSync());
    }
  }

  /// Waits out any in-flight sync before a namespace switch, so a background
  /// flush/pull can't land writes into the wrong account's boxes.
  Future<void> _quiesceSync() async {
    var guard = 0;
    while (_sync.isSyncing && guard < 100) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      guard++;
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
      // After signup, move into this account's namespace and sync.
      if (_supabase.isAuthenticated) {
        await _quiesceSync();
        await _storage.switchNamespace(_supabase.currentUserId!);
        // Re-persist the business name into the fresh account namespace.
        await _storage.setOperatorName(bName);
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
      // After login, move into this account's namespace, then pull + merge.
      if (_supabase.isAuthenticated) {
        await _quiesceSync();
        await _storage.switchNamespace(_supabase.currentUserId!);
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
      }
    } catch (_) {
      // Non-fatal — sync will catch it later
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.signOut();
      // Quiesce any in-flight sync, clear stale engine error state, and drop
      // back to the local namespace so the next account starts clean.
      await _quiesceSync();
      _sync.lastError = null;
      _settingsSyncError = null;
      await _storage.switchNamespace('local');
      _loadAll();
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
    // The engine's onSyncStarted/Completed callbacks drive _isSyncing.
    await _sync.fullSync();
    // Re-push profile settings (idempotent, last-write-wins) so a prior
    // settings-sync failure is retried and its error cleared by the same
    // "Sync issue" Retry the user tapped.
    await _syncSettings(
      businessName: _operatorName,
      currency: _currency,
      language: _l10n.languageCode,
      airPricing: _airPricing,
      seaPricing: _seaPricing,
    );
    _loadAll();
    notifyListeners();
  }

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

  Future<void> addPackage(ShippingPackage package,
      {Uint8List? photoBytes}) async {
    final existingRefs = {
      for (final p in _packages)
        if (p.id != package.id) p.referenceNumber,
    };
    final unique =
        ShippingPackage.ensureUniqueReference(package, existingRefs);
    if (!unique && kDebugMode) {
      debugPrint(
          '[Packages] Reference collision persisted after retries: ${package.referenceNumber}');
    }
    // Photos live in cloud storage so they survive across devices and can
    // appear on the customer tracking page. The captured image is only kept
    // as photoPath once it is a real storage URL — a device-local path or web
    // blob URL is meaningless elsewhere, would be clobbered on the next sync,
    // and would render as a broken placeholder on other devices, so if the
    // upload can't happen (offline, signed out, or an error) we drop it and
    // photoPathAttached stays false so the UI can tell the operator.
    photoWasDropped = false;
    if (photoBytes != null) {
      if (_supabase.isAuthenticated && _sync.isOnline) {
        try {
          package.photoPath = await _supabase.uploadPackagePhoto(
            operatorId: _supabase.currentUserId!,
            packageId: package.id,
            bytes: photoBytes,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('[Packages] Photo upload failed: $e');
          package.photoPath = null;
          photoWasDropped = true;
        }
      } else {
        package.photoPath = null;
        photoWasDropped = true;
      }
    }
    await _sync.savePackage(package);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  /// True when the most recent addPackage had a photo it could not upload
  /// (offline/signed out/error) and therefore did not attach. The intake
  /// screen reads this to warn the operator.
  bool photoWasDropped = false;

  Future<void> updatePackage(ShippingPackage package) async {
    await _sync.savePackage(package);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  Future<void> deletePackage(String id) async {
    // Best-effort cloud photo cleanup before the row is tombstoned, so the
    // storage object doesn't outlive the package (freemium quota hygiene).
    final pkg = _storage.getPackage(id);
    if (pkg != null &&
        pkg.photoPath != null &&
        pkg.photoPath!.startsWith('http') &&
        _supabase.isAuthenticated) {
      unawaited(_supabase.deletePackagePhoto(
        operatorId: _supabase.currentUserId!,
        packageId: id,
      ));
    }
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
    unawaited(_syncSettings(language: lang));
    notifyListeners();
  }

  Future<void> setOperatorName(String name) async {
    await _storage.setOperatorName(name);
    _operatorName = name;
    unawaited(_syncSettings(businessName: name));
    notifyListeners();
  }

  Future<void> setCurrency(String cur) async {
    await _storage.setCurrency(cur);
    _currency = cur;
    unawaited(_syncSettings(currency: cur));
    notifyListeners();
  }

  Future<void> updateAirPricing(AirPricingConfig config) async {
    await _storage.setAirPricing(config);
    _airPricing = config;
    unawaited(_syncSettings(airPricing: config));
    notifyListeners();
  }

  Future<void> updateSeaPricing(SeaPricingConfig config) async {
    await _storage.setSeaPricing(config);
    _seaPricing = config;
    unawaited(_syncSettings(seaPricing: config));
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
    final trackUrl =
        '${SupabaseConfig.trackingBaseUrl(Uri.base)}/?t=${pkg.trackingToken}';
    buffer.writeln('Track your package:');
    buffer.writeln(trackUrl);
    buffer.writeln('');
    buffer.writeln(_operatorName);

    return buffer.toString();
  }
}
