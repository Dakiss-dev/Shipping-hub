import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../models/country_codes.dart';
import '../services/contact_service.dart';
import '../widgets/phone_input.dart';
import '../widgets/package_photo.dart';
import '../theme.dart';

class NewPackageScreen extends StatefulWidget {
  final Shipment shipment;

  const NewPackageScreen({super.key, required this.shipment});

  @override
  State<NewPackageScreen> createState() => _NewPackageScreenState();
}

class _NewPackageScreenState extends State<NewPackageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();

  String? _photoPath;
  XFile? _photoFile;
  Customer? _selectedCustomer;
  String? _selectedPresetItem;
  SeaItemType? _selectedSeaItem;
  double _calculatedPrice = 0.0;
  bool _isCustomWeight = false;
  CountryCode _receiverCountryCode = defaultCountryCode;

  bool get isAir => widget.shipment.type == ShipmentType.air;

  @override
  void dispose() {
    _weightController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    super.dispose();
  }

  void _recalculatePrice() {
    final provider = context.read<AppProvider>();
    double price = 0.0;

    if (isAir) {
      if (_selectedPresetItem != null) {
        price = provider.calculateAirPrice(presetItem: _selectedPresetItem);
      } else {
        final weight = double.tryParse(_weightController.text);
        if (weight != null) {
          price = provider.calculateAirPrice(weightKg: weight);
        }
      }
    } else {
      if (_selectedSeaItem != null &&
          _selectedSeaItem != SeaItemType.customWeight) {
        price = provider.calculateSeaPrice(itemType: _selectedSeaItem);
      } else {
        final weight = double.tryParse(_weightController.text);
        if (weight != null) {
          price = provider.calculateSeaPrice(weightKg: weight);
        }
      }
    }

    setState(() => _calculatedPrice = price);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _photoPath = image.path;
          _photoFile = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera/gallery: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;
    final currency = provider.currency == 'USD' ? '\$' : provider.currency;
    final isAirShipment = isAir;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('newPackage')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo Section
            _buildPhotoSection(l),
            const SizedBox(height: 20),

            // Customer Selection
            _buildCustomerSection(context, provider, l),
            const SizedBox(height: 20),

            // Item/Weight Section
            if (isAirShipment)
              _buildAirPricingSection(provider, l, currency)
            else
              _buildSeaPricingSection(provider, l, currency),

            const SizedBox(height: 20),

            // Description
            Text(
              l.t('description'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'What\'s in the package?',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 28),
                  child: Icon(Icons.description_outlined),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Receiver (Destinataire) Section
            _buildReceiverSection(context, provider, l),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: l.t('notes'),
                prefixIcon: const Icon(Icons.notes),
              ),
            ),

            const SizedBox(height: 24),

            // Price Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navyLight],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on,
                      color: AppColors.gold, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('calculatedPrice'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$currency${_calculatedPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _savePackage,
                icon: const Icon(Icons.check_circle),
                label: Text(l.t('addPackage')),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('packagePhoto'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (_photoPath != null)
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.surface,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PackagePhoto(
                    photoPath: _photoPath,
                    height: 200,
                    width: double.infinity,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: AppColors.danger,
                  radius: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Colors.white),
                    onPressed: () => setState(() {
                      _photoPath = null;
                      _photoFile = null;
                    }),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Photo taken',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _photoButton(
                  icon: Icons.camera_alt,
                  label: l10n.t('takePhoto'),
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _photoButton(
                  icon: Icons.photo_library,
                  label: l10n.t('chooseFromGallery'),
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.gold, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSection(
      BuildContext context, AppProvider provider, l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('selectCustomer'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        // Quick action buttons: From Contacts + Manual Add
        Row(
          children: [
            Expanded(
              child: _customerActionButton(
                icon: Icons.contacts,
                label: 'From Contacts',
                color: AppColors.navy,
                onTap: () => _importFromContacts(context, provider),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _customerActionButton(
                icon: Icons.person_add,
                label: l10n.t('newCustomer'),
                color: AppColors.gold,
                onTap: () => _showAddCustomerDialog(context, provider),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Selected customer display or dropdown
        if (_selectedCustomer != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.navy,
                  radius: 20,
                  child: Text(
                    _selectedCustomer!.name.isNotEmpty
                        ? _selectedCustomer!.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCustomer!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _selectedCustomer!.phone,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedCustomer = null),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          )
        else if (provider.customers.isNotEmpty)
          DropdownButtonFormField<Customer>(
            value: _selectedCustomer,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
              hintText: 'Choose existing customer',
            ),
            items: provider.customers.map((c) {
              return DropdownMenuItem(
                value: c,
                child: Text('${c.name}  (${c.phone})'),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedCustomer = val),
            validator: (v) => v == null ? 'Please select a customer' : null,
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: AppColors.textSecondary, size: 16),
                SizedBox(width: 8),
                Text(
                  'Use the buttons above to add a customer',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReceiverSection(
      BuildContext context, AppProvider provider, l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.person_pin_circle, color: AppColors.navy, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.t('receiver'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              // Import receiver from contacts too
              TextButton.icon(
                onPressed: () => _importReceiverFromContacts(context),
                icon: const Icon(Icons.contacts, size: 14, color: AppColors.navy),
                label: Text(
                  l10n.t('fromContacts'),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('receiverHint'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _receiverNameController,
            decoration: InputDecoration(
              labelText: l10n.t('receiverName'),
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          PhoneInput(
            controller: _receiverPhoneController,
            label: l10n.t('receiverPhone'),
            initialCountryCode: _receiverCountryCode,
            onCountryCodeChanged: (code) {
              _receiverCountryCode = code;
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importReceiverFromContacts(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact import available on mobile app.'),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final contacts = await ContactService.getContacts();
      if (!mounted) return;
      Navigator.pop(context);

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contacts found or permission denied'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<ContactResult>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _ContactPickerSheet(contacts: contacts),
      );

      if (selected != null && mounted) {
        setState(() {
          _receiverNameController.text = selected.name;
          _receiverPhoneController.text = selected.phone;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receiver set to ${selected.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildAirPricingSection(AppProvider provider, l10n, String currency) {
    final presets = provider.airPricing.presetItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('presetItem'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presets.entries.map((entry) {
              final isSelected = _selectedPresetItem == entry.key;
              return ChoiceChip(
                label: Text(
                  '${entry.key} ($currency${entry.value.toStringAsFixed(0)})',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.navy,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPresetItem = entry.key;
                      _isCustomWeight = false;
                      _weightController.clear();
                    } else {
                      _selectedPresetItem = null;
                    }
                  });
                  _recalculatePrice();
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.t('orEnterWeight'),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.0',
                  labelText: l10n.t('weight'),
                  prefixIcon: const Icon(Icons.scale),
                  suffixText: 'kg',
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedPresetItem = null;
                    _isCustomWeight = true;
                  });
                  _recalculatePrice();
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.airBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$currency${provider.airPricing.pricePerKg.toStringAsFixed(0)}/kg',
                style: const TextStyle(
                  color: AppColors.airText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeaPricingSection(AppProvider provider, l10n, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('selectItem'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SeaItemType.values.map((type) {
            final isSelected = _selectedSeaItem == type;
            final price = type == SeaItemType.customWeight
                ? null
                : provider.seaPricing.itemPrices[type];
            return ChoiceChip(
              label: Text(
                type == SeaItemType.customWeight
                    ? l10n.t('customWeight')
                    : '${seaItemTypeLabel(type)} ${price != null ? '($currency${price.toStringAsFixed(0)})' : ''}',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.navy,
              onSelected: (selected) {
                setState(() {
                  _selectedSeaItem = selected ? type : null;
                  _isCustomWeight = type == SeaItemType.customWeight;
                  if (!_isCustomWeight) _weightController.clear();
                });
                _recalculatePrice();
              },
            );
          }).toList(),
        ),
        if (_selectedSeaItem == SeaItemType.customWeight) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.0',
                    labelText: l10n.t('weight'),
                    prefixIcon: const Icon(Icons.scale),
                    suffixText: 'kg',
                  ),
                  onChanged: (_) => _recalculatePrice(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.seaBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$currency${provider.seaPricing.pricePerKg.toStringAsFixed(0)}/kg',
                  style: const TextStyle(
                    color: AppColors.seaText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _customerActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importFromContacts(
      BuildContext context, AppProvider provider) async {
    // On web, show a message that contacts aren't available
    if (kIsWeb) {
      _showWebContactsFallback(context, provider);
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final contacts = await ContactService.getContacts();
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contacts found or permission denied'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      // Show contact picker bottom sheet
      final selected = await showModalBottomSheet<ContactResult>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _ContactPickerSheet(contacts: contacts),
      );

      if (selected != null && mounted) {
        // Check if customer already exists by phone
        final existing = provider.customers.where(
          (c) => c.phone.replaceAll(RegExp(r'[^\d]'), '') ==
              selected.phone.replaceAll(RegExp(r'[^\d]'), ''),
        );

        if (existing.isNotEmpty) {
          setState(() => _selectedCustomer = existing.first);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selected.name} already in your customers!'),
              backgroundColor: AppColors.info,
            ),
          );
        } else {
          final customer = ContactService.contactToCustomer(selected);
          await provider.addCustomer(customer);
          setState(() => _selectedCustomer = customer);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selected.name} added from contacts!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if still showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access contacts: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showWebContactsFallback(BuildContext context, AppProvider provider) {
    // On web, contacts API isn't available - show manual entry with a helpful message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Contact import available on mobile app. Use manual entry for web preview.'),
        backgroundColor: AppColors.info,
        duration: Duration(seconds: 3),
      ),
    );
    _showAddCustomerDialog(context, provider);
  }

  void _showAddCustomerDialog(BuildContext context, AppProvider provider) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    CountryCode customerCountryCode = defaultCountryCode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.l10n.t('newCustomer')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: provider.l10n.t('customerName'),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              PhoneInput(
                controller: phoneController,
                label: provider.l10n.t('phone'),
                initialCountryCode: customerCountryCode,
                onCountryCodeChanged: (code) => customerCountryCode = code,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.l10n.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final customer = Customer(
                  name: nameController.text,
                  phone: phoneController.text,
                  phoneCountryCode: customerCountryCode.dialCode,
                );
                provider.addCustomer(customer);
                setState(() => _selectedCustomer = customer);
                Navigator.pop(ctx);
              }
            },
            child: Text(provider.l10n.t('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _savePackage() async {
    if (_formKey.currentState?.validate() != true) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_calculatedPrice == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an item or enter weight'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text);

    final pkg = ShippingPackage(
      customerId: _selectedCustomer!.id,
      shipmentId: widget.shipment.id,
      shipmentType: widget.shipment.type,
      photoPath: _photoPath,
      description: _descriptionController.text,
      weightKg: weight,
      seaItemType: isAir ? null : _selectedSeaItem,
      presetItemName: isAir ? _selectedPresetItem : null,
      price: _calculatedPrice,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      receiverName: _receiverNameController.text.isNotEmpty
          ? _receiverNameController.text
          : null,
      receiverPhone: _receiverPhoneController.text.isNotEmpty
          ? _receiverPhoneController.text
          : null,
      receiverPhoneCountryCode: _receiverPhoneController.text.isNotEmpty
          ? _receiverCountryCode.dialCode
          : null,
    );

    // Read the captured image bytes (works on web + mobile) so the provider
    // can upload them to cloud storage. A read error just drops the photo.
    Uint8List? photoBytes;
    if (_photoFile != null) {
      try {
        photoBytes = await _photoFile!.readAsBytes();
      } catch (e) {
        photoBytes = null;
      }
    }
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.addPackage(pkg, photoBytes: photoBytes);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📦 Package ${pkg.referenceNumber} added!'),
        backgroundColor: AppColors.success,
      ),
    );
    if (provider.photoWasDropped) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.l10n.t('photoNeedsConnection'))),
      );
    }

    Navigator.pop(context);
  }
}

// ==================== CONTACT PICKER BOTTOM SHEET ====================

class _ContactPickerSheet extends StatefulWidget {
  final List<ContactResult> contacts;

  const _ContactPickerSheet({required this.contacts});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  String _search = '';

  List<ContactResult> get _filteredContacts {
    if (_search.isEmpty) return widget.contacts;
    return widget.contacts
        .where((c) =>
            c.name.toLowerCase().contains(_search.toLowerCase()) ||
            c.phone.contains(_search))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
                  const Icon(Icons.contacts, color: AppColors.navy),
                  const SizedBox(width: 10),
                  const Text(
                    'Select Contact',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.contacts.length} contacts',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
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

            // Contact list
            Expanded(
              child: _filteredContacts.isEmpty
                  ? const Center(
                      child: Text(
                        'No contacts found',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredContacts.length,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.navyLight,
                            child: Text(
                              contact.name.isNotEmpty
                                  ? contact.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text(
                            contact.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            contact.phone,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.gold,
                          ),
                          onTap: () => Navigator.pop(context, contact),
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
