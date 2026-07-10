import '../../models/models.dart';

/// Model <-> Postgres row mapping (snake_case columns).
///
/// The pushed updated_at is advisory: the DB trigger overwrites it with
/// NOW() on conflicting upserts. That is safe — the merge protects unflushed
/// local edits via the pending-queue check, not clock comparison.

Map<String, dynamic> customerToRow(Customer c, String operatorId) => {
      'id': c.id,
      'operator_id': operatorId,
      'name': c.name,
      'phone': c.phone,
      'phone_country_code': c.phoneCountryCode,
      'email': c.email,
      'created_at': c.createdAt.toIso8601String(),
      'updated_at': c.updatedAt.toIso8601String(),
      'deleted_at': c.deletedAt?.toIso8601String(),
      'synced_at': DateTime.now().toIso8601String(),
    };

Customer customerFromRow(Map<String, dynamic> row) => Customer(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String,
      phoneCountryCode: row['phone_country_code'] as String? ?? '+1',
      email: row['email'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );

Map<String, dynamic> shipmentToRow(Shipment s, String operatorId) => {
      'id': s.id,
      'operator_id': operatorId,
      'name': s.name,
      'type': s.type.name,
      'destination': s.destination,
      'status': s.status.name,
      'departure_date': s.departureDate?.toIso8601String(),
      'estimated_arrival': s.estimatedArrival?.toIso8601String(),
      'notes': s.notes,
      'created_at': s.createdAt.toIso8601String(),
      'updated_at': s.updatedAt.toIso8601String(),
      'deleted_at': s.deletedAt?.toIso8601String(),
      'synced_at': DateTime.now().toIso8601String(),
    };

Shipment shipmentFromRow(Map<String, dynamic> row) => Shipment(
      id: row['id'] as String,
      name: row['name'] as String,
      type: ShipmentType.values.firstWhere((e) => e.name == row['type']),
      destination: row['destination'] as String,
      status:
          ShipmentStatus.values.firstWhere((e) => e.name == row['status']),
      createdAt: DateTime.parse(row['created_at'] as String),
      departureDate: row['departure_date'] != null
          ? DateTime.parse(row['departure_date'] as String)
          : null,
      estimatedArrival: row['estimated_arrival'] != null
          ? DateTime.parse(row['estimated_arrival'] as String)
          : null,
      notes: row['notes'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );

Map<String, dynamic> packageToRow(ShippingPackage p, String operatorId) => {
      'id': p.id,
      'operator_id': operatorId,
      'customer_id': p.customerId,
      'shipment_id': p.shipmentId,
      'reference_number': p.referenceNumber,
      'shipment_type': p.shipmentType.name,
      'photo_url': p.photoPath,
      'description': p.description,
      'weight_kg': p.weightKg,
      'sea_item_type': p.seaItemType?.name,
      'preset_item_name': p.presetItemName,
      'price': p.price,
      'payment_status': p.paymentStatus.name,
      'notes': p.notes,
      'receiver_name': p.receiverName,
      'receiver_phone': p.receiverPhone,
      'receiver_phone_country_code': p.receiverPhoneCountryCode,
      'created_at': p.createdAt.toIso8601String(),
      'updated_at': p.updatedAt.toIso8601String(),
      'deleted_at': p.deletedAt?.toIso8601String(),
      'synced_at': DateTime.now().toIso8601String(),
    };

ShippingPackage packageFromRow(Map<String, dynamic> row) => ShippingPackage(
      id: row['id'] as String,
      referenceNumber: row['reference_number'] as String,
      customerId: row['customer_id'] as String,
      shipmentId: row['shipment_id'] as String,
      shipmentType: ShipmentType.values
          .firstWhere((e) => e.name == row['shipment_type']),
      photoPath: row['photo_url'] as String?,
      description: row['description'] as String? ?? '',
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      seaItemType: row['sea_item_type'] != null
          ? SeaItemType.values
              .firstWhere((e) => e.name == row['sea_item_type'])
          : null,
      presetItemName: row['preset_item_name'] as String?,
      price: (row['price'] as num).toDouble(),
      paymentStatus: PaymentStatus.values
          .firstWhere((e) => e.name == row['payment_status']),
      createdAt: DateTime.parse(row['created_at'] as String),
      notes: row['notes'] as String?,
      receiverName: row['receiver_name'] as String?,
      receiverPhone: row['receiver_phone'] as String?,
      receiverPhoneCountryCode:
          row['receiver_phone_country_code'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
