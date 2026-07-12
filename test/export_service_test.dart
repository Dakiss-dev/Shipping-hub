import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_hub/models/models.dart';
import 'package:shipping_hub/services/export_service.dart';

void main() {
  Customer customer({String id = 'c1', String name = 'Awa Traore'}) => Customer(
        id: id,
        name: name,
        phone: '70123456',
        phoneCountryCode: '+226',
      );

  Shipment shipment({String id = 's1', String name = 'Ouaga Feb'}) => Shipment(
        id: id,
        name: name,
        type: ShipmentType.sea,
        destination: 'Ouagadougou',
      );

  ShippingPackage pkg({
    String customerId = 'c1',
    String shipmentId = 's1',
    String description = 'Barrel of goods',
    double price = 150,
    ShipmentType type = ShipmentType.sea,
    PaymentStatus payment = PaymentStatus.unpaid,
  }) =>
      ShippingPackage(
        customerId: customerId,
        shipmentId: shipmentId,
        shipmentType: type,
        description: description,
        price: price,
        paymentStatus: payment,
        createdAt: DateTime(2026, 2, 5),
      );

  group('packagesToCsv', () {
    test('emits a header row matching csvHeaders', () {
      final csv = ExportService.packagesToCsv([],
          customersById: {}, shipmentsById: {});
      final firstLine = csv.trimRight().split('\n').first.trim();
      expect(firstLine, ExportService.csvHeaders.join(','));
    });

    test('joins sender and shipment names and formats price to 2 decimals', () {
      final csv = ExportService.packagesToCsv(
        [pkg()],
        customersById: {'c1': customer()},
        shipmentsById: {'s1': shipment()},
      );
      final row = csv.trimRight().split('\n').last;
      expect(row, contains('Awa Traore'));
      expect(row, contains('Ouaga Feb'));
      expect(row, contains('Ouagadougou'));
      expect(row, contains('150.00'));
      expect(row, contains('2026-02-05'));
    });

    test('RFC-4180 escapes commas and quotes in a field', () {
      final csv = ExportService.packagesToCsv(
        [pkg(description: 'Rice, beans, "premium" grade')],
        customersById: {'c1': customer()},
        shipmentsById: {'s1': shipment()},
      );
      // Comma-containing field must be quoted, inner quotes doubled.
      expect(csv, contains('"Rice, beans, ""premium"" grade"'));
    });

    test('missing joins render as empty cells rather than throwing', () {
      final csv = ExportService.packagesToCsv(
        [pkg(customerId: 'ghost', shipmentId: 'ghost')],
        customersById: {},
        shipmentsById: {},
      );
      // The row still exists and has the right number of columns.
      final row = csv.trimRight().split('\n').last;
      expect(row.split(',').length, greaterThanOrEqualTo(ExportService.csvHeaders.length));
    });

    test('neutralizes formula-injection payloads in free-text fields', () {
      final csv = ExportService.packagesToCsv(
        [pkg(description: '=HYPERLINK("http://evil","x")')],
        customersById: {'c1': customer()},
        shipmentsById: {'s1': shipment()},
      );
      // Leading '=' is defused with a single quote so the cell is text.
      expect(csv, contains("'=HYPERLINK"));
      // And the payload never appears as a live leading '=' cell.
      expect(csv.contains(',=HYPERLINK'), isFalse);
    });

    test('preserves the leading + on phone numbers (no spreadsheet coercion)', () {
      // fullPhone -> "+22670123456"; without the guard Excel strips the '+'.
      final csv = ExportService.packagesToCsv(
        [pkg()],
        customersById: {'c1': customer()},
        shipmentsById: {'s1': shipment()},
      );
      expect(csv, contains("'+22670123456"));
    });

    test('defuses every formula-trigger character', () {
      for (final trigger in ['=', '+', '-', '@']) {
        final csv = ExportService.packagesToCsv(
          [pkg(description: '${trigger}danger')],
          customersById: {'c1': customer()},
          shipmentsById: {'s1': shipment()},
        );
        expect(csv, contains("'$trigger" 'danger'),
            reason: 'field starting with "$trigger" should be quoted');
      }
    });
  });
}
