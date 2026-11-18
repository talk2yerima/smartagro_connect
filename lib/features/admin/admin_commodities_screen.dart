import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/utils/money_format.dart';
import '../../shared/widgets/status_badge.dart';

// ─── Firestore provider ───────────────────────────────────────────────────────

final _commoditiesStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).commoditiesStream();
});

// ─── Seed data (used only to populate Firestore on first run) ─────────────────

const _kSeed = [
  {
    'name': 'Maize',
    'category': 'Grains',
    'unit': 'bag (100 kg)',
    'priceNgn': 28000.0,
    'changePct': 2.3
  },
  {
    'name': 'Cassava',
    'category': 'Tubers',
    'unit': 'kg',
    'priceNgn': 120.0,
    'changePct': -0.8
  },
  {
    'name': 'Tomatoes',
    'category': 'Vegetables',
    'unit': 'crate',
    'priceNgn': 9500.0,
    'changePct': 5.1
  },
  {
    'name': 'Yam',
    'category': 'Tubers',
    'unit': 'tuber',
    'priceNgn': 450.0,
    'changePct': 1.2
  },
  {
    'name': 'Palm Oil',
    'category': 'Oils',
    'unit': 'litre',
    'priceNgn': 1600.0,
    'changePct': -1.5
  },
  {
    'name': 'Groundnut',
    'category': 'Legumes',
    'unit': 'bag (50 kg)',
    'priceNgn': 19000.0,
    'changePct': 3.7
  },
  {
    'name': 'Sorghum',
    'category': 'Grains',
    'unit': 'bag (100 kg)',
    'priceNgn': 22000.0,
    'changePct': 0.5
  },
  {
    'name': 'Pepper (Scotch)',
    'category': 'Spices',
    'unit': 'kg',
    'priceNgn': 800.0,
    'changePct': -2.1
  },
  {
    'name': 'Plantain',
    'category': 'Fruits',
    'unit': 'bunch',
    'priceNgn': 1800.0,
    'changePct': 1.8
  },
];

Color _categoryColor(String cat) => switch (cat) {
      'Grains' => AppColors.golden,
      'Tubers' => AppColors.warmOrange,
      'Vegetables' => AppColors.freshGreen,
      'Oils' => AppColors.infoBlue,
      'Legumes' => AppColors.mintGreen,
      'Spices' => AppColors.errorRed,
      'Fruits' => AppColors.emerald,
      _ => AppColors.gray,
    };

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminCommoditiesScreen extends ConsumerStatefulWidget {
  const AdminCommoditiesScreen({super.key});

  @override
  ConsumerState<AdminCommoditiesScreen> createState() =>
      _AdminCommoditiesScreenState();
}

class _AdminCommoditiesScreenState
    extends ConsumerState<AdminCommoditiesScreen> {
  String _search = '';

  Future<void> _seedCommodities() async {
    final firestore = ref.read(firestoreServiceProvider);
    for (final item in _kSeed) {
      final id = (item['name'] as String).toLowerCase().replaceAll(' ', '_');
      await firestore.upsertCommodity(id, item);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catalog seeded with default commodities'),
          backgroundColor: AppColors.mintGreen,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> commodity) async {
    final name = commodity['name'] as String? ?? 'this commodity';
    final id = commodity['id'] as String?;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete commodity',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content:
            Text('Remove "$name" from the catalog? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider).deleteCommodity(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"$name" removed from catalog'),
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic>? existing) async {
    final existingPrice =
        (existing?['priceNgn'] as num?)?.toStringAsFixed(0) ?? '';
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final categoryCtrl =
        TextEditingController(text: existing?['category'] as String? ?? '');
    final unitCtrl =
        TextEditingController(text: existing?['unit'] as String? ?? '');
    final priceCtrl = TextEditingController(text: existingPrice);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null ? 'Add Commodity' : 'Edit ${existing['name']}',
          style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Field(controller: nameCtrl, label: 'Name'),
              const SizedBox(height: 10),
              _Field(controller: categoryCtrl, label: 'Category'),
              const SizedBox(height: 10),
              _Field(controller: unitCtrl, label: 'Unit (e.g. kg, bag)'),
              const SizedBox(height: 10),
              _Field(
                controller: priceCtrl,
                label: 'Reference price (₦)',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text) ?? 0.0;
              final name = nameCtrl.text.trim().isEmpty
                  ? 'New Commodity'
                  : nameCtrl.text.trim();
              final id = existing?['id'] as String? ??
                  name.toLowerCase().replaceAll(' ', '_');
              final category = categoryCtrl.text.trim().isEmpty
                  ? 'Uncategorised'
                  : categoryCtrl.text.trim();
              final unit =
                  unitCtrl.text.trim().isEmpty ? 'kg' : unitCtrl.text.trim();
              final changePct =
                  (existing?['changePct'] as num?)?.toDouble() ?? 0.0;

              try {
                await ref.read(firestoreServiceProvider).upsertCommodity(id, {
                  'name': name,
                  'category': category,
                  'unit': unit,
                  'priceNgn': price,
                  'changePct': changePct,
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(existing == null
                        ? '$name added to catalog'
                        : '$name updated'),
                    backgroundColor: AppColors.mintGreen,
                    duration: const Duration(seconds: 2),
                  ));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('Save failed. ${friendlyError(e)}'),
                    backgroundColor: AppColors.errorRed,
                  ));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.deepGreen),
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    categoryCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final commoditiesAsync = ref.watch(_commoditiesStreamProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Commodity Catalog',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(null),
        backgroundColor: AppColors.deepGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
      ),
      body: commoditiesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.deepGreen)),
        error: (_, __) =>
            const Center(child: Text('Could not load commodities.')),
        data: (items) {
          final q = _search.toLowerCase();
          final filtered = q.isEmpty
              ? items
              : items
                  .where((c) =>
                      (c['name'] as String? ?? '').toLowerCase().contains(q) ||
                      (c['category'] as String? ?? '')
                          .toLowerCase()
                          .contains(q))
                  .toList();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 56, color: AppColors.gray),
                  const SizedBox(height: 12),
                  const Text('No commodities yet',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.gray)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _seedCommodities,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepGreen),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Seed default catalog'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or category…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    return _CommodityCard(
                      commodity: c,
                      isDark: isDark,
                      onEdit: () => _showEditDialog(c),
                      onDelete: () => _confirmDelete(c),
                    )
                        .animate(delay: (40 * i).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.04, end: 0, duration: 300.ms);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Commodity card ───────────────────────────────────────────────────────────

class _CommodityCard extends StatelessWidget {
  const _CommodityCard({
    required this.commodity,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> commodity;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = commodity;
    final name = (c['name'] as String?) ?? '';
    final category = (c['category'] as String?) ?? '';
    final unit = (c['unit'] as String?) ?? '';
    final price = (c['priceNgn'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _categoryColor(category).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bar_chart_rounded,
                  color: _categoryColor(category), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusBadge(
                          label: category, color: _categoryColor(category)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(children: [
                      TextSpan(
                        text: formatNgn(price),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.charcoal,
                        ),
                      ),
                      TextSpan(
                        text: ' / $unit',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.gray),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.infoBlue,
              tooltip: 'Edit',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppColors.errorRed,
              tooltip: 'Delete',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text field helper ────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field(
      {required this.controller, required this.label, this.keyboardType});

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
