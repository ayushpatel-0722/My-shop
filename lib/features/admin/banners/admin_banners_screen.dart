import '../../../app/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/banner.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/auth_cubit.dart';
import '../admin_shell.dart';

/// Offer banner manager — upload graphics, configure action targets and
/// schedule start/end (Section 13.1).
class AdminBannersScreen extends StatelessWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final companyId = context.read<AuthCubit>().currentUser?.companyId ?? '';
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: 'Banners',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showCreateSheet(context, companyId),
        ),
      ],
      child: StreamBuilder<List<OfferBanner>>(
        stream: repo.offerBanners(companyId),
        builder: (context, snap) {
          final list = snap.data ?? const <OfferBanner>[];
          if (list.isEmpty) {
            return const Center(child: Text('No offer banners'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final b = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.image),
                  title: Text(b.id),
                  subtitle: Text(
                    '${b.actionType.name} · priority ${b.priority}',
                  ),
                  trailing: const Icon(Icons.drag_handle),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, String companyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateBannerSheet(companyId: companyId),
    );
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
  String _actionType = 'product';
  String? _targetProdId;
  String? _targetCatId;

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Offer Banner',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _imageUrlCtrl,
            decoration: const InputDecoration(labelText: 'Image URL'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _actionType,
            decoration: const InputDecoration(labelText: 'Tap action'),
            items: const [
              DropdownMenuItem(value: 'product', child: Text('Product')),
              DropdownMenuItem(value: 'category', child: Text('Category')),
              DropdownMenuItem(
                value: 'external_url',
                child: Text('External URL'),
              ),
            ],
            onChanged: (v) => setState(() => _actionType = v ?? 'product'),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: _actionType == 'category'
                  ? 'Category ID'
                  : _actionType == 'product'
                  ? 'Product ID'
                  : 'URL',
            ),
            onChanged: (v) => setState(() {
              if (_actionType == 'category') {
                _targetCatId = v;
              } else if (_actionType == 'product') {
                _targetProdId = v;
              }
            }),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              repo.saveBanner(
                OfferBanner(
                  id: '',
                  companyId: widget.companyId,
                  image: _imageUrlCtrl.text.trim(),
                  actionType: _actionType == 'category'
                      ? BannerActionType.category
                      : _actionType == 'external_url'
                      ? BannerActionType.externalUrl
                      : BannerActionType.product,
                  targetCatId: _targetCatId,
                  targetProdId: _targetProdId,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
