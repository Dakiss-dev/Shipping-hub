import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../models/country_codes.dart';
import '../services/contact_service.dart';
import '../widgets/phone_input.dart';
import '../theme.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final l = provider.l10n;

    var customers = provider.customers;
    if (_searchQuery.isNotEmpty) {
      customers = customers
          .where((c) =>
              c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.phone.contains(_searchQuery))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('customers')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '${l.t('search')} by name or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: context.semantic.cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: customers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    l.t('noData'),
                    style: TextStyle(
                        color: context.semantic.textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customers are added when you log packages',
                    style:
                        TextStyle(color: context.semantic.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: customers.length,
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemBuilder: (context, index) {
                final customer = customers[index];
                final packageCount = provider.packages
                    .where((p) => p.customerId == customer.id)
                    .length;
                final totalSpent = provider.packages
                    .where((p) => p.customerId == customer.id)
                    .fold(0.0, (sum, p) => sum + p.price);
                final currency = provider.currency == 'USD'
                    ? '\$'
                    : provider.currency;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.navy,
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullPhone,
                          style: TextStyle(
                              color: context.semantic.textSecondary, fontSize: 13),
                        ),
                        Text(
                          '$packageCount packages • $currency${totalSpent.toStringAsFixed(0)} total',
                          style: TextStyle(
                              color: context.semantic.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: context.semantic.textSecondary),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editCustomer(context, provider, customer);
                            break;
                          case 'delete':
                            _deleteCustomer(context, provider, customer);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: const Icon(Icons.edit, size: 20),
                            title: Text(l.t('edit')),
                            dense: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: const Icon(Icons.delete,
                                color: AppColors.danger, size: 20),
                            title: Text(l.t('delete'),
                                style:
                                    const TextStyle(color: AppColors.danger)),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // From Contacts FAB
          FloatingActionButton.small(
            heroTag: 'contacts',
            onPressed: () => _importFromContacts(context, provider),
            backgroundColor: AppColors.navy,
            child: const Icon(Icons.contacts, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          // Manual Add FAB
          FloatingActionButton(
            heroTag: 'manual',
            onPressed: () => _addCustomer(context, provider),
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromContacts(
      BuildContext context, AppProvider provider) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Contact import available on mobile app. Use manual entry for web.'),
          backgroundColor: AppColors.info,
        ),
      );
      _addCustomer(context, provider);
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
        final existing = provider.customers.where(
          (c) => c.phone.replaceAll(RegExp(r'[^\d]'), '') ==
              selected.phone.replaceAll(RegExp(r'[^\d]'), ''),
        );

        if (existing.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selected.name} already in your customers!'),
              backgroundColor: AppColors.info,
            ),
          );
        } else {
          final customer = ContactService.contactToCustomer(selected);
          await provider.addCustomer(customer);
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access contacts: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _addCustomer(BuildContext context, AppProvider provider) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
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
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: '${provider.l10n.t('email')} (optional)',
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
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
                provider.addCustomer(Customer(
                  name: nameController.text,
                  phone: phoneController.text,
                  phoneCountryCode: customerCountryCode.dialCode,
                  email: emailController.text.isNotEmpty
                      ? emailController.text
                      : null,
                ));
                Navigator.pop(ctx);
              }
            },
            child: Text(provider.l10n.t('save')),
          ),
        ],
      ),
    );
  }

  void _editCustomer(
      BuildContext context, AppProvider provider, Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final emailController = TextEditingController(text: customer.email ?? '');
    final formKey = GlobalKey<FormState>();
    CountryCode editCountryCode = findCountryByDialCode(customer.phoneCountryCode) ?? defaultCountryCode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.l10n.t('edit')),
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
                initialCountryCode: editCountryCode,
                onCountryCodeChanged: (code) => editCountryCode = code,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: '${provider.l10n.t('email')} (optional)',
                  prefixIcon: const Icon(Icons.email),
                ),
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
                customer.name = nameController.text;
                customer.phone = phoneController.text;
                customer.phoneCountryCode = editCountryCode.dialCode;
                customer.email = emailController.text.isNotEmpty
                    ? emailController.text
                    : null;
                provider.updateCustomer(customer);
                Navigator.pop(ctx);
              }
            },
            child: Text(provider.l10n.t('save')),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(
      BuildContext context, AppProvider provider, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content:
            Text('Delete ${customer.name}? Existing packages will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              provider.deleteCustomer(customer.id);
              Navigator.pop(ctx);
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.contacts, color: context.semantic.textPrimary),
                  const SizedBox(width: 10),
                  const Text(
                    'Import from Contacts',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.contacts.length}',
                    style: TextStyle(
                      color: context.semantic.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: context.semantic.scaffold,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: _filteredContacts.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts found',
                        style: TextStyle(color: context.semantic.textSecondary),
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
                            style: TextStyle(
                              color: context.semantic.textSecondary,
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
