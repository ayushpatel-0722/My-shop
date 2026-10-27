import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

import '../../app/theme/app_theme.dart';
import '../../core/services/auth_session.dart';
import '../../core/services/email_service.dart';
import '../auth/auth_cubit.dart';

class ContactSupportScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialOrderId;

  const ContactSupportScreen({
    super.key,
    this.initialCategory,
    this.initialOrderId,
  });

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _orderIdCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  late String _selectedCategory = AppLocalizations.of(
    context,
  ).orderIssueTracking;
  bool _isSubmitting = false;

  late final List<String> _categories = [
    AppLocalizations.of(context).orderIssueTracking,
    AppLocalizations.of(context).deliveryDelayScheduling,
    AppLocalizations.of(context).paymentRefundInquiries,
    AppLocalizations.of(context).damagedWrongItemReceived,
    AppLocalizations.of(context).productDetailsAvailability,
    AppLocalizations.of(context).accountLoginAssistance,
    AppLocalizations.of(context).generalFeedbackSuggestions,
    AppLocalizations.of(context).otherInquiries,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null &&
        _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialOrderId != null) {
      _orderIdCtrl.text = widget.initialOrderId!;
    }

    final user =
        context.read<AuthCubit>().currentUser ?? AuthSession.currentUser;
    if (user != null) {
      if (user.name.isNotEmpty) _nameCtrl.text = user.name;
      if (user.email.isNotEmpty) _emailCtrl.text = user.email;
      if (user.phone.isNotEmpty) {
        _phoneCtrl.text = user.phone;
      } else if (user.mobileNumber.isNotEmpty) {
        _phoneCtrl.text = user.mobileNumber;
      }
      final defaultAddr = user.defaultAddress;
      if (defaultAddr != null) {
        _addressCtrl.text = defaultAddr.formattedAddress;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _orderIdCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitQuery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final fromEmail = _emailCtrl.text.trim();
    final customerName = _nameCtrl.text.trim();
    final mobileNumber = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final orderId = _orderIdCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    // Trigger email via EmailService to ayush123@gmail.com with account details attached
    await EmailService.sendSupportQueryEmail(
      fromEmail: fromEmail,
      customerName: customerName,
      mobileNumber: mobileNumber,
      address: address,
      category: _selectedCategory,
      orderId: orderId.isNotEmpty ? orderId : null,
      subject: subject,
      message: message,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final ticketId = 'TKT-${DateTime.now().millisecondsSinceEpoch % 1000000}';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEFFAF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: Color(0xFF1E8F66),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).querySubmittedEmailSent,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2229),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              ).yourTicketIdIsAnEmailHasBeenTriggeredToAyush123GmailComWithYourAttachedAccountDetails(
                ticketId,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).ticket(ticketId),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E2229),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5247),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: Text(
                AppLocalizations.of(context).paymentDone,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: const Color(0xFF6B7280))
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFFF5247),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).contactSupport,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E2229)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFE8D6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEDE0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.email_outlined,
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
                            AppLocalizations.of(
                              context,
                            ).supportHelplineAyush123GmailCom,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E2229),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).submittingThisFormTriggersAnEmailToAyush123GmailComWithYourMessageAndAccountDetailsAttached,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Category dropdown
              Text(
                AppLocalizations.of(context).issueCategory,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6B7280),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(
                          cat,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E2229),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Order ID (optional)
              _buildTextField(
                controller: _orderIdCtrl,
                label: AppLocalizations.of(context).orderIdOptional,
                hint: AppLocalizations.of(context).eGOrd10294OrPasteOrderId,
                prefixIcon: Icons.receipt_outlined,
              ),
              const SizedBox(height: 16),

              // User details
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _nameCtrl,
                      label: AppLocalizations.of(context).yourName,
                      hint: AppLocalizations.of(context).enterYourName,
                      prefixIcon: Icons.person_outline,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return AppLocalizations.of(context).nameIsRequired;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _phoneCtrl,
                      label: AppLocalizations.of(context).mobileNumber2,
                      hint: AppLocalizations.of(context).msg10DigitPhone,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return AppLocalizations.of(context).phoneIsRequired;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailCtrl,
                label: AppLocalizations.of(context).yourEmailAddressFrom,
                hint: AppLocalizations.of(context).eGUserExampleCom,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return AppLocalizations.of(context).emailIsRequired;
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return AppLocalizations.of(context).enterAValidEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address (optional / prefilled)
              _buildTextField(
                controller: _addressCtrl,
                label: AppLocalizations.of(context).deliveryContactAddress,
                hint: AppLocalizations.of(
                  context,
                ).enterYourAddressToAttachWithQuery,
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),

              // Subject
              _buildTextField(
                controller: _subjectCtrl,
                label: AppLocalizations.of(context).subjectQuerySummary,
                hint: AppLocalizations.of(context).briefSummaryOfTheIssue,
                prefixIcon: Icons.subject_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return AppLocalizations.of(context).pleaseEnterASummary;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Message
              _buildTextField(
                controller: _messageCtrl,
                label: AppLocalizations.of(context).detailedQueryMessage,
                hint: AppLocalizations.of(
                  context,
                ).explainYourIssueQuestionsOrFeedbackInDetailSoWeCanAssistYouQuickly,
                maxLines: 5,
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return AppLocalizations.of(
                      context,
                    ).pleaseDescribeYourQueryInAtLeast10Characters;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5247),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submitQuery,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context).submitQuerySendEmail,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
