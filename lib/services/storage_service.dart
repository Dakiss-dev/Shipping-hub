import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class StorageService {
  static const String _customersBox = 'customers';
  static const String _shipmentsBox = 'shipments';
  static const String _packagesBox = 'packages';
  static const String _settingsBox = 'settings';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_customersBox);
    await Hive.openBox(_shipmentsBox);
    await Hive.openBox(_packagesBox);
    await Hive.openBox(_settingsBox);
  }

  // ==================== CUSTOMERS ====================

  List<Customer> getCustomers() {
    final box = Hive.box(_customersBox);
    return box.values
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> saveCustomer(Customer customer) async {
    final box = Hive.box(_customersBox);
    await box.put(customer.id, customer.toJson());
  }

  Future<void> deleteCustomer(String id) async {
    final box = Hive.box(_customersBox);
    await box.delete(id);
  }

  Customer? getCustomer(String id) {
    final box = Hive.box(_customersBox);
    final data = box.get(id);
    if (data == null) return null;
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ==================== SHIPMENTS ====================

  List<Shipment> getShipments() {
    final box = Hive.box(_shipmentsBox);
    return box.values
        .map((e) => Shipment.fromJson(Map<String, dynamic>.from(e as Map)))
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
    final box = Hive.box(_shipmentsBox);
    await box.put(shipment.id, shipment.toJson());
  }

  Future<void> deleteShipment(String id) async {
    final box = Hive.box(_shipmentsBox);
    await box.delete(id);
  }

  Shipment? getShipment(String id) {
    final box = Hive.box(_shipmentsBox);
    final data = box.get(id);
    if (data == null) return null;
    return Shipment.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ==================== PACKAGES ====================

  List<ShippingPackage> getPackages() {
    final box = Hive.box(_packagesBox);
    return box.values
        .map(
            (e) => ShippingPackage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ShippingPackage> getPackagesForShipment(String shipmentId) {
    return getPackages().where((p) => p.shipmentId == shipmentId).toList();
  }

  Future<void> savePackage(ShippingPackage package) async {
    final box = Hive.box(_packagesBox);
    await box.put(package.id, package.toJson());
  }

  Future<void> deletePackage(String id) async {
    final box = Hive.box(_packagesBox);
    await box.delete(id);
  }

  // ==================== SETTINGS ====================

  String getLanguage() {
    final box = Hive.box(_settingsBox);
    return box.get('language', defaultValue: 'en') as String;
  }

  Future<void> setLanguage(String lang) async {
    final box = Hive.box(_settingsBox);
    await box.put('language', lang);
  }

  String getOperatorName() {
    final box = Hive.box(_settingsBox);
    return box.get('operatorName', defaultValue: 'My Shipping Business') as String;
  }

  Future<void> setOperatorName(String name) async {
    final box = Hive.box(_settingsBox);
    await box.put('operatorName', name);
  }

  String getCurrency() {
    final box = Hive.box(_settingsBox);
    return box.get('currency', defaultValue: 'USD') as String;
  }

  Future<void> setCurrency(String currency) async {
    final box = Hive.box(_settingsBox);
    await box.put('currency', currency);
  }

  AirPricingConfig getAirPricing() {
    final box = Hive.box(_settingsBox);
    final data = box.get('airPricing');
    if (data == null) return AirPricingConfig();
    return AirPricingConfig.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> setAirPricing(AirPricingConfig config) async {
    final box = Hive.box(_settingsBox);
    await box.put('airPricing', config.toJson());
  }

  SeaPricingConfig getSeaPricing() {
    final box = Hive.box(_settingsBox);
    final data = box.get('seaPricing');
    if (data == null) return SeaPricingConfig();
    return SeaPricingConfig.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> setSeaPricing(SeaPricingConfig config) async {
    final box = Hive.box(_settingsBox);
    await box.put('seaPricing', config.toJson());
  }
}
