import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/i18n/i18n.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/commodity.dart';
import '../../domain/farmer_directory.dart';
import '../../shared/widgets/empty_state.dart';
import '../marketplace/seller_profile_screen.dart' show FarmerCard, ProductTile;

/// Explore: find farmers and produce — search, today's market prices, top
/// farmers, trending products (with "Best price" badges) and browse by
/// state.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsAsync = ref.watch(productsProvider);
    final commodities = ref.watch(commoditiesProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      appBar: AppBar(
        title: const T('Explore'),
        actions: [
          IconButton(
            tooltip: tr('All products'),
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: () => context.push('/marketplace'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productsProvider);
          try {
            await ref.read(productsProvider.future);
          } catch (_) {
            // The error shows on the screen itself.
          }
        },
        child: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: tr('Could not load produce'),
                subtitle: friendlyError(e),
                actionLabel: tr('Retry'),
                onAction: () => ref.invalidate(productsProvider),
              ),
            ],
          ),
          data: (all) {
            final top = topFarmers(all);
            final trending = trendingProducts(all);
            final best = bestPriceIds(all);
            final states = listingsByState(all);
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _SearchBox(onTap: () => context.push('/search')),
                ),
                if (commodities.isNotEmpty)
                  _PricesStrip(commodities: commodities.take(6).toList()),
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.storefront_outlined,
                      title: tr('No produce listed yet'),
                      subtitle: tr('When farmers list produce, you will find '
                          'them here.'),
                    ),
                  ),
                if (top.isNotEmpty) ...[
                  _Header(
                    title: tr('Top farmers'),
                    action: tr('See all'),
                    onAction: () => context.push('/marketplace'),
                  ),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: top.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => FarmerCard(farmer: top[i]),
                    ),
                  ),
                ],
                if (trending.isNotEmpty) ...[
                  _Header(
                    title: tr('Trending products'),
                    action: tr('See all'),
                    onAction: () => context.push('/marketplace'),
                  ),
                  GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: trending.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (_, i) => ProductTile(
                      product: trending[i],
                      bestPrice: best.contains(trending[i].id),
                    ),
                  ),
                ],
                if (states.isNotEmpty) ...[
                  _Header(title: tr('Explore by state')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in states)
                          ActionChip(
                            avatar: const Icon(Icons.place_outlined, size: 16),
                            label: Text('${s.state} · ${s.count}'),
                            onPressed: () => context.push(
                                '/marketplace?state=${Uri.encodeComponent(s.state)}'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: AppColors.surface(isDark),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.subText(isDark)),
              const SizedBox(width: 10),
              T('Search produce or farmers',
                  style: TextStyle(color: AppColors.subText(isDark))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
        child: Row(
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}

/// Today's commodity prices, a tap away from the full market.
class _PricesStrip extends StatelessWidget {
  const _PricesStrip({required this.commodities});

  final List<Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _Header(
          title: tr('Market prices today'),
          action: tr('All prices'),
          onAction: () => context.push('/main/market/prices'),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: commodities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = commodities[i];
              final up = c.changePct >= 0;
              return Material(
                color: AppColors.card(isDark),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/main/market/commodity/${c.id}'),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border_(isDark)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(formatNgn(c.priceNgn),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(
                          '${up ? '▲' : '▼'} ${c.changePct.abs().toStringAsFixed(1)}% · ${c.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  up ? AppColors.emerald : AppColors.errorRed),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
