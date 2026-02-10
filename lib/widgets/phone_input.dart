import 'package:flutter/material.dart';
import '../models/country_codes.dart';
import '../theme.dart';

/// Phone number input with country code selector.
/// Stores the full international number (e.g., "+22670123456").
class PhoneInput extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final CountryCode initialCountryCode;
  final ValueChanged<CountryCode>? onCountryCodeChanged;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;

  const PhoneInput({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.initialCountryCode = defaultCountryCode,
    this.onCountryCodeChanged,
    this.validator,
    this.prefixIcon,
  });

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountryCode;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CountryPickerSheet(
        selectedCode: _selectedCountry.code,
        onSelected: (country) {
          setState(() => _selectedCountry = country);
          widget.onCountryCodeChanged?.call(country);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  /// Get the full international phone number
  String get fullPhoneNumber {
    final raw = widget.controller.text.replaceAll(RegExp(r'[^\d]'), '');
    if (raw.isEmpty) return '';
    return '${_selectedCountry.dialCode}$raw';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country code selector button
        GestureDetector(
          onTap: _showCountryPicker,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedCountry.flag,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 4),
                Text(
                  _selectedCountry.dialCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, 
                    color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Phone number field
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint ?? 'Phone number',
              prefixIcon: widget.prefixIcon != null 
                  ? Icon(widget.prefixIcon, size: 20) 
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            validator: widget.validator,
          ),
        ),
      ],
    );
  }
}

/// Provides a static helper to extract country code from a full phone number
class PhoneHelper {
  /// Extract the full international number from controller text + country code
  static String getFullNumber(String rawPhone, CountryCode country) {
    final digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    return '${country.dialCode}$digits';
  }

  /// Format a phone number for WhatsApp (strip everything except digits and +)
  static String formatForWhatsApp(String phone) {
    // If already has + prefix, just clean non-digits after +
    if (phone.startsWith('+')) {
      return '+${phone.substring(1).replaceAll(RegExp(r'[^\d]'), '')}';
    }
    // Otherwise just clean
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }
}

// ==================== COUNTRY PICKER BOTTOM SHEET ====================

class _CountryPickerSheet extends StatefulWidget {
  final String selectedCode;
  final ValueChanged<CountryCode> onSelected;

  const _CountryPickerSheet({
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _search = '';

  List<CountryCode> get _filtered {
    if (_search.isEmpty) return countryCodes;
    return countryCodes
        .where((c) =>
            c.name.toLowerCase().contains(_search.toLowerCase()) ||
            c.dialCode.contains(_search) ||
            c.code.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.public, color: AppColors.navy),
                  const SizedBox(width: 10),
                  const Text(
                    'Select Country',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search country...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            // List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) {
                  final country = _filtered[index];
                  final isSelected = country.code == widget.selectedCode;
                  return ListTile(
                    leading: Text(country.flag,
                        style: const TextStyle(fontSize: 24)),
                    title: Text(
                      country.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    trailing: Text(
                      country.dialCode,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.navy : AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppColors.navy.withValues(alpha: 0.05),
                    onTap: () => widget.onSelected(country),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
