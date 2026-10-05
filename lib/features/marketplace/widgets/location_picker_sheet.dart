import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/company.dart';
import '../../../core/models/customer.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/service_locator.dart';
import '../../account/widgets/add_edit_address_dialog.dart';
import '../../auth/auth_cubit.dart';
import '../../auth/widgets/auth_bottom_sheet.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

/// Flipkart / Amazon style Location & Address Selector Bottom Sheet.
class LocationPickerSheet extends StatefulWidget {
  final Company? company;

  const LocationPickerSheet({super.key, this.company});

  static Future<AddressEntry?> show(BuildContext context, {Company? company}) {
    return showModalBottomSheet<AddressEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationPickerSheet(company: company),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _pincodeSearchCtrl = TextEditingController();
  bool _detectingLocation = false;

  @override
  void dispose() {
    _pincodeSearchCtrl.dispose();
    super.dispose();
  }

  void _useCurrentLocation() async {
    setState(() => _detectingLocation = true);

    final detected = await LocationService.detectCurrentLocation();

    if (!mounted) return;
    setState(() => _detectingLocation = false);

    context.read<AuthCubit>().selectActiveAddress(detected);

    if (mounted) {
      Navigator.of(context).pop(detected);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).deliveryLocationSetTo(detected.shortLocation, detected.pincode),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applyPincode(String pincode) {
    final cleanPin = pincode.trim();
    if (cleanPin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).pleaseEnterAValid6DigitPincode,
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final (city, state) = LocationService.resolveCityStateFromPincode(cleanPin);
    final finalCity = city.isNotEmpty ? city : 'India';
    final finalState = state.isNotEmpty ? state : '';

    final pinAddress = AddressEntry(
      id: 'pin_$cleanPin',
      name: AppLocalizations.of(context).deliverTo(cleanPin),
      address: finalCity,
      city: finalCity,
      state: finalState,
      pincode: cleanPin,
      label: AppLocalizations.of(context).pincode3(cleanPin),
      isDefault: true,
    );

    context.read<AuthCubit>().selectActiveAddress(pinAddress);
    Navigator.of(context).pop(pinAddress);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).deliveryLocationUpdatedTo(finalCity, cleanPin),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onAddNewAddress(BuildContext context, List<AddressEntry> addresses) {
    if (addresses.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).maximum3AddressesAllowedPleaseEditOrRemoveAnAddress,
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = context.read<AuthCubit>().currentUser;
    if (user == null) {
      AuthBottomSheet.show(
        context,
        requireAddress: true,
        onAuthenticated: () {
          AddEditAddressSheet.show(context, isFirstAddress: addresses.isEmpty);
        },
      );
      return;
    }

    AddEditAddressSheet.show(context, isFirstAddress: addresses.isEmpty);
  }

  void _onEditAddress(BuildContext context, AddressEntry addr) {
    AddEditAddressSheet.show(context, initialAddress: addr);
  }

  void _onDeleteAddress(BuildContext context, AddressEntry addr) async {
    final authCubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.deleteAddress),
        content: Text(
          l10n.areYouSureYouWantToDelete2(addr.label, addr.shortLocation),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5247),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await authCubit.deleteUserAddress(addr.id);
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.addressDeleted),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final user = authCubit.currentUser;
    final addresses = user?.addresses ?? const <AddressEntry>[];
    final active = AuthSession.activeAddress;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).selectDeliveryLocation,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).selectAnAddressToSeeProductAvailabilityAndDeliveryFees,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Search Pincode Bar (Amazon/Flipkart Style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.search,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _pincodeSearchCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(
                          context,
                        ).enter6DigitDeliveryPincode,
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _applyPincode,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _applyPincode(_pincodeSearchCtrl.text),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5247),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      AppLocalizations.of(context).apply,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Scrollable Options & Saved Addresses
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Use Current Location Action
                _buildActionCard(
                  icon: Icons.my_location,
                  iconColor: const Color(0xFFFF5247),
                  bgColor: const Color(0xFFFFEBEA),
                  title: AppLocalizations.of(context).useCurrentLocation,
                  subtitle: _detectingLocation
                      ? AppLocalizations.of(
                          context,
                        ).detectingYourCurrentLocation
                      : AppLocalizations.of(
                          context,
                        ).autoDetectViaGpsDeviceNetwork,
                  isLoading: _detectingLocation,
                  onTap: _detectingLocation ? null : _useCurrentLocation,
                ),

                const SizedBox(height: 10),

                // 2. Add New Address Action
                _buildActionCard(
                  icon: Icons.add_location_alt_outlined,
                  iconColor: const Color(0xFF3D38D9),
                  bgColor: const Color(0xFFECEBFF),
                  title: AppLocalizations.of(context).addNewAddress,
                  subtitle: addresses.length >= 3
                      ? AppLocalizations.of(context).maximum3AddressesSaved
                      : AppLocalizations.of(
                          context,
                        ).saveHomeWorkOrOtherAddressSaved3(
                          '${addresses.length}',
                        ),
                  trailingBadge: '${addresses.length}/3',
                  onTap: () => _onAddNewAddress(context, addresses),
                ),

                if (addresses.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).savedAddresses,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).of3Added('${addresses.length}'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // List of saved addresses
                  ...addresses.map((addr) {
                    final isSelected =
                        active?.id == addr.id ||
                        (active == null && addr.isDefault);

                    return _buildAddressCard(
                      context,
                      addr: addr,
                      isSelected: isSelected,
                      company: widget.company,
                      onSelect: () {
                        context.read<AuthCubit>().selectActiveAddress(addr);
                        Navigator.of(context).pop(addr);
                      },
                      onEdit: () => _onEditAddress(context, addr),
                      onDelete: () => _onDeleteAddress(context, addr),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    String? trailingBadge,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.02),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2229),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (trailingBadge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trailingBadge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B5563),
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context, {
    required AddressEntry addr,
    required bool isSelected,
    Company? company,
    required VoidCallback onSelect,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final label = addr.label.isNotEmpty
        ? addr.label
        : AppLocalizations.of(context).home;
    final isHome = label.toLowerCase() == 'home';
    final isWork = label.toLowerCase() == 'work';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF8F7) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF5247) : const Color(0xFFE5E7EB),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top label, custom radio indicator, default badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isHome
                          ? const Color(0xFFFFEBEA)
                          : isWork
                          ? const Color(0xFFECEBFF)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHome
                              ? Icons.home
                              : isWork
                              ? Icons.work
                              : Icons.location_on,
                          size: 13,
                          color: isHome
                              ? const Color(0xFFFF5247)
                              : isWork
                              ? const Color(0xFF3D38D9)
                              : const Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isHome
                                ? const Color(0xFFFF5247)
                                : isWork
                                ? const Color(0xFF3D38D9)
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (addr.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F7F2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppLocalizations.of(context).defaultBadge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00875A),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Modern custom radio circle indicator (0 deprecations)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF5247)
                            : const Color(0xFFD1D5DB),
                        width: isSelected ? 6 : 1.5,
                      ),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Name & Phone
              if (addr.name.isNotEmpty || addr.phone.isNotEmpty) ...[
                Row(
                  children: [
                    if (addr.name.isNotEmpty)
                      Text(
                        addr.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                    if (addr.name.isNotEmpty && addr.phone.isNotEmpty)
                      const Text('  •  ', style: TextStyle(color: Colors.grey)),
                    if (addr.phone.isNotEmpty)
                      Text(
                        addr.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Formatted Address
              Text(
                addr.formattedAddress,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),

              // Store delivery availability check if company is passed
              if (company != null) ...[
                const SizedBox(height: 8),
                _buildCompanyDeliveryStatus(company, addr),
              ],

              const Divider(height: 18),

              // Bottom Actions: Edit & Delete
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF4B5563),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      AppLocalizations.of(context).edit,
                      style: TextStyle(fontSize: 12.5),
                    ),
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(
                      AppLocalizations.of(context).delete,
                      style: TextStyle(fontSize: 12.5),
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyDeliveryStatus(Company company, AddressEntry addr) {
    if (company.isSelfPickupOnly ||
        (!company.allowsHomeDelivery && company.allowsSelfPickup)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront, size: 14, color: Color(0xFFE65100)),
            SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).storeOnlySupportsSelfPickup,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE65100),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder(
      future: repo.deliveryCharge(addr.pincode, company.id),
      builder: (context, snap) {
        final charge = snap.data;
        final delivers = charge != null || addr.pincode.isNotEmpty;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: delivers ? const Color(0xFFE6F7F2) : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                delivers ? Icons.check_circle_outline : Icons.error_outline,
                size: 14,
                color: delivers ? const Color(0xFF00875A) : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                delivers
                    ? AppLocalizations.of(context).deliveryAvailableTo(
                        addr.pincode.isNotEmpty
                            ? addr.pincode
                            : AppLocalizations.of(context).thisAddress,
                      )
                    : AppLocalizations.of(
                        context,
                      ).deliveryNotAvailableToThisPincode,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: delivers ? const Color(0xFF00875A) : Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
