import 'package:flutter/material.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/cache/app_images.dart';
import '../../../core/models/banner.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../storefront_lock/locked_admin_shell.dart';

/// Home Screen Ads Banner manager: the banners shown in the carousel at the
/// top of every shopper's home screen (platform-wide, not one shop's offers).
///
/// Same format as the shop's offer banners: a 16:9 picture, what a tap does,
/// and a priority. Password-protected like the other storefront sections: it
/// opens locked.
class AdminAdsBannersScreen extends StatefulWidget {
  const AdminAdsBannersScreen({super.key});

  @override
  State<AdminAdsBannersScreen> createState() => _AdminAdsBannersScreenState();
}

class _AdminAdsBannersScreenState extends State<AdminAdsBannersScreen> {
  late final Stream<List<AdBanner>> _banners = repo.adBanners(shopId: _shopId);

  String get _shopId => AuthSession.currentUser?.companyId ?? '';

  void _openSheet({AdBanner? banner}) {
    final shopId = _shopId;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AdsBannerSheet(banner: banner, shopId: shopId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LockedAdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: l10n.adsBannerTitle,
      actions: [
        IconButton(
          key: const Key('ads-banner-add'),
          icon: const Icon(Icons.add),
          tooltip: l10n.adsBannerAdd,
          onPressed: () => _openSheet(),
        ),
      ],
      child: StreamBuilder<List<AdBanner>>(
        stream: _banners,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = [...(snap.data ?? const <AdBanner>[])]
            ..sort((a, b) => b.priority.compareTo(a.priority));
          if (list.isEmpty) {
            return Center(
              key: const Key('ads-banner-empty'),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.adsBannerEmptyTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.adsBannerEmptyBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.adsBannerCreateFirst),
                      onPressed: () => _openSheet(),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.separated(
                key: const Key('ads-banner-list'),
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, i) => _AdsBannerCard(
                  banner: list[i],
                  onEdit: () => _openSheet(banner: list[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdsBannerCard extends StatelessWidget {
  const _AdsBannerCard({required this.banner, required this.onEdit});

  final AdBanner banner;
  final VoidCallback onEdit;

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adsBannerDeleteTitle),
        content: Text(l10n.adsBannerDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.deleteBanner(banner.id);
      messenger.showAppToast(SnackBar(content: Text(l10n.adsBannerDeleted)));
    } catch (e) {
      messenger.showAppToast(
        SnackBar(
          content: Text('Failed to delete banner: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = banner.actionTarget.trim();
    return Card(
      key: Key('ads-banner-card-${banner.id}'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              child: banner.image.isNotEmpty
                  ? AppNetworkImage(
                      banner.image,
                      fit: BoxFit.cover,
                      decodeWidth: 800,
                      errorBuilder: (_, _, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _chip(
                            theme,
                            'Action: ${banner.actionTypeWire.toUpperCase()}',
                            theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.7,
                            ),
                            theme.colorScheme.onPrimaryContainer,
                          ),
                          _chip(
                            theme,
                            'Priority: ${banner.priority}',
                            Colors.grey.withValues(alpha: 0.15),
                            theme.colorScheme.onSurface,
                          ),
                        ],
                      ),
                      if (target.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Target: $target',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  key: Key('ads-banner-edit-${banner.id}'),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                IconButton(
                  key: Key('ads-banner-delete-${banner.id}'),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Delete',
                  onPressed: () => _delete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(ThemeData theme, String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
    ),
  );
}

class _AdsBannerSheet extends StatefulWidget {
  const _AdsBannerSheet({this.banner, this.shopId = ''});

  /// The shop the new banner belongs to.
  final String shopId;

  /// The banner being edited; null when adding a new one.
  final AdBanner? banner;

  @override
  State<_AdsBannerSheet> createState() => _AdsBannerSheetState();
}

class _AdsBannerSheetState extends State<_AdsBannerSheet> {
  late final _imageUrl = TextEditingController(text: widget.banner?.image);
  late final _priority = TextEditingController(
    text: '${widget.banner?.priority ?? 0}',
  );
  late final _target = TextEditingController(text: widget.banner?.actionTarget);
  late String _actionType = widget.banner?.actionTypeWire ?? 'product';
  bool _saving = false;

  /// Why the last save failed, shown inside the sheet (a toast would sit
  /// behind it).
  String? _error;

  @override
  void dispose() {
    _imageUrl.dispose();
    _priority.dispose();
    _target.dispose();
    super.dispose();
  }

  BannerActionType get _action => switch (_actionType) {
    'category' => BannerActionType.category,
    'external_url' => BannerActionType.externalUrl,
    _ => BannerActionType.product,
  };

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final url = _imageUrl.text.trim();
    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      messenger.showAppToast(
        const SnackBar(
          content: Text('Please enter a valid image URL (http or https).'),
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repo.saveAdBanner(
        AdBanner(
          id: widget.banner?.id ?? '',
          image: url,
          actionType: _action,
          actionTarget: _target.text.trim(),
          priority: int.tryParse(_priority.text.trim()) ?? 0,
          shopId: widget.banner?.shopId ?? widget.shopId,
        ),
      );
      if (!mounted) return;
      nav.pop();
      messenger.showAppToast(SnackBar(content: Text(l10n.adsBannerSaved)));
    } catch (e) {
      if (!mounted) return;
      final denied = e.toString().contains('permission-denied');
      setState(
        () => _error = denied
            ? 'You do not have permission to save banners for this shop.'
            : 'Failed to save banner: $e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preview = _imageUrl.text.trim();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.adsBannerCreateTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: preview.isNotEmpty
                  ? AppNetworkImage(
                      preview,
                      fit: BoxFit.cover,
                      decodeWidth: 600,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          'Invalid or inaccessible image URL',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        'Enter an image URL below to preview',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('ads-banner-image-field'),
              controller: _imageUrl,
              decoration: InputDecoration(
                labelText: l10n.imageUrl,
                hintText: 'https://example.com/banner.jpg',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _actionType,
                    decoration: InputDecoration(
                      labelText: l10n.tapAction,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'product',
                        child: Text(l10n.product),
                      ),
                      DropdownMenuItem(
                        value: 'category',
                        child: Text(l10n.category),
                      ),
                      DropdownMenuItem(
                        value: 'external_url',
                        child: Text(l10n.externalUrl),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _actionType = v ?? 'product'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: const Key('ads-banner-priority-field'),
                    controller: _priority,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ads-banner-target-field'),
              controller: _target,
              decoration: InputDecoration(
                labelText: _actionType == 'category'
                    ? l10n.categoryId
                    : _actionType == 'product'
                    ? l10n.productId
                    : l10n.url,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('ads-banner-error'),
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('ads-banner-save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
