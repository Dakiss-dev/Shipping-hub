import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/models.dart';

class ContactResult {
  final String name;
  final String phone;

  ContactResult({required this.name, required this.phone});
}

class ContactService {
  /// Check if we're on a platform that supports contacts
  static bool get isSupported => !kIsWeb;

  /// Request permission and pick a contact from the phone's address book
  static Future<ContactResult?> pickContact() async {
    if (kIsWeb) return null;

    try {
      // Request permission
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) return null;

      // Get all contacts with phone numbers
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        sorted: true,
      );

      if (contacts.isEmpty) return null;

      // Return the list for the UI to display
      // This method is called from the UI which will show a picker
      return null; // We'll use getContacts instead
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error picking contact: $e');
      }
      return null;
    }
  }

  /// Get all contacts with phone numbers for display in a picker
  static Future<List<ContactResult>> getContacts() async {
    if (kIsWeb) return [];

    try {
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) return [];

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        sorted: true,
      );

      final results = <ContactResult>[];
      for (final contact in contacts) {
        if (contact.phones.isNotEmpty) {
          results.add(ContactResult(
            name: contact.displayName,
            phone: contact.phones.first.number,
          ));
        }
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting contacts: $e');
      }
      return [];
    }
  }

  /// Convert a ContactResult to a Customer model
  static Customer contactToCustomer(ContactResult contact) {
    return Customer(
      name: contact.name,
      phone: contact.phone,
    );
  }
}
