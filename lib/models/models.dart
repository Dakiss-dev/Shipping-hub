import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ==================== ENUMS ====================

enum ShipmentType { air, sea }

enum ShipmentStatus { open, closed, inTransit, delivered }

enum PaymentStatus { unpaid, paid }

enum SeaItemType {
  smallBarrel,
  largeBarrel,
  car,
  mattress,
  television,
  furniture,
  electronics,
  customWeight,
}

// ==================== CUSTOMER ====================

class Customer {
  final String id;
  String name;
  String phone;
  String phoneCountryCode;
  String? email;
  final DateTime createdAt;

  Customer({
    String? id,
    required this.name,
    required this.phone,
    this.phoneCountryCode = '+1',
    this.email,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Full international phone number
  String get fullPhone {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return phone;
    if (phone.startsWith('+')) return phone; // Already international
    return '$phoneCountryCode$digits';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'phoneCountryCode': phoneCountryCode,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        phoneCountryCode: json['phoneCountryCode'] as String? ?? '+1',
        email: json['email'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

// ==================== PRICING CONFIG ====================

class AirPricingConfig {
  double pricePerKg; // USD per kg
  Map<String, double> presetItems; // item name -> fixed price

  AirPricingConfig({
    this.pricePerKg = 8.0,
    Map<String, double>? presetItems,
  }) : presetItems = presetItems ??
            {
              'Phone': 25.0,
              'Laptop': 50.0,
              'Tablet': 35.0,
              'Small Electronics': 20.0,
              'Documents/Envelope': 15.0,
              'Shoes (pair)': 15.0,
              'Clothing Bundle': 20.0,
            };

  Map<String, dynamic> toJson() => {
        'pricePerKg': pricePerKg,
        'presetItems': presetItems,
      };

  factory AirPricingConfig.fromJson(Map<String, dynamic> json) =>
      AirPricingConfig(
        pricePerKg: (json['pricePerKg'] as num).toDouble(),
        presetItems: Map<String, double>.from(
          (json['presetItems'] as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        ),
      );
}

class SeaPricingConfig {
  Map<SeaItemType, double> itemPrices;
  double pricePerKg; // for custom weight items

  SeaPricingConfig({
    Map<SeaItemType, double>? itemPrices,
    this.pricePerKg = 3.0,
  }) : itemPrices = itemPrices ??
            {
              SeaItemType.smallBarrel: 80.0,
              SeaItemType.largeBarrel: 150.0,
              SeaItemType.car: 1500.0,
              SeaItemType.mattress: 100.0,
              SeaItemType.television: 75.0,
              SeaItemType.furniture: 120.0,
              SeaItemType.electronics: 60.0,
            };

  Map<String, dynamic> toJson() => {
        'itemPrices': itemPrices.map((k, v) => MapEntry(k.name, v)),
        'pricePerKg': pricePerKg,
      };

  factory SeaPricingConfig.fromJson(Map<String, dynamic> json) =>
      SeaPricingConfig(
        pricePerKg: (json['pricePerKg'] as num).toDouble(),
        itemPrices: (json['itemPrices'] as Map).map(
          (k, v) => MapEntry(
            SeaItemType.values.firstWhere((e) => e.name == k),
            (v as num).toDouble(),
          ),
        ),
      );
}

// ==================== PACKAGE ====================

class ShippingPackage {
  final String id;
  final String referenceNumber;
  final String customerId;
  final String shipmentId;
  final ShipmentType shipmentType;
  String? photoPath;
  String description;
  double? weightKg;
  SeaItemType? seaItemType;
  String? presetItemName; // for air preset items
  double price;
  PaymentStatus paymentStatus;
  final DateTime createdAt;
  String? notes;
  // Receiver (destinataire) info
  String? receiverName;
  String? receiverPhone;
  String? receiverPhoneCountryCode;

  ShippingPackage({
    String? id,
    String? referenceNumber,
    required this.customerId,
    required this.shipmentId,
    required this.shipmentType,
    this.photoPath,
    this.description = '',
    this.weightKg,
    this.seaItemType,
    this.presetItemName,
    required this.price,
    this.paymentStatus = PaymentStatus.unpaid,
    DateTime? createdAt,
    this.notes,
    this.receiverName,
    this.receiverPhone,
    this.receiverPhoneCountryCode,
  })  : id = id ?? _uuid.v4(),
        referenceNumber = referenceNumber ?? _generateRefNumber(),
        createdAt = createdAt ?? DateTime.now();

  static String _generateRefNumber() {
    final now = DateTime.now();
    final datePart =
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomPart = _uuid.v4().substring(0, 4).toUpperCase();
    return 'SH-$datePart-$randomPart';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'referenceNumber': referenceNumber,
        'customerId': customerId,
        'shipmentId': shipmentId,
        'shipmentType': shipmentType.name,
        'photoPath': photoPath,
        'description': description,
        'weightKg': weightKg,
        'seaItemType': seaItemType?.name,
        'presetItemName': presetItemName,
        'price': price,
        'paymentStatus': paymentStatus.name,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
        'receiverName': receiverName,
        'receiverPhone': receiverPhone,
        'receiverPhoneCountryCode': receiverPhoneCountryCode,
      };

  factory ShippingPackage.fromJson(Map<String, dynamic> json) =>
      ShippingPackage(
        id: json['id'] as String,
        referenceNumber: json['referenceNumber'] as String,
        customerId: json['customerId'] as String,
        shipmentId: json['shipmentId'] as String,
        shipmentType: ShipmentType.values
            .firstWhere((e) => e.name == json['shipmentType']),
        photoPath: json['photoPath'] as String?,
        description: json['description'] as String? ?? '',
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        seaItemType: json['seaItemType'] != null
            ? SeaItemType.values
                .firstWhere((e) => e.name == json['seaItemType'])
            : null,
        presetItemName: json['presetItemName'] as String?,
        price: (json['price'] as num).toDouble(),
        paymentStatus: PaymentStatus.values
            .firstWhere((e) => e.name == json['paymentStatus']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        notes: json['notes'] as String?,
        receiverName: json['receiverName'] as String?,
        receiverPhone: json['receiverPhone'] as String?,
        receiverPhoneCountryCode: json['receiverPhoneCountryCode'] as String?,
      );
}

// ==================== SHIPMENT ====================

class Shipment {
  final String id;
  String name; // e.g. "Container to Ouaga - Feb 15"
  ShipmentType type;
  String destination; // Country/city
  ShipmentStatus status;
  final DateTime createdAt;
  DateTime? departureDate;
  DateTime? estimatedArrival;
  String? notes;

  Shipment({
    String? id,
    required this.name,
    required this.type,
    required this.destination,
    this.status = ShipmentStatus.open,
    DateTime? createdAt,
    this.departureDate,
    this.estimatedArrival,
    this.notes,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'destination': destination,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'departureDate': departureDate?.toIso8601String(),
        'estimatedArrival': estimatedArrival?.toIso8601String(),
        'notes': notes,
      };

  factory Shipment.fromJson(Map<String, dynamic> json) => Shipment(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ShipmentType.values.firstWhere((e) => e.name == json['type']),
        destination: json['destination'] as String,
        status: ShipmentStatus.values
            .firstWhere((e) => e.name == json['status']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        departureDate: json['departureDate'] != null
            ? DateTime.parse(json['departureDate'] as String)
            : null,
        estimatedArrival: json['estimatedArrival'] != null
            ? DateTime.parse(json['estimatedArrival'] as String)
            : null,
        notes: json['notes'] as String?,
      );
}

// ==================== HELPERS ====================

String seaItemTypeLabel(SeaItemType type) {
  switch (type) {
    case SeaItemType.smallBarrel:
      return 'Small Barrel';
    case SeaItemType.largeBarrel:
      return 'Large Barrel';
    case SeaItemType.car:
      return 'Car / Vehicle';
    case SeaItemType.mattress:
      return 'Mattress';
    case SeaItemType.television:
      return 'Television';
    case SeaItemType.furniture:
      return 'Furniture';
    case SeaItemType.electronics:
      return 'Electronics';
    case SeaItemType.customWeight:
      return 'Custom (by weight)';
  }
}

String shipmentStatusLabel(ShipmentStatus status) {
  switch (status) {
    case ShipmentStatus.open:
      return 'Open - Accepting Packages';
    case ShipmentStatus.closed:
      return 'Closed - Ready to Ship';
    case ShipmentStatus.inTransit:
      return 'In Transit';
    case ShipmentStatus.delivered:
      return 'Delivered';
  }
}

String destinationFlag(String destination) {
  final d = destination.toLowerCase();
  if (d.contains('burkina') || d.contains('ouaga') || d.contains('bobo'))
    return '🇧🇫';
  if (d.contains('ivory') ||
      d.contains("ivoire") ||
      d.contains('abidjan') ||
      d.contains('cote')) return '🇨🇮';
  if (d.contains('togo') || d.contains('lome') || d.contains('lomé'))
    return '🇹🇬';
  if (d.contains('ghana') || d.contains('accra')) return '🇬🇭';
  if (d.contains('senegal') || d.contains('dakar')) return '🇸🇳';
  if (d.contains('mali') || d.contains('bamako')) return '🇲🇱';
  if (d.contains('niger') || d.contains('niamey')) return '🇳🇪';
  if (d.contains('benin') || d.contains('cotonou')) return '🇧🇯';
  return '🌍';
}
