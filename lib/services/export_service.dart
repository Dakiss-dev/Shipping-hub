import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Pro feature: export an operator's package ledger to a spreadsheet-ready CSV
/// and hand it to the platform share sheet (WhatsApp, email, Drive, etc.).
///
/// The CSV builder is a pure function so it can be unit-tested without a device;
/// the share step is the only part that touches platform channels.
class ExportService {
  /// Columns, in order. Kept explicit (not derived from the model) so the
  /// export stays stable even if the model gains internal fields.
  static const List<String> csvHeaders = [
    'Reference',
    'Created',
    'Shipment',
    'Type',
    'Destination',
    'Sender',
    'Sender Phone',
    'Receiver',
    'Receiver Phone',
    'Description',
    'Weight (kg)',
    'Price',
    'Payment',
  ];

  /// Builds an RFC-4180 CSV string for [packages], joining each to its sender
  /// (customer) and shipment via the provided lookup maps. Missing joins render
  /// as empty cells rather than throwing, so a partially-synced ledger still
  /// exports cleanly.
  static String packagesToCsv(
    List<ShippingPackage> packages, {
    required Map<String, Customer> customersById,
    required Map<String, Shipment> shipmentsById,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(csvHeaders.map(_cell).join(','));

    for (final p in packages) {
      final customer = customersById[p.customerId];
      final shipment = shipmentsById[p.shipmentId];
      final row = <String>[
        p.referenceNumber,
        _date(p.createdAt),
        shipment?.name ?? '',
        p.shipmentType.name,
        shipment?.destination ?? '',
        customer?.name ?? '',
        customer?.fullPhone ?? '',
        p.receiverName ?? '',
        p.receiverPhone ?? '',
        p.description,
        p.weightKg?.toString() ?? '',
        p.price.toStringAsFixed(2),
        p.paymentStatus.name,
      ];
      buffer.writeln(row.map(_cell).join(','));
    }
    return buffer.toString();
  }

  /// Shares [csv] as a downloadable `.csv` file through the platform share
  /// sheet. [filename] should end in `.csv`. [sharePositionOrigin] anchors the
  /// share popover on iPad/macOS; it is REQUIRED on those platforms (share_plus
  /// throws without it) and ignored on phones, so callers should always pass the
  /// triggering widget's global rect.
  static Future<void> shareCsv(
    String csv, {
    required String filename,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'text/csv', name: filename),
        ],
        fileNameOverrides: [filename],
        subject: filename,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  // yyyy-MM-dd — locale-independent so the CSV sorts and parses predictably in
  // any spreadsheet, regardless of the operator's phone locale.
  static String _date(DateTime d) {
    final local = d.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$day';
  }

  /// Full cell encoding: first neutralize spreadsheet formulas, then apply
  /// RFC-4180 quoting.
  static String _cell(String field) => _quote(_neutralizeFormula(field));

  // Characters that make Excel/Google Sheets treat a cell as a formula. A
  // leading '+' also matters because every phone number here starts with one
  // (Customer.fullPhone), which the spreadsheet would otherwise coerce to a
  // number and strip.
  static const _formulaTriggers = {'=', '+', '-', '@', '\t', '\r'};

  /// Defuses CSV/formula injection (CWE-1236): if a field starts with a formula
  /// trigger, prefix a single quote so the spreadsheet stores it as literal
  /// text. This preserves phone numbers ("+22670123456") and stops payloads
  /// like `=HYPERLINK(...)` or `=IMPORTDATA(...)` from executing when an
  /// operator opens the export.
  static String _neutralizeFormula(String field) {
    if (field.isEmpty) return field;
    if (_formulaTriggers.contains(field[0])) return "'$field";
    return field;
  }

  /// RFC-4180 escaping: a field is quoted when it contains a comma, quote, or
  /// line break, and any inner quotes are doubled. Everything else passes
  /// through untouched.
  static String _quote(String field) {
    final needsQuoting =
        field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r');
    if (!needsQuoting) return field;
    return '"${field.replaceAll('"', '""')}"';
  }
}
