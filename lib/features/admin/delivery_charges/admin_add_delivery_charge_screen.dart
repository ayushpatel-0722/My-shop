import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/delivery_charge.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_card.dart';
import '../admin_shell.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

enum DeliveryPricingType { paid, free }

class AdminAddDeliveryChargeScreen extends StatefulWidget {
  final DeliveryCharge? deliveryCharge;
  final String? pincode;

  const AdminAddDeliveryChargeScreen({
    super.key,
    this.deliveryCharge,
    this.pincode,
  });

  @override
  State<AdminAddDeliveryChargeScreen> createState() =>
      _AdminAddDeliveryChargeScreenState();
}

class _AdminAddDeliveryChargeScreenState
    extends State<AdminAddDeliveryChargeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _chargeCtrl;
  late final TextEditingController _freeAboveCtrl;
  late final TextEditingController _estimatedDaysCtrl;

  DeliveryPricingType _pricingType = DeliveryPricingType.paid;
  bool _isServiceable = true;
  bool _isSaving = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    final d = widget.deliveryCharge;
    _isEdit =
        d != null || (widget.pincode != null && widget.pincode!.isNotEmpty);

    _pincodeCtrl = TextEditingController(
      text: d?.pincode ?? widget.pincode ?? '',
    );
    _chargeCtrl = TextEditingController(
      text: d != null && d.charge > 0 ? d.charge.toStringAsFixed(0) : '',
    );
    _freeAboveCtrl = TextEditingController(
      text: d != null && d.freeAboveAmount > 0
          ? d.freeAboveAmount.toStringAsFixed(0)
          : '',
    );
    _estimatedDaysCtrl = TextEditingController(text: d?.estimatedDays ?? '');

    if (d != null && d.isFree) {
      _pricingType = DeliveryPricingType.free;
    } else {
      _pricingType = DeliveryPricingType.paid;
    }

    _isServiceable = d?.isServiceable ?? true;
  }

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    _chargeCtrl.dispose();
    _freeAboveCtrl.dispose();
    _estimatedDaysCtrl.dispose();
    super.dispose();
  }

  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final pincode = _pincodeCtrl.text.trim();
      final isFree = _pricingType == DeliveryPricingType.free;
      final charge = isFree
          ? 0.0
          : (double.tryParse(_chargeCtrl.text.trim()) ?? 0.0);
      final freeAboveAmount = isFree
          ? 0.0
          : (double.tryParse(_freeAboveCtrl.text.trim()) ?? 0.0);
      final estimatedDays = _estimatedDaysCtrl.text.trim();

      final deliveryCharge = DeliveryCharge(
        pincode: pincode,
        companyId: _companyId,
        charge: charge,
        isFree: isFree,
        freeAboveAmount: freeAboveAmount,
        isServiceable: _isServiceable,
        estimatedDays: estimatedDays,
      );

      await repo.saveDeliveryCharge(deliveryCharge);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? AppLocalizations.of(context).deliveryChargeUpdatedFor(pincode)
                : AppLocalizations.of(
                    context,
                  ).deliveryChargeCreatedFor(pincode),
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).failedToSaveDeliveryCharge('$e'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.adminDelivery,
      title: _isEdit
          ? AppLocalizations.of(context).editDeliveryCharge
          : AppLocalizations.of(context).addDeliveryCharge,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 20,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ModernCard(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).pincodeInformation,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _pincodeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).postalPincode,
                            hintText: AppLocalizations.of(context).eG380001,
                            prefixIcon: const Icon(Icons.pin_drop_outlined),
                            border: const OutlineInputBorder(),
                            helperText: AppLocalizations.of(
                              context,
                            ).msg6DigitAreaCodeForDeliveryService,
                            enabled: !_isEdit,
                          ),
                          validator: (value) {
                            final val = value?.trim() ?? '';
                            if (val.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              ).enterA6DigitPincode;
                            }
                            if (val.length != 6) {
                              return AppLocalizations.of(
                                context,
                              ).pincodeMustBeExactly6Digits;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            AppLocalizations.of(context).serviceableArea,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _isServiceable
                                ? AppLocalizations.of(
                                    context,
                                  ).ordersCanBeDeliveredToThisPincode
                                : AppLocalizations.of(
                                    context,
                                  ).deliveryTemporarilySuspendedToThisPincode,
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _isServiceable,
                          onChanged: (v) => setState(() => _isServiceable = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ModernCard(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).pricingChargeRules,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<DeliveryPricingType>(
                          segments: [
                            ButtonSegment(
                              value: DeliveryPricingType.paid,
                              label: Text(
                                AppLocalizations.of(context).fixedPaidCharge,
                              ),
                              icon: const Icon(Icons.payments_outlined),
                            ),
                            ButtonSegment(
                              value: DeliveryPricingType.free,
                              label: Text(
                                AppLocalizations.of(context).freeDelivery2,
                              ),
                              icon: const Icon(Icons.local_shipping_outlined),
                            ),
                          ],
                          selected: {_pricingType},
                          onSelectionChanged: (set) {
                            setState(() => _pricingType = set.first);
                          },
                        ),
                        const SizedBox(height: 18),
                        if (_pricingType == DeliveryPricingType.paid) ...[
                          TextFormField(
                            controller: _chargeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).standardDeliveryCharge,
                              hintText: AppLocalizations.of(context).eG40,
                              prefixIcon: Icon(Icons.currency_rupee),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (_pricingType == DeliveryPricingType.paid) {
                                final v = val?.trim() ?? '';
                                if (v.isEmpty) {
                                  return AppLocalizations.of(
                                    context,
                                  ).enterDeliveryCharge;
                                }
                                final num = double.tryParse(v);
                                if (num == null || num < 0) {
                                  return AppLocalizations.of(
                                    context,
                                  ).enterAValidAmount;
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _freeAboveCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).freeDeliveryForOrdersAboveOptional,
                              hintText: AppLocalizations.of(
                                context,
                              ).eG499LeaveBlankIfNoFreeTier,
                              prefixIcon: Icon(Icons.card_giftcard),
                              border: OutlineInputBorder(),
                              helperText: AppLocalizations.of(
                                context,
                              ).customersGet0DeliveryFeeWhenOrderSubtotalMeetsThisAmount,
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).deliveryWillAlwaysBeFree0ForAllOrdersToThisPincode,
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ModernCard(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).estimatedDeliveryTimeEta,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _estimatedDaysCtrl,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).estimatedDeliveryTimeOptional,
                            hintText: AppLocalizations.of(
                              context,
                            ).eG12DaysSameDay3045Mins,
                            prefixIcon: Icon(Icons.timer_outlined),
                            border: OutlineInputBorder(),
                            helperText: AppLocalizations.of(
                              context,
                            ).displayedToCustomersOnCheckoutProductPages,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving
                          ? AppLocalizations.of(context).saving
                          : (_isEdit
                                ? AppLocalizations.of(
                                    context,
                                  ).updateDeliveryCharge
                                : AppLocalizations.of(
                                    context,
                                  ).saveDeliveryCharge),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isSaving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
