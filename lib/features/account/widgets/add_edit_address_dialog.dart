import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/customer.dart';
import '../../auth/auth_cubit.dart';

/// Modal bottom sheet for adding or editing a delivery address (up to 3 addresses).
class AddEditAddressSheet extends StatefulWidget {
  final AddressEntry? initialAddress;
  final bool isFirstAddress;

  const AddEditAddressSheet({
    super.key,
    this.initialAddress,
    this.isFirstAddress = false,
  });

  static Future<AddressEntry?> show(
    BuildContext context, {
    AddressEntry? initialAddress,
    bool isFirstAddress = false,
  }) {
    return showModalBottomSheet<AddressEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditAddressSheet(
        initialAddress: initialAddress,
        isFirstAddress: isFirstAddress,
      ),
    );
  }

  @override
  State<AddEditAddressSheet> createState() => _AddEditAddressSheetState();
}

class _AddEditAddressSheetState extends State<AddEditAddressSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _houseNoCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;

  late String _label;
  late bool _isDefault;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAddress;
    final user = context.read<AuthCubit>().currentUser;

    _nameCtrl = TextEditingController(text: init?.name ?? user?.name ?? '');
    _phoneCtrl = TextEditingController(
      text: init?.phone ?? user?.mobileNumber ?? '',
    );
    _pincodeCtrl = TextEditingController(text: init?.pincode ?? '');
    _houseNoCtrl = TextEditingController(text: init?.houseNo ?? '');
    _streetCtrl = TextEditingController(text: init?.address ?? '');
    _cityCtrl = TextEditingController(text: init?.city ?? 'Ahmedabad');
    _stateCtrl = TextEditingController(text: init?.state ?? 'Gujarat');

    _label = init?.label.isNotEmpty == true ? init!.label : 'Home';
    _isDefault = init?.isDefault ?? widget.isFirstAddress;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pincodeCtrl.dispose();
    _houseNoCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final entry = AddressEntry(
      id: widget.initialAddress?.id ?? '',
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      houseNo: _houseNoCtrl.text.trim(),
      address: _streetCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      label: _label,
      isDefault: _isDefault,
    );

    final ok = await context.read<AuthCubit>().saveUserAddress(entry);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      Navigator.of(context).pop(entry);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save address. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialAddress != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + viewInsets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFFF5247),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Address' : 'Add New Address',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2229),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(height: 20),

            // Scrollable fields
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Contact Info
                    const Text(
                      'Contact Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter name'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Mobile Number *',
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter phone';
                              }
                              if (v.trim().length < 10) {
                                return '10 digits required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Address Info
                    const Text(
                      'Address Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _pincodeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Pincode *',
                              prefixIcon: const Icon(
                                Icons.pin_drop_outlined,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter pincode';
                              }
                              if (v.trim().length < 6) return '6 digits';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _cityCtrl,
                            decoration: InputDecoration(
                              labelText: 'City *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter city'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _houseNoCtrl,
                      decoration: InputDecoration(
                        labelText: 'House / Flat / Block No. *',
                        hintText: 'e.g. Flat 402, Block A',
                        prefixIcon: const Icon(
                          Icons.home_work_outlined,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter house/flat number'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _streetCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Street / Area / Landmark *',
                        hintText: 'e.g. Near Shiv Temple, Vastrapur',
                        prefixIcon: const Icon(
                          Icons.edit_road_outlined,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter street or landmark'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Address Type (Home / Work / Other)
                    const Text(
                      'Save Address As',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Home', 'Work', 'Other'].map((type) {
                        final isSelected =
                            _label.toLowerCase() == type.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _label = type);
                            },
                            avatar: Icon(
                              type == 'Home'
                                  ? Icons.home
                                  : type == 'Work'
                                  ? Icons.work
                                  : Icons.location_on,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF4B5563),
                            ),
                            selectedColor: const Color(0xFFFF5247),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E2229),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            backgroundColor: const Color(0xFFF3F4F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Default Address Toggle
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Set as default delivery address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: _isDefault,
                      activeColor: const Color(0xFFFF5247),
                      onChanged: (val) {
                        setState(() => _isDefault = val ?? false);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5247),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing ? 'Update Address' : 'Save & Deliver Here',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
