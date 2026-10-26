import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/banner.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/auth_cubit.dart';
import '../admin_shell.dart';

/// Offer banner manager — upload graphics, preview 16:9 images,
/// configure action targets, and delete/manage banners (Section 13.1).
class AdminBannersScreen extends StatelessWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final companyId = context.read<AuthCubit>().currentUser?.companyId ?? '';
    final theme = Theme.of(context);

    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).banners,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add Banner',
          onPressed: () => _showCreateSheet(context, companyId),
        ),
      ],
      child: StreamBuilder<List<OfferBanner>>(
        stream: repo.offerBanners(companyId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snap.data ?? const <OfferBanner>[];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).noOfferBanners,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Promote seasonal discounts, products, or collections by creating a banner.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Banner'),
                      onPressed: () => _showCreateSheet(context, companyId),
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
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final banner = list[i];
                  return _BannerCard(banner: banner, companyId: companyId);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, String companyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CreateBannerSheet(companyId: companyId),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final OfferBanner banner;
  final String companyId;

  const _BannerCard({required this.banner, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
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
          // 16:9 Banner Image Preview
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              child: banner.image.isNotEmpty
                  ? Image.network(
                      banner.image,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (ctx, error, stackTrace) => Center(
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

          // Metadata & Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Action: ${banner.actionType.name.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Priority: ${banner.priority}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (banner.targetProdId != null &&
                          banner.targetProdId!.isNotEmpty)
                        Text(
                          'Target Product: ${banner.targetProdId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (banner.targetCatId != null &&
                          banner.targetCatId!.isNotEmpty)
                        Text(
                          'Target Category: ${banner.targetCatId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Delete Banner',
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Banner'),
        content: const Text(
          'Are you sure you want to delete this offer banner? It will no longer be shown to customers.',
        ),
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

    if (confirmed != true) return;

    try {
      await repo.deleteBanner(banner.id, companyId: companyId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner deleted successfully.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete banner: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _CreateBannerSheet extends StatefulWidget {
  final String companyId;
  const _CreateBannerSheet({required this.companyId});

  @override
  State<_CreateBannerSheet> createState() => _CreateBannerSheetState();
}

class _CreateBannerSheetState extends State<_CreateBannerSheet> {
  final _imageUrlCtrl = TextEditingController();
  final _priorityCtrl = TextEditingController(text: '0');
  String _actionType = 'product';
  String? _targetProdId;
  String? _targetCatId;
  bool _isSaving = false;

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = _imageUrlCtrl.text.trim();

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
                  AppLocalizations.of(context).createOfferBanner,
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

            // Live 16:9 Image Preview
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: previewUrl.isNotEmpty
                  ? Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          'Invalid or inaccessible image URL',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter an image URL below to preview',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _imageUrlCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).imageUrl,
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
                      labelText: AppLocalizations.of(context).tapAction,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'product',
                        child: Text(AppLocalizations.of(context).product),
                      ),
                      DropdownMenuItem(
                        value: 'category',
                        child: Text(AppLocalizations.of(context).category),
                      ),
                      DropdownMenuItem(
                        value: 'external_url',
                        child: Text(AppLocalizations.of(context).externalUrl),
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
                    controller: _priorityCtrl,
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
              decoration: InputDecoration(
                labelText: _actionType == 'category'
                    ? AppLocalizations.of(context).categoryId
                    : _actionType == 'product'
                    ? AppLocalizations.of(context).productId
                    : AppLocalizations.of(context).url,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() {
                if (_actionType == 'category') {
                  _targetCatId = v.trim();
                } else if (_actionType == 'product') {
                  _targetProdId = v.trim();
                }
              }),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _isSaving ? null : _saveBanner,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );
  }

  void _saveBanner() async {
    final url = _imageUrlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid image URL.')),
      );
      return;
    }

    final priority = int.tryParse(_priorityCtrl.text.trim()) ?? 0;

    setState(() => _isSaving = true);
    try {
      await repo.saveBanner(
        OfferBanner(
          id: '',
          companyId: widget.companyId,
          image: url,
          actionType: _actionType == 'category'
              ? BannerActionType.category
              : _actionType == 'external_url'
              ? BannerActionType.externalUrl
              : BannerActionType.product,
          targetCatId: _targetCatId,
          targetProdId: _targetProdId,
          priority: priority,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save banner: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
