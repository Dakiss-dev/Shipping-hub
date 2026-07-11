import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Hive-backed primary store, namespaced per account.
///
/// Box names are `<namespace>_customers` etc., where namespace is the
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

  /// Test hook: callers must run `Hive.init` with a temp dir first.
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
