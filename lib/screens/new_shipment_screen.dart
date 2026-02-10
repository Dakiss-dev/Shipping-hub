import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'shipment_detail_screen.dart';

class NewShipmentScreen extends StatefulWidget {
  final ShipmentType? preselectedType;

  const NewShipmentScreen({super.key, this.preselectedType});

  @override
  State<NewShipmentScreen> createState() => _NewShipmentScreenState();
}

class _NewShipmentScreenState extends State<NewShipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late ShipmentType _type;
  String _destination = 'Burkina Faso';
  DateTime? _departureDate;
  final _notesController = TextEditingController();

  final _destinations = [
    'Burkina Faso',
    'Ivory Coast (Côte d\'Ivoire)',
    'Togo',
    'Ghana',
    'Senegal',
    'Mali',
    'Niger',
    'Benin',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.preselectedType ?? ShipmentType.air;
    _updateDefaultName();
  }

  void _updateDefaultName() {
    final typeStr = _type == ShipmentType.air ? 'Air' : 'Sea';
    final dest = _destination.split(' ').first;
    final now = DateTime.now();
    _nameController.text =
        '$typeStr to $dest - ${now.month}/${now.day}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('newShipment')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Shipment Type Toggle
            Text(
              l.t('selectShipmentType'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _typeOption(
                    icon: Icons.flight_takeoff,
                    label: l.t('airShipment'),
                    emoji: '✈️',
                    isSelected: _type == ShipmentType.air,
                    color: AppColors.airText,
                    bgColor: AppColors.airBg,
                    onTap: () {
                      setState(() {
                        _type = ShipmentType.air;
                        _updateDefaultName();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _typeOption(
                    icon: Icons.directions_boat,
                    label: l.t('seaShipment'),
                    emoji: '🚢',
                    isSelected: _type == ShipmentType.sea,
                    color: AppColors.seaText,
                    bgColor: AppColors.seaBg,
                    onTap: () {
                      setState(() {
                        _type = ShipmentType.sea;
                        _updateDefaultName();
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Destination
            Text(
              l.t('destination'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _destination,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.pin_drop_outlined),
              ),
              items: _destinations.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Row(
                    children: [
                      Text(destinationFlag(d),
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Flexible(child: Text(d)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _destination = val;
                    _updateDefaultName();
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            // Shipment Name
            Text(
              l.t('shipmentName'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.label_outline),
                hintText: 'e.g. Air to Ouaga - Feb 15',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter a name' : null,
            ),

            const SizedBox(height: 20),

            // Departure Date
            Text(
              l.t('departureDate'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      _departureDate ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _departureDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _departureDate != null
                      ? '${_departureDate!.month}/${_departureDate!.day}/${_departureDate!.year}'
                      : 'Select date (optional)',
                  style: TextStyle(
                    color: _departureDate != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Notes
            Text(
              l.t('notes'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.notes),
                ),
                hintText: 'Optional notes...',
              ),
            ),

            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _createShipment,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(l.t('newShipment')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeOption({
    required IconData icon,
    required String label,
    required String emoji,
    required bool isSelected,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createShipment() {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<AppProvider>();
      final shipment = Shipment(
        name: _nameController.text,
        type: _type,
        destination: _destination,
        departureDate: _departureDate,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      provider.addShipment(shipment);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ShipmentDetailScreen(shipmentId: shipment.id),
        ),
      );
    }
  }
}
