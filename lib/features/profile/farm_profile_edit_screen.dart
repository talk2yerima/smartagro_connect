import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/farm_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/upload_providers.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/i18n/i18n.dart';
import '../../core/services/app_lock.dart';
import '../../domain/entities/farm_profile.dart';
import '../../shared/widgets/produce_image.dart';
import '../marketplace/seller_profile_screen.dart' show categoryIcon;

/// Farmer: what buyers see on their public page — story, what they
/// produce, opening hours, a cover photo and up to six farm photos.
class FarmProfileEditScreen extends ConsumerStatefulWidget {
  const FarmProfileEditScreen({super.key});

  @override
  ConsumerState<FarmProfileEditScreen> createState() =>
      _FarmProfileEditScreenState();
}

class _FarmProfileEditScreenState extends ConsumerState<FarmProfileEditScreen> {
  final _about = TextEditingController();
  final _hours = TextEditingController();
  final _categories = <String>{};
  String? _coverUrl;
  final _gallery = <String>[];
  bool _loaded = false;
  bool _saving = false;
  String? _uploading; // 'cover' or 'gallery' while a photo uploads
  double _progress = 0;

  @override
  void dispose() {
    _about.dispose();
    _hours.dispose();
    super.dispose();
  }

  void _fill(FarmProfile p) {
    if (_loaded) return;
    _loaded = true;
    _about.text = p.about;
    _hours.text = p.openingHours;
    _categories.addAll(p.categories);
    _coverUrl = p.coverUrl;
    _gallery.addAll(p.galleryUrls.take(maxGalleryPhotos));
  }

  Future<String?> _pickAndUpload(String slot) async {
    final uid = ref.read(authSessionProvider)?.id;
    if (uid == null) return null;
    ref.read(appLockProvider.notifier).allowNextReturn();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return null;
    setState(() {
      _uploading = slot;
      _progress = 0;
    });
    try {
      return await ref.read(imageUploadServiceProvider).uploadFarmPhoto(
            filePath: picked.path,
            userId: uid,
            name: '${slot}_${DateTime.now().millisecondsSinceEpoch}',
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
    } catch (e) {
      _snack('Photo upload failed. ${friendlyError(e)}');
      return null;
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _save() async {
    final uid = ref.read(authSessionProvider)?.id;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).updateFarmProfile(
            uid,
            about: _about.text,
            openingHours: _hours.text,
            categories:
                farmCategoryOptions.where(_categories.contains).toList(),
            coverUrl: _coverUrl,
            galleryUrls: _gallery,
          );
      if (!mounted) return;
      _snack('Farm profile saved.');
      context.pop();
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authSessionProvider.select((u) => u?.id)) ?? '';
    final profileAsync = ref.watch(farmProfileProvider(uid));
    final profile = profileAsync.valueOrNull;
    if (profile != null) _fill(profile);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = AppColors.subText(isDark);
    final busy = _saving || _uploading != null;

    return Scaffold(
      appBar: AppBar(
        title: const T('Farm profile'),
        actions: [
          TextButton(
            onPressed: uid.isEmpty ? null : () => context.push('/seller/$uid'),
            child: const T('Preview'),
          ),
        ],
      ),
      body: !_loaded && profileAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                T('Cover photo', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                T('A wide photo of your farm, field or animals.',
                    style: TextStyle(fontSize: 12, color: sub)),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Material(
                    color: AppColors.surface(isDark),
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: busy
                          ? null
                          : () async {
                              final url = await _pickAndUpload('cover');
                              if (url != null) setState(() => _coverUrl = url);
                            },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_coverUrl != null)
                            ProduceImage(url: _coverUrl!)
                          else
                            const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 40, color: AppColors.emerald),
                                SizedBox(height: 6),
                                T('Add a cover photo'),
                              ],
                            ),
                          if (_uploading == 'cover')
                            _UploadOverlay(progress: _progress),
                          if (_coverUrl != null && _uploading == null)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: IconButton.filledTonal(
                                tooltip: tr('Remove cover photo'),
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () =>
                                    setState(() => _coverUrl = null),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _about,
                  maxLength: 600,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: tr('About your farm'),
                    hintText: tr('e.g. A family farm in Gashua growing rice, '
                        'beans and pepper since 2010. We harvest twice a year.'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _hours,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: tr('Opening hours'),
                    hintText: tr('e.g. Mon – Sat, 7:00 AM – 6:00 PM'),
                    prefixIcon: const Icon(Icons.schedule_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                T('What you produce',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in farmCategoryOptions)
                      FilterChip(
                        avatar: Icon(categoryIcon(c), size: 18),
                        label: Text(tr(c)),
                        selected: _categories.contains(c),
                        onSelected: (on) => setState(() =>
                            on ? _categories.add(c) : _categories.remove(c)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    T('Farm gallery',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text('${_gallery.length} of $maxGalleryPhotos',
                        style: TextStyle(fontSize: 12, color: sub)),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (var i = 0; i < _gallery.length; i++)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ProduceImage(url: _gallery[i]),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              tooltip: tr('Remove photo'),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () =>
                                  setState(() => _gallery.removeAt(i)),
                            ),
                          ),
                        ],
                      ),
                    if (_gallery.length < maxGalleryPhotos)
                      Material(
                        color: AppColors.surface(isDark),
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: busy
                              ? null
                              : () async {
                                  final url = await _pickAndUpload('gallery');
                                  if (url != null) {
                                    setState(() => _gallery.add(url));
                                  }
                                },
                          child: _uploading == 'gallery'
                              ? _UploadOverlay(progress: _progress)
                              : const Icon(Icons.add_a_photo_outlined,
                                  color: AppColors.emerald),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: busy ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save farm profile'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black45,
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          value: progress > 0 ? progress : null,
          color: Colors.white,
        ),
      );
}
