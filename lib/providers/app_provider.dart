import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

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
  String get languageCode => _l10n.languageCode;

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
    _loadAll();
    _isLoading = false;
    notifyListeners();
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

  // ==================== CUSTOMERS ====================

  Future<void> addCustomer(Customer customer) async {
    await _storage.saveCustomer(customer);
    _customers = _storage.getCustomers();
    notifyListeners();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _storage.saveCustomer(customer);
    _customers = _storage.getCustomers();
    notifyListeners();
  }

  Future<void> deleteCustomer(String id) async {
    await _storage.deleteCustomer(id);
    _customers = _storage.getCustomers();
    notifyListeners();
  }

  Customer? getCustomer(String id) => _storage.getCustomer(id);

  // ==================== SHIPMENTS ====================

  Future<void> addShipment(Shipment shipment) async {
    await _storage.saveShipment(shipment);
    _shipments = _storage.getShipments();
    notifyListeners();
  }

  Future<void> updateShipment(Shipment shipment) async {
    await _storage.saveShipment(shipment);
    _shipments = _storage.getShipments();
    notifyListeners();
  }

  Future<void> deleteShipment(String id) async {
    // Also delete all packages in this shipment
    final packages = _storage.getPackagesForShipment(id);
    for (final pkg in packages) {
      await _storage.deletePackage(pkg.id);
    }
    await _storage.deleteShipment(id);
    _shipments = _storage.getShipments();
    _packages = _storage.getPackages();
    notifyListeners();
  }

  // ==================== PACKAGES ====================

  List<ShippingPackage> getPackagesForShipment(String shipmentId) {
    return _packages.where((p) => p.shipmentId == shipmentId).toList();
  }

  Future<void> addPackage(ShippingPackage package) async {
    await _storage.savePackage(package);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  Future<void> updatePackage(ShippingPackage package) async {
    await _storage.savePackage(package);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  Future<void> deletePackage(String id) async {
    await _storage.deletePackage(id);
    _packages = _storage.getPackages();
    notifyListeners();
  }

  Future<void> togglePaymentStatus(ShippingPackage package) async {
    package.paymentStatus = package.paymentStatus == PaymentStatus.paid
        ? PaymentStatus.unpaid
        : PaymentStatus.paid;
    await _storage.savePackage(package);
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
    notifyListeners();
  }

  Future<void> setOperatorName(String name) async {
    await _storage.setOperatorName(name);
    _operatorName = name;
    notifyListeners();
  }

  Future<void> setCurrency(String cur) async {
    await _storage.setCurrency(cur);
    _currency = cur;
    notifyListeners();
  }

  Future<void> updateAirPricing(AirPricingConfig config) async {
    await _storage.setAirPricing(config);
    _airPricing = config;
    notifyListeners();
  }

  Future<void> updateSeaPricing(SeaPricingConfig config) async {
    await _storage.setSeaPricing(config);
    _seaPricing = config;
    notifyListeners();
  }

  // ==================== RECEIPT ====================

  String generateReceipt(ShippingPackage pkg) {
    final customer = getCustomer(pkg.customerId);
    final shipment =
        _shipments.where((s) => s.id == pkg.shipmentId).firstOrNull;
    final currSymbol = _currency == 'USD' ? '\$' : _currency;

    final buffer = StringBuffer();
    buffer.writeln('📦 *${_operatorName}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔖 Ref: ${pkg.referenceNumber}');
    buffer.writeln('👤 Customer: ${customer?.name ?? 'Unknown'}');
    buffer.writeln('📞 Phone: ${customer?.phone ?? 'N/A'}');
    buffer.writeln('');
    if (shipment != null) {
      buffer.writeln(
          '${pkg.shipmentType == ShipmentType.air ? '✈️' : '🚢'} ${shipment.name}');
      buffer.writeln(
          '📍 Destination: ${destinationFlag(shipment.destination)} ${shipment.destination}');
    }
    buffer.writeln('');
    if (pkg.description.isNotEmpty) {
      buffer.writeln('📋 Description: ${pkg.description}');
    }
    if (pkg.weightKg != null) {
      buffer.writeln('⚖️ Weight: ${pkg.weightKg!.toStringAsFixed(1)} kg');
    }
    if (pkg.presetItemName != null) {
      buffer.writeln('📦 Item: ${pkg.presetItemName}');
    }
    if (pkg.seaItemType != null) {
      buffer.writeln('📦 Item: ${seaItemTypeLabel(pkg.seaItemType!)}');
    }
    buffer.writeln('');
    buffer.writeln('💰 *Price: $currSymbol${pkg.price.toStringAsFixed(2)}*');
    buffer.writeln(
        '💳 Payment: ${pkg.paymentStatus == PaymentStatus.paid ? '✅ Paid' : '⏳ Unpaid'}');
    if (pkg.receiverName != null) {
      buffer.writeln('');
      buffer.writeln('📬 Receiver: ${pkg.receiverName}');
      if (pkg.receiverPhone != null) {
        buffer.writeln('📞 Receiver Phone: ${pkg.receiverPhone}');
      }
    }
    buffer.writeln('');
    buffer.writeln(
        '📅 Date: ${pkg.createdAt.day}/${pkg.createdAt.month}/${pkg.createdAt.year}');
    buffer.writeln('');
    buffer.writeln('Thank you for shipping with us! 🙏');

    return buffer.toString();
  }

  /// Generate a receipt specifically for the receiver/destinataire
  String generateReceiverReceipt(ShippingPackage pkg) {
    final customer = getCustomer(pkg.customerId);
    final shipment =
        _shipments.where((s) => s.id == pkg.shipmentId).firstOrNull;

    final buffer = StringBuffer();
    buffer.writeln('📦 *${_operatorName}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🎉 *A package is on its way to you!*');
    buffer.writeln('');
    buffer.writeln('🔖 Ref: ${pkg.referenceNumber}');
    buffer.writeln('👤 Sent by: ${customer?.name ?? 'Unknown'}');
    if (pkg.receiverName != null) {
      buffer.writeln('📬 For: ${pkg.receiverName}');
    }
    buffer.writeln('');
    if (shipment != null) {
      buffer.writeln(
          '${pkg.shipmentType == ShipmentType.air ? '✈️' : '🚢'} ${shipment.name}');
      buffer.writeln(
          '📍 Destination: ${destinationFlag(shipment.destination)} ${shipment.destination}');
    }
    buffer.writeln('');
    if (pkg.description.isNotEmpty) {
      buffer.writeln('📋 Contents: ${pkg.description}');
    }
    if (pkg.weightKg != null) {
      buffer.writeln('⚖️ Weight: ${pkg.weightKg!.toStringAsFixed(1)} kg');
    }
    buffer.writeln('');
    buffer.writeln(
        '📅 Shipped: ${pkg.createdAt.day}/${pkg.createdAt.month}/${pkg.createdAt.year}');
    if (shipment?.departureDate != null) {
      buffer.writeln(
          '🛫 Departure: ${shipment!.departureDate!.day}/${shipment.departureDate!.month}/${shipment.departureDate!.year}');
    }
    buffer.writeln('');
    buffer.writeln(
        'Please keep this reference number for pickup. We will notify you when the package arrives.');
    buffer.writeln('');
    buffer.writeln('$_operatorName 🙏');

    return buffer.toString();
  }
}
