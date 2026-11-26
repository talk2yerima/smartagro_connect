import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/farm_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../domain/farmer_directory.dart';
import '../../shared/widgets/produce_image.dart';
import '../marketplace/seller_profile_screen.dart' show FarmerCard;

/// Buyer Home: farmers picked for them (saved ones, their state, the best
/// rated) and the farmers they looked at recently.
class FarmersForYou extends ConsumerWidget {
  const FarmersForYou({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(productsProvider).valueOrNull;
    if (all == null || all.isEmpty) return const SizedBox.shrink();
    final me = ref.watch(authSessionProvider);
    final saved = ref.watch(favouriteFarmersProvider);
    final recentIds = ref.watch(recentFarmersProvider);

    final recommended = recommendedFarmers(all,
        myId: me?.id, myLocation: me?.location, saved: saved, max: 8);
    final byId = {for (final f in farmersFrom(all)) f.id: f};
    final recent = [
      for (final id in recentIds)
        if (byId[id] != null) byId[id]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recommended.isNotEmpty) ...[
          _Title(
            'Recommended farmers',
            onAll: () => context.go('/main/market'),
          ),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recommended.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => FarmerCard(farmer: recommended[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (recent.isNotEmpty) ...[
          const _Title('Recently viewed farmers'),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _RecentFarmer(farmer: recent[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.onAll});

  final String text;
  final VoidCallback? onAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (onAll != null)
              TextButton(onPressed: onAll, child: const Text('Explore')),
          ],
        ),
      );
}

/// Photo card with the name and rating over it.
class _RecentFarmer extends StatelessWidget {
  const _RecentFarmer({required this.farmer});

  final FarmerSummary farmer;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/seller/${farmer.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 110,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (farmer.imageUrl.isNotEmpty)
                ProduceImage(url: farmer.imageUrl)
              else
                Container(
                  color: AppColors.emerald,
                  child: const Icon(Icons.agriculture_rounded,
                      color: Colors.white70, size: 36),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                    stops: [0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(farmer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(
                        farmer.rating > 0
                            ? '★ ${farmer.rating.toStringAsFixed(1)}'
                            : 'No rating yet',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
