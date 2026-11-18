import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/nigerian_states.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/di/upload_providers.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/services/app_lock.dart';
import '../../core/utils/money_format.dart' show formatNgn;
import '../../domain/entities/product_listing.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/produce_image.dart';
import '../../shared/widgets/skeleton_list.dart';

// ---------------------------------------------------------------------------
// Card decoration
// ---------------------------------------------------------------------------

BoxDecoration _card(bool isDark) => BoxDecoration(
      color: isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.borderLight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(myListingsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: const Text(
          'My Listings',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        actions: [
          async.whenOrNull(
                data: (list) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.deepGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${list.length} listing${list.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                  ),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/marketplace/add'),
        backgroundColor: AppColors.deepGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Listing',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 4, height: 100),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 48, color: AppColors.gray),
                const SizedBox(height: 12),
                Text(friendlyError(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.gray)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(myListingsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return EmptyState(
              type: EmptyStateType.marketplace,
              icon: Icons.storefront_outlined,
              title: 'No listings yet',
              subtitle:
                  'Your produce listings will appear here once you add them.',
              actionLabel: 'Add your first listing',
              onAction: () => context.push('/marketplace/add'),
            );
          }

          return RefreshIndicator(
            color: AppColors.deepGreen,
            onRefresh: () async {
              ref.invalidate(myListingsProvider);
              await ref.read(myListingsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: listings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ListingCard(
                listing: listings[i],
                isDark: isDark,
              )
                  .animate(delay: (40 * i).ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.04, end: 0, duration: 300.ms),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Listing card
// ---------------------------------------------------------------------------

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.listing, required this.isDark});

  final ProductListing listing;
  final bool isDark;

  Color get _availabilityColor => switch (listing.availability) {
        ProductAvailability.inStock => AppColors.mintGreen,
        ProductAvailability.limited => AppColors.golden,
        ProductAvailability.preOrder => AppColors.infoBlue,
        ProductAvailability.soldOut => AppColors.errorRed,
      };

  String get _availabilityLabel => switch (listing.availability) {
        ProductAvailability.inStock => 'In Stock',
        ProductAvailability.limited => 'Limited',
        ProductAvailability.preOrder => 'Pre-order',
        ProductAvailability.soldOut => 'Sold Out',
      };

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete listing?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${listing.title}" will be permanently removed.',
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(productRepositoryProvider).deleteListing(listing.id);
      ref.invalidate(productsProvider);
      ref.invalidate(myListingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed. ${friendlyError(e)}'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditListingSheet(listing: listing, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.charcoal;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.gray;

    return Container(
      decoration: _card(isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail ───────────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(12)),
            child: SizedBox(
              width: 90,
              height: 100,
              child: listing.imageUrl.isNotEmpty
                  ? ProduceImage(
                      url: listing.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : _PlaceholderThumb(isDark: isDark),
            ),
          ),

          // ── Details ─────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Price + quantity
                  Text(
                    '${formatNgn(listing.priceNgn)}  ·  ${listing.quantityKg} kg',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.deepGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // State + availability badge
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: subColor),
                      const SizedBox(width: 2),
                      Text(
                        listing.state,
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _availabilityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _availabilityLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _availabilityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Actions ─────────────────────────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              IconButton(
                onPressed: () => _showEditSheet(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.deepGreen,
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.errorRed,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: AppColors.gray),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit bottom sheet
// ---------------------------------------------------------------------------

class _EditListingSheet extends StatefulWidget {
  const _EditListingSheet({required this.listing, required this.ref});

  final ProductListing listing;
  final WidgetRef ref;

  @override
  State<_EditListingSheet> createState() => _EditListingSheetState();
}

class _EditListingSheetState extends State<_EditListingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _cityCtrl;
  String? _state;
  late String _imageUrl;
  double? _uploadProgress;
  late ProductAvailability _availability;
  bool _saving = false;

  static const _green = AppColors.emerald;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.listing.title);
    _priceCtrl =
        TextEditingController(text: widget.listing.priceNgn.toString());
    _qtyCtrl =
        TextEditingController(text: widget.listing.quantityKg.toString());
    _descCtrl = TextEditingController(text: widget.listing.description);
    _cityCtrl = TextEditingController(text: widget.listing.city);
    _state = kNigerianStates.contains(widget.listing.state)
        ? widget.listing.state
        : null;
    _imageUrl = widget.listing.imageUrl;
    _availability = widget.listing.availability;
  }

  /// Picks and uploads a new photo; the listing keeps the old one until
  /// "Save changes".
  Future<void> _changePhoto(ImageSource source) async {
    widget.ref.read(appLockProvider.notifier).allowNextReturn();
    final XFile? file;
    try {
      file = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open the camera or gallery.')));
      }
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _uploadProgress = 0);
    try {
      final url =
          await widget.ref.read(imageUploadServiceProvider).uploadProductImage(
                filePath: file.path,
                productId:
                    '${widget.listing.id}-${DateTime.now().millisecondsSinceEpoch}',
                userId: widget.ref.read(authSessionProvider)?.id,
                onProgress: (p) {
                  if (mounted) setState(() => _uploadProgress = p);
                },
              );
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Photo not uploaded. ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final data = {
        'id': widget.listing.id,
        'title': _titleCtrl.text.trim(),
        'priceNgn': int.parse(_priceCtrl.text.trim()),
        'quantityKg': int.parse(_qtyCtrl.text.trim()),
        // Stored spelling, as read by the app and the payments backend
        // ('soldOut' was being saved and read back as in stock).
        'availability': switch (_availability) {
          ProductAvailability.inStock => 'in_stock',
          ProductAvailability.limited => 'limited',
          ProductAvailability.preOrder => 'pre_order',
          ProductAvailability.soldOut => 'sold_out',
        },
        'description': _descCtrl.text.trim(),
        'state': _state ?? widget.listing.state,
        'city': _cityCtrl.text.trim(),
        'sellerId': widget.listing.sellerId,
        'sellerName': widget.listing.sellerName,
        'sellerRating': widget.listing.sellerRating,
        'verified': widget.listing.verified,
        'imageUrl': _imageUrl,
        'lat': widget.listing.lat,
        'lng': widget.listing.lng,
      };

      await widget.ref
          .read(productRepositoryProvider)
          .updateListing(widget.listing.id, data);

      widget.ref.invalidate(productsProvider);
      widget.ref.invalidate(myListingsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing updated'),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed. ${friendlyError(e)}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.cardDark : Colors.white;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
          key: _formKey,
          // Scrolls so the longer form fits small phones with the keyboard up.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white24
                          : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text(
                  'Edit Listing',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color:
                        isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 16),

                // Photo
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _uploadProgress != null
                            ? Center(
                                child: CircularProgressIndicator(
                                    value: _uploadProgress))
                            : ProduceImage(
                                url: _imageUrl, width: 72, height: 72),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploadProgress != null
                                ? null
                                : () => _changePhoto(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Camera'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _uploadProgress != null
                                ? null
                                : () => _changePhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _inputDeco('Title', Icons.label_outline, isDark),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      _inputDeco('Description', Icons.notes_rounded, isDark),
                ),
                const SizedBox(height: 4),

                // Location
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _state,
                        isExpanded: true,
                        decoration:
                            _inputDeco('State', Icons.map_outlined, isDark),
                        items: [
                          for (final st in kNigerianStates)
                            DropdownMenuItem(value: st, child: Text(st)),
                        ],
                        onChanged: (v) => setState(() => _state = v),
                        validator: (v) => v == null ? 'Choose a state' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cityCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDeco(
                            'City / LGA', Icons.location_on_outlined, isDark),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Price + Qty row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDeco(
                            'Price per kg (₦)', Icons.sell_outlined, isDark),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDeco(
                            'Qty (kg)', Icons.scale_outlined, isDark),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Availability chips
                Text(
                  'AVAILABILITY',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ProductAvailability.values.map((a) {
                    final selected = _availability == a;
                    final color = switch (a) {
                      ProductAvailability.inStock => AppColors.mintGreen,
                      ProductAvailability.limited => AppColors.golden,
                      ProductAvailability.preOrder => AppColors.infoBlue,
                      ProductAvailability.soldOut => AppColors.errorRed,
                    };
                    final label = switch (a) {
                      ProductAvailability.inStock => 'In Stock',
                      ProductAvailability.limited => 'Limited',
                      ProductAvailability.preOrder => 'Pre-order',
                      ProductAvailability.soldOut => 'Sold Out',
                    };
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _availability = a),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? color
                                  : (isDark ? Colors.white12 : Colors.black12),
                            ),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected
                                  ? color
                                  : (isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Save button
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.softWhite,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _green, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
