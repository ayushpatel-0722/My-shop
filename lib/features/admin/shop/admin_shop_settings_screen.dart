import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../core/domain/shop_hours.dart';
import '../../../core/domain/store_profile.dart';
import '../../../core/models/company.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/modern_card.dart';
import '../admin_shell.dart';

/// "Shop Settings": the shop admin edits the public details of their own shop
/// (description, address, contact, opening hours, delivery rules, images).
///
/// Only [Company.toEditableMap] fields are saved; the shop name (which is also
/// the admin login), password, status and ratings are never touched here.
class AdminShopSettingsScreen extends StatefulWidget {
  const AdminShopSettingsScreen({super.key});

  @override
  State<AdminShopSettingsScreen> createState() =>
      _AdminShopSettingsScreenState();
}

/// Why the shop could not be shown. Turned into text only when building, so
/// no localisation is needed while the screen is still initialising.
enum _LoadFailure { noShop, notFound, error }

class _AdminShopSettingsScreenState extends State<AdminShopSettingsScreen> {
  static const _maxDescription = 600;

  final _formKey = GlobalKey<FormState>();

  final _category = TextEditingController();
  final _details = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _minOrder = TextEditingController();
  final _handling = TextEditingController();
  final _deliveryMinutes = TextEditingController();
  final _logo = TextEditingController();
  final _banner = TextEditingController();
  final _profile = TextEditingController();

  late final List<TextEditingController> _controllers = [
    _category,
    _details,
    _address,
    _phone,
    _location,
    _minOrder,
    _handling,
    _deliveryMinutes,
    _logo,
    _banner,
    _profile,
  ];

  bool _loading = true;
  bool _saving = false;
  _LoadFailure? _loadFailure;
  String _loadErrorDetail = '';

  /// The last saved version; edits are compared against it.
  Company? _saved;
  List<WeeklyHours> _week = [];
  Set<String> _deliveryTypes = {};

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_onEdited);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c
        ..removeListener(_onEdited)
        ..dispose();
    }
    super.dispose();
  }

  void _onEdited() {
    if (mounted && !_loading) setState(() {});
  }

  // ------------------------------------------------------------------ data --

  Future<void> _load() async {
    final companyId = AuthSession.currentUser?.companyId ?? '';
    if (companyId.isEmpty) {
      setState(() {
        _loading = false;
        _loadFailure = _LoadFailure.noShop;
      });
      return;
    }
    try {
      final company = await repo.company(companyId);
      if (!mounted) return;
      if (company == null) {
        setState(() {
          _loading = false;
          _loadFailure = _LoadFailure.notFound;
        });
        return;
      }
      _fill(company);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailure = _LoadFailure.error;
        _loadErrorDetail = '$e';
      });
    }
  }

  /// Shows [company] in the form and treats it as the saved version.
  void _fill(Company company) {
    _saved = company;
    _category.text = company.category;
    _details.text = company.details;
    _address.text = company.address;
    _phone.text = company.phone;
    _location.text = company.location;
    _minOrder.text = _trimNumber(company.minOrderAmount);
    _handling.text = '${company.handlingMinutes}';
    _deliveryMinutes.text = '${company.deliveryMinutes}';
    _logo.text = company.logoUrl;
    _banner.text = company.bannerUrl;
    _profile.text = company.profileImageUrl;
    _deliveryTypes = {...company.deliveryTypes};
    final defaults = WeeklyHours.defaultWeek();
    _week = [
      for (var i = 0; i < 7; i++)
        i < company.weeklyHours.length ? company.weeklyHours[i] : defaults[i],
    ];
  }

  static String _trimNumber(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// What the form currently says, as a company.
  Company _draft() => _saved!.copyWith(
    category: _category.text.trim(),
    details: _details.text.trim(),
    address: _address.text.trim(),
    phone: _phone.text.trim(),
    location: _location.text.trim(),
    logoUrl: _logo.text.trim(),
    bannerUrl: _banner.text.trim(),
    profileImageUrl: _profile.text.trim(),
    deliveryTypes: [
      for (final t in const ['self_pickup', 'home_delivery'])
        if (_deliveryTypes.contains(t)) t,
    ],
    weeklyHours: _week,
    minOrderAmount: double.tryParse(_minOrder.text.trim()) ?? 0,
    handlingMinutes: int.tryParse(_handling.text.trim()) ?? 0,
    deliveryMinutes: int.tryParse(_deliveryMinutes.text.trim()) ?? 0,
  );

  bool get _dirty =>
      _saved != null &&
      jsonEncode(_draft().toEditableMap()) !=
          jsonEncode(_saved!.toEditableMap());

  void _discard() {
    if (_saved == null) return;
    setState(() => _fill(_saved!));
    _formKey.currentState?.reset();
  }

  Future<void> _save() async {
    if (_saving || _saved == null) return;
    final l10n = AppLocalizations.of(context);
    final formOk = _formKey.currentState?.validate() ?? false;
    final hoursError = validateWeeklyHours(_week);
    final deliveryError = _deliveryTypes.isEmpty
        ? l10n.shopChooseDeliveryOption
        : null;
    if (!formOk || hoursError != null || deliveryError != null) {
      _snack(
        hoursError != null
            ? _hoursMessage(hoursError)
            : (deliveryError ?? l10n.shopFixFields),
        error: true,
      );
      return;
    }
    final draft = _draft();
    setState(() => _saving = true);
    try {
      await repo.updateCompanyDetails(draft);
      if (!mounted) return;
      setState(() {
        _saved = _saved!.withEditableFieldsFrom(draft);
        _saving = false;
      });
      _snack(AppLocalizations.of(context).shopDetailsSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(AppLocalizations.of(context).shopCouldNotSave('$e'), error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ----------------------------------------------------------- validators --

  /// An optional http(s) link: empty is fine, anything else must be a link.
  String? _optionalUrl(String? v, String Function() invalidMessage) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!t.startsWith('http://') && !t.startsWith('https://')) {
      return invalidMessage();
    }
    return null;
  }

  String? _validatePhone(String? v) {
    final l10n = AppLocalizations.of(context);
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!RegExp(r'^[+()\-\s\d]+$').hasMatch(t)) return l10n.shopPhoneChars;
    final digits = t.replaceAll(RegExp(r'\D'), '').length;
    if (digits < 7 || digits > 15) return l10n.shopPhoneInvalid;
    return null;
  }

  String? _validateMoney(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || n < 0) {
      return AppLocalizations.of(context).shopMoneyInvalid;
    }
    return null;
  }

  String? _validateMinutes(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 1 || n > 1440) {
      return AppLocalizations.of(context).shopMinutesInvalid;
    }
    return null;
  }

  String _hoursMessage(HoursIssue issue) {
    final l10n = AppLocalizations.of(context);
    return switch (issue.kind) {
      HoursIssueKind.invalidTime => l10n.shopHoursInvalidTime(issue.day),
      HoursIssueKind.sameTime => l10n.shopHoursSameTime(issue.day),
      HoursIssueKind.noOpenDay => l10n.shopHoursNoOpenDay,
    };
  }

  // ----------------------------------------------------------------- hours --

  Future<void> _pickTime(int index, {required bool opening}) async {
    final day = _week[index];
    final current = hoursToMinutes(opening ? day.openTime : day.closeTime) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    final value = formatHours(picked.hour, picked.minute);
    setState(() {
      _week = [
        for (var i = 0; i < _week.length; i++)
          if (i == index)
            WeeklyHours(
              day: day.day,
              openTime: opening ? value : day.openTime,
              closeTime: opening ? day.closeTime : value,
              isClosed: day.isClosed,
            )
          else
            _week[i],
      ];
    });
  }

  void _setDayOpen(int index, bool open) {
    final day = _week[index];
    setState(() {
      _week = [
        for (var i = 0; i < _week.length; i++)
          if (i == index)
            WeeklyHours(
              day: day.day,
              // A day re-opened from the "closed" default gets sane hours.
              openTime: day.openTime == day.closeTime ? '09:00' : day.openTime,
              closeTime: day.openTime == day.closeTime
                  ? '21:00'
                  : day.closeTime,
              isClosed: !open,
            )
          else
            _week[i],
      ];
    });
  }

  /// Marks [index] "open 24 hours" (00:00 to 00:00), or puts back normal hours.
  void _setAllDay(int index, bool allDay) {
    final day = _week[index];
    setState(() {
      _week = [
        for (var i = 0; i < _week.length; i++)
          if (i == index)
            WeeklyHours(
              day: day.day,
              openTime: allDay ? '00:00' : '09:00',
              closeTime: allDay ? '00:00' : '21:00',
            )
          else
            _week[i],
      ];
    });
  }

  void _applyFirstDayToAll() {
    final first = _week.first;
    setState(() {
      _week = [
        for (final d in _week)
          WeeklyHours(
            day: d.day,
            openTime: first.openTime,
            closeTime: first.closeTime,
            isClosed: first.isClosed,
          ),
      ];
    });
  }

  // ----------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: AppLocalizations.of(context).shopSettings,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailure != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadFailureText(), textAlign: TextAlign.center),
              ),
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        MediaQuery.sizeOf(context).width >= 900 ? 32 : 16,
                        16,
                        MediaQuery.sizeOf(context).width >= 900 ? 32 : 16,
                        24,
                      ),
                      children: [
                        _basicInfo(context),
                        const SizedBox(height: 16),
                        _hours(context),
                        const SizedBox(height: 16),
                        _delivery(context),
                        const SizedBox(height: 16),
                        _branding(context),
                      ],
                    ),
                  ),
                  _saveBar(context),
                ],
              ),
            ),
    );
  }

  String _loadFailureText() {
    final l10n = AppLocalizations.of(context);
    return switch (_loadFailure!) {
      _LoadFailure.noShop => l10n.shopNoShopLinked,
      _LoadFailure.notFound => l10n.shopNotFound,
      _LoadFailure.error => l10n.shopCouldNotLoad(_loadErrorDetail),
    };
  }

  Widget _twoColumns(Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 640) {
        return Column(children: [a, const SizedBox(height: 14), b]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ],
      );
    },
  );

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return ModernCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
    'active' => l10n.shopStatusActive,
    'suspended' => l10n.shopStatusSuspended,
    'inactive' => l10n.shopStatusInactive,
    _ => status,
  };

  Widget _basicInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = _saved!;
    return _section(
      context,
      icon: Icons.storefront_outlined,
      title: l10n.shopDetailsTitle,
      subtitle: l10n.shopDetailsSubtitle,
      trailing: Chip(
        key: const Key('shop-status-chip'),
        label: Text(_statusLabel(l10n, saved.status)),
        visualDensity: VisualDensity.compact,
      ),
      children: [
        TextFormField(
          key: const Key('shop-name-field'),
          initialValue: saved.name,
          enabled: false,
          decoration: InputDecoration(
            labelText: l10n.shopNameLabel,
            helperText: l10n.shopNameHelper,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        _twoColumns(
          TextFormField(
            key: const Key('shop-category-field'),
            controller: _category,
            decoration: InputDecoration(
              labelText: l10n.shopCategoryLabel,
              hintText: l10n.shopCategoryHint,
              border: const OutlineInputBorder(),
            ),
          ),
          TextFormField(
            key: const Key('shop-phone-field'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            validator: _validatePhone,
            decoration: InputDecoration(
              labelText: l10n.shopPhoneLabel,
              helperText: l10n.shopPhoneHelper,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('shop-details-field'),
          controller: _details,
          maxLines: 4,
          maxLength: _maxDescription,
          validator: (v) =>
              (v?.trim().isEmpty ?? true) ? l10n.shopDescriptionRequired : null,
          decoration: InputDecoration(
            labelText: l10n.shopDescriptionLabel,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        _twoColumns(
          TextFormField(
            key: const Key('shop-address-field'),
            controller: _address,
            maxLines: 2,
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? l10n.shopAddressRequired : null,
            decoration: InputDecoration(
              labelText: l10n.shopAddressLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          TextFormField(
            key: const Key('shop-map-field'),
            controller: _location,
            keyboardType: TextInputType.url,
            validator: (v) => _optionalUrl(v, () => l10n.shopMapLinkInvalid),
            decoration: InputDecoration(
              labelText: l10n.shopMapLabel,
              hintText: 'https://maps.google.com/...',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hours(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The same rule the shopper app uses for its "Open now" pill.
    final open = StoreHours.isOpenAt(_draft(), DateTime.now());
    return _section(
      context,
      icon: Icons.schedule,
      title: l10n.shopHoursTitle,
      subtitle: l10n.shopHoursSubtitle,
      trailing: Chip(
        key: const Key('shop-open-now-chip'),
        avatar: Icon(
          Icons.circle,
          size: 10,
          color: open ? Colors.green : Colors.red,
        ),
        label: Text(open ? l10n.shopOpenNow : l10n.shopClosedNow),
        visualDensity: VisualDensity.compact,
      ),
      children: [
        for (var i = 0; i < _week.length; i++) _dayRow(context, i),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('shop-copy-hours'),
            onPressed: _applyFirstDayToAll,
            icon: const Icon(Icons.copy_all, size: 18),
            label: Text(l10n.shopApplyHoursToAll(_week.first.day)),
          ),
        ),
      ],
    );
  }

  Widget _dayRow(BuildContext context, int i) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final day = _week[i];
    final allDay = isOpenAllDay(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              day.day,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            key: Key('shop-day-switch-$i'),
            value: !day.isClosed,
            onChanged: (v) => _setDayOpen(i, v),
          ),
          if (day.isClosed)
            Text(
              l10n.shopDayClosed,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            )
          else ...[
            FilterChip(
              key: Key('shop-day-24h-$i'),
              label: Text(l10n.shopOpen24Hours),
              selected: allDay,
              onSelected: (v) => _setAllDay(i, v),
            ),
            if (!allDay) ...[
              OutlinedButton(
                key: Key('shop-day-open-$i'),
                onPressed: () => _pickTime(i, opening: true),
                child: Text(day.openTime),
              ),
              Text(l10n.shopTo),
              OutlinedButton(
                key: Key('shop-day-close-$i'),
                onPressed: () => _pickTime(i, opening: false),
                child: Text(day.closeTime),
              ),
              if (isOvernight(day))
                Text(
                  l10n.shopClosesNextDay,
                  key: Key('shop-day-overnight-$i'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _delivery(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _section(
      context,
      icon: Icons.local_shipping_outlined,
      title: l10n.shopDeliveryTitle,
      subtitle: l10n.shopDeliverySubtitle,
      children: [
        CheckboxListTile(
          key: const Key('shop-delivery-pickup'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shopSelfPickup),
          value: _deliveryTypes.contains('self_pickup'),
          onChanged: (v) => setState(() {
            v == true
                ? _deliveryTypes.add('self_pickup')
                : _deliveryTypes.remove('self_pickup');
          }),
        ),
        CheckboxListTile(
          key: const Key('shop-delivery-home'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shopHomeDelivery),
          value: _deliveryTypes.contains('home_delivery'),
          onChanged: (v) => setState(() {
            v == true
                ? _deliveryTypes.add('home_delivery')
                : _deliveryTypes.remove('home_delivery');
          }),
        ),
        if (_deliveryTypes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.shopChooseDeliveryOption,
              key: const Key('shop-delivery-error'),
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 8),
        _twoColumns(
          TextFormField(
            key: const Key('shop-min-order-field'),
            controller: _minOrder,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _validateMoney,
            decoration: InputDecoration(
              labelText: l10n.shopMinOrderLabel,
              prefixText: '${_saved!.currencySymbol} ',
              helperText: l10n.shopMinOrderHelper,
              border: const OutlineInputBorder(),
            ),
          ),
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.shopCurrencyLabel,
              helperText: l10n.shopCurrencyHelper,
              border: const OutlineInputBorder(),
            ),
            child: Text(
              '${_saved!.currency} (${_saved!.currencySymbol})',
              key: const Key('shop-currency'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _twoColumns(
          TextFormField(
            key: const Key('shop-handling-field'),
            controller: _handling,
            keyboardType: TextInputType.number,
            validator: _validateMinutes,
            decoration: InputDecoration(
              labelText: l10n.shopHandlingLabel,
              helperText: l10n.shopHandlingHelper,
              border: const OutlineInputBorder(),
            ),
          ),
          TextFormField(
            key: const Key('shop-delivery-minutes-field'),
            controller: _deliveryMinutes,
            keyboardType: TextInputType.number,
            validator: _validateMinutes,
            decoration: InputDecoration(
              labelText: l10n.shopDeliveryMinutesLabel,
              helperText: l10n.shopDeliveryMinutesHelper,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _branding(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget row(String label, TextEditingController c, String key) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _preview(c.text.trim(), key),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                key: Key('shop-$key-field'),
                controller: c,
                keyboardType: TextInputType.url,
                validator: (v) =>
                    _optionalUrl(v, () => l10n.shopImageLinkInvalid(label)),
                decoration: InputDecoration(
                  labelText: l10n.shopImageLinkLabel(label),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _section(
      context,
      icon: Icons.image_outlined,
      title: l10n.shopBrandingTitle,
      subtitle: l10n.shopBrandingSubtitle,
      children: [
        row(l10n.shopLogoLabel, _logo, 'logo'),
        row(l10n.shopBannerLabel, _banner, 'banner'),
        row(l10n.shopStorefrontLabel, _profile, 'profile'),
      ],
    );
  }

  Widget _preview(String url, String key) {
    final isUrl = url.startsWith('http://') || url.startsWith('https://');
    final box = Container(
      key: Key('shop-$key-preview'),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: isUrl
          ? ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: AppProductImage(url: url, width: 56, height: 56),
            )
          : const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    );
    if (!isUrl) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showFullScreenImages(context, urls: [url]),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: box),
    );
  }

  Widget _saveBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dirty = _dirty;
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dirty ? l10n.shopUnsavedChanges : l10n.shopAllSaved,
                  key: const Key('shop-save-status'),
                  style: TextStyle(
                    color: dirty
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: dirty ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              TextButton(
                key: const Key('shop-discard-button'),
                onPressed: dirty && !_saving ? _discard : null,
                child: Text(l10n.shopDiscard),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('shop-save-button'),
                onPressed: dirty && !_saving ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(l10n.shopSaveChanges),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
