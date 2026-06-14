import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/di/upload_providers.dart';
import '../../shared/widgets/gradient_button.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const _kCategories = [
  'Grains',
  'Vegetables',
  'Fruits',
  'Livestock',
  'Oilseeds',
];

const _kNigerianStates = [
  'Abia',
  'Adamawa',
  'Akwa Ibom',
  'Anambra',
  'Bauchi',
  'Bayelsa',
  'Benue',
  'Borno',
  'Cross River',
  'Delta',
  'Ebonyi',
  'Edo',
  'Ekiti',
  'Enugu',
  'FCT — Abuja',
  'Gombe',
  'Imo',
  'Jigawa',
  'Kaduna',
  'Kano',
  'Katsina',
  'Kebbi',
  'Kogi',
  'Kwara',
  'Lagos',
  'Nasarawa',
  'Niger',
  'Ogun',
  'Ondo',
  'Osun',
  'Oyo',
  'Plateau',
  'Rivers',
  'Sokoto',
  'Taraba',
  'Yobe',
  'Zamfara',
];

enum _Availability { inStock, limited, preOrder }

// ─── Card decoration helper ───────────────────────────────────────────────────

BoxDecoration _card(bool isDark) => BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? const Color(0xFF2E3C2E) : const Color(0xFFE2EAE0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // state
  String? _imagePath;
  String? _uploadedImageUrl;
  double? _uploadProgress;
  String? _selectedCategory;
  String? _selectedState;
  _Availability _availability = _Availability.inStock;
  bool _busy = false;
  bool _locating = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  // ─── Image picker ─────────────────────────────────────────────────────────

  void _showImageSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.deepGreen),
                title: Text(
                  'Take a photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.deepGreen),
                title: Text(
                  'Choose from gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_imagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.errorRed),
                  title: Text(
                    'Remove photo',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: AppColors.errorRed,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _imagePath = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file =
          await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (file != null) {
        setState(() {
          _imagePath = file.path;
          _uploadedImageUrl = null;
          _uploadProgress = null;
        });
        _startUpload(file.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access camera/gallery.')),
        );
      }
    }
  }

  // ─── Image upload ─────────────────────────────────────────────────────────

  void _startUpload(String path) {
    setState(() => _uploadProgress = 0.0);

    ref
        .read(imageUploadServiceProvider)
        .uploadProductImage(
          filePath: path,
          productId: 'listing-${path.hashCode.abs()}',
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        )
        .then((url) {
          if (mounted) {
            setState(() {
              _uploadedImageUrl = url;
              _uploadProgress = null;
            });
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() => _uploadProgress = null);
            _showSnack('Image upload failed. Please try again.');
          }
        });
  }

  // ─── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _useGps() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied. Enable in settings.');
        return;
      }
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      // In production: reverse-geocode to fill state/city fields.
      _showSnack('GPS location detected. Fill city manually for accuracy.',
          success: true);
    } catch (e) {
      _showSnack('Could not get location. Try again.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_uploadProgress != null) {
      _showSnack('Please wait for the image to finish uploading.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    try {
      final session = ref.read(authSessionProvider);
      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'priceNgn': int.parse(_priceCtrl.text.trim()),
        'quantityKg': int.parse(_qtyCtrl.text.trim()),
        'state': _selectedState ?? '',
        'city': _cityCtrl.text.trim(),
        'sellerId': session?.id ?? 'unknown',
        'sellerName': session?.name ?? 'Farmer',
        'sellerRating': session?.rating ?? 5.0,
        'verified': session?.verified ?? false,
        'availability': switch (_availability) {
          _Availability.limited => 'limited',
          _Availability.preOrder => 'pre_order',
          _Availability.inStock => 'in_stock',
        },
        'imageUrl': _uploadedImageUrl ??
            'https://picsum.photos/seed/${_titleCtrl.text.hashCode}/400/300',
        'lat': 0.0,
        'lng': 0.0,
      };

      await ref.read(productRepositoryProvider).addListing(data);
      ref.invalidate(productsProvider);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.freshGreen, size: 20),
              const SizedBox(width: 10),
              Text(
                'Listing published!',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B5E20),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (mounted) _showSnack('Failed to publish listing. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: success ? AppColors.deepGreen : AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.softWhite;
    final textPrimary = AppColors.text(isDark);
    final textSub = AppColors.subText(isDark);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
        title: Text(
          'New Listing',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // [1] Image picker
              _ImagePickerCard(
                isDark: isDark,
                imagePath: _imagePath,
                onTap: _uploadProgress != null ? null : _showImageSheet,
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.04, duration: 300.ms),

              // Upload progress / success indicator
              if (_uploadProgress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    color: AppColors.deepGreen,
                    backgroundColor:
                        AppColors.deepGreen.withValues(alpha: 0.12),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Uploading ${((_uploadProgress!) * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.deepGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ] else if (_uploadedImageUrl != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 14, color: AppColors.mintGreen),
                    const SizedBox(width: 5),
                    Text(
                      'Image uploaded successfully',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.mintGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // [2] Listing details
              _SectionLabel(
                      label: 'Listing Details',
                      icon: Icons.edit_note_rounded,
                      isDark: isDark)
                  .animate(delay: 50.ms)
                  .fadeIn()
                  .slideY(begin: 0.04),

              const SizedBox(height: 8),

              Container(
                decoration: _card(isDark),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTextFormField(
                      controller: _titleCtrl,
                      label: 'Product Title',
                      hint: 'e.g. Fresh White Maize — Kano 2024',
                      isDark: isDark,
                      maxLength: 80,
                      validator: (v) =>
                          (v == null || v.trim().length < 4)
                              ? 'Enter a descriptive title (min 4 chars)'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    _buildCategoryDropdown(isDark, textPrimary, textSub),
                    const SizedBox(height: 14),
                    _buildTextFormField(
                      controller: _descCtrl,
                      label: 'Description',
                      hint: 'Describe quality, harvest date, storage…',
                      isDark: isDark,
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().length < 10)
                              ? 'Add a description (min 10 chars)'
                              : null,
                    ),
                  ],
                ),
              )
                  .animate(delay: 80.ms)
                  .fadeIn()
                  .slideY(begin: 0.04),

              const SizedBox(height: 20),

              // [3] Pricing & Quantity
              _SectionLabel(
                      label: 'Pricing & Quantity',
                      icon: Icons.sell_outlined,
                      isDark: isDark)
                  .animate(delay: 110.ms)
                  .fadeIn()
                  .slideY(begin: 0.04),

              const SizedBox(height: 8),

              Container(
                decoration: _card(isDark),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: _priceCtrl,
                            label: 'Price (NGN)',
                            hint: '0.00',
                            isDark: isDark,
                            prefixText: '₦ ',
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter price';
                              }
                              final parsed = double.tryParse(v.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Enter a valid price';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextFormField(
                            controller: _qtyCtrl,
                            label: 'Quantity',
                            hint: '0',
                            isDark: isDark,
                            suffixText: ' kg',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter quantity';
                              }
                              final parsed = int.tryParse(v.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Must be > 0';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _AvailabilitySegment(
                      selected: _availability,
                      isDark: isDark,
                      onChanged: (val) => setState(() => _availability = val),
                    ),
                  ],
                ),
              )
                  .animate(delay: 140.ms)
                  .fadeIn()
                  .slideY(begin: 0.04),

              const SizedBox(height: 20),

              // [4] Location
              _SectionLabel(
                      label: 'Location',
                      icon: Icons.location_on_outlined,
                      isDark: isDark)
                  .animate(delay: 170.ms)
                  .fadeIn()
                  .slideY(begin: 0.04),

              const SizedBox(height: 8),

              Container(
                decoration: _card(isDark),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStateDropdown(isDark, textPrimary, textSub),
                    const SizedBox(height: 14),
                    _buildTextFormField(
                      controller: _cityCtrl,
                      label: 'City / LGA',
                      hint: 'e.g. Ikeja, Nassarawa, Ungwa Rimi',
                      isDark: isDark,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter city or LGA' : null,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.deepGreen,
                                ),
                              )
                            : const Icon(Icons.my_location_outlined,
                                color: AppColors.deepGreen),
                        label: Text(
                          _locating ? 'Detecting…' : 'Use GPS Location',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepGreen,
                          ),
                        ),
                        onPressed: _locating ? null : _useGps,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.deepGreen),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: 200.ms)
                  .fadeIn()
                  .slideY(begin: 0.04),

              const SizedBox(height: 28),

              // [5] Submit
              PrimaryGradientButton(
                label: _busy
                    ? 'Publishing…'
                    : _uploadProgress != null
                        ? 'Uploading image…'
                        : 'Publish Listing',
                icon: (_busy || _uploadProgress != null)
                    ? null
                    : Icons.check_circle_outline_rounded,
                onPressed: (_busy || _uploadProgress != null) ? null : _submit,
              ).animate(delay: 230.ms).fadeIn().slideY(begin: 0.04),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: AppColors.gray,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Your listing will be reviewed within 2 hours',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.gray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ).animate(delay: 250.ms).fadeIn(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Form field builders ──────────────────────────────────────────────────

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    int? maxLength,
    String? prefixText,
    String? suffixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final borderColor =
        isDark ? const Color(0xFF2E3C2E) : const Color(0xFFE2EAE0);
    final focusColor = AppColors.deepGreen;
    final fillColor = isDark ? const Color(0xFF121212) : AppColors.surfaceLight;
    final textColor = AppColors.text(isDark);
    final hintColor = AppColors.subText(isDark);

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.poppins(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: hintColor),
        labelStyle:
            GoogleFonts.poppins(fontSize: 13, color: hintColor),
        prefixText: prefixText,
        suffixText: suffixText,
        filled: true,
        fillColor: fillColor,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: focusColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.errorRed, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.errorRed, width: 1.8),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildCategoryDropdown(
      bool isDark, Color textPrimary, Color textSub) {
    final borderColor =
        isDark ? const Color(0xFF2E3C2E) : const Color(0xFFE2EAE0);
    final fillColor = isDark ? const Color(0xFF121212) : AppColors.surfaceLight;

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      hint: Text(
        'Select category',
        style: GoogleFonts.poppins(fontSize: 13, color: textSub),
      ),
      items: _kCategories
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(
                  c,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: textPrimary),
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedCategory = v),
      validator: (v) =>
          v == null ? 'Please select a category' : null,
      style: GoogleFonts.poppins(fontSize: 14, color: textPrimary),
      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle:
            GoogleFonts.poppins(fontSize: 13, color: textSub),
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.deepGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.errorRed, width: 1.4),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.gray),
    );
  }

  Widget _buildStateDropdown(
      bool isDark, Color textPrimary, Color textSub) {
    final borderColor =
        isDark ? const Color(0xFF2E3C2E) : const Color(0xFFE2EAE0);
    final fillColor = isDark ? const Color(0xFF121212) : AppColors.surfaceLight;

    return DropdownButtonFormField<String>(
      initialValue: _selectedState,
      hint: Text(
        'Select state',
        style: GoogleFonts.poppins(fontSize: 13, color: textSub),
      ),
      items: _kNigerianStates
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: textPrimary),
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedState = v),
      validator: (v) => v == null ? 'Please select a state' : null,
      style: GoogleFonts.poppins(fontSize: 14, color: textPrimary),
      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      decoration: InputDecoration(
        labelText: 'State',
        labelStyle:
            GoogleFonts.poppins(fontSize: 13, color: textSub),
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.deepGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.errorRed, width: 1.4),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.gray),
    );
  }
}

// ─── _ImagePickerCard ─────────────────────────────────────────────────────────

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.isDark,
    required this.imagePath,
    required this.onTap,
  });

  final bool isDark;
  final String? imagePath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2A1A) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.deepGreen,
            width: 2,
            // Dashed border via custom painter fallback — use a CustomPainter for dashes
          ),
        ),
        child: imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                    ),
                    // Edit overlay
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Change',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _DashedEmptyPicker(isDark: isDark),
      ),
    );
  }
}

class _DashedEmptyPicker extends StatelessWidget {
  const _DashedEmptyPicker({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashBorderPainter(isDark: isDark),
      child: SizedBox(
        width: double.infinity,
        height: 160,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: AppColors.deepGreen,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to add photos',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'JPEG / PNG  •  max 5 MB',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashBorderPainter extends CustomPainter {
  const _DashBorderPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.deepGreen.withValues(alpha: isDark ? 0.7 : 0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashGap = 5.0;
    const radius = 12.0;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final start = dist;
        final end = (dist + dashWidth).clamp(0.0, metric.length);
        dashPath.addPath(metric.extractPath(start, end), Offset.zero);
        dist += dashWidth + dashGap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(_DashBorderPainter old) => old.isDark != isDark;
}

// ─── _AvailabilitySegment ─────────────────────────────────────────────────────

class _AvailabilitySegment extends StatelessWidget {
  const _AvailabilitySegment({
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  final _Availability selected;
  final bool isDark;
  final ValueChanged<_Availability> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.subText(isDark),
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_Availability>(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.deepGreen,
            selectedForegroundColor: Colors.white,
            foregroundColor: AppColors.subText(isDark),
            backgroundColor:
                isDark ? const Color(0xFF121212) : AppColors.surfaceLight,
            side: BorderSide(
              color: isDark
                  ? const Color(0xFF2E3C2E)
                  : const Color(0xFFE2EAE0),
            ),
            textStyle: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          showSelectedIcon: false,
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
          segments: const [
            ButtonSegment(
              value: _Availability.inStock,
              label: Text('In Stock'),
              icon: Icon(Icons.check_circle_outline, size: 15),
            ),
            ButtonSegment(
              value: _Availability.limited,
              label: Text('Limited'),
              icon: Icon(Icons.warning_amber_outlined, size: 15),
            ),
            ButtonSegment(
              value: _Availability.preOrder,
              label: Text('Pre-order'),
              icon: Icon(Icons.schedule_outlined, size: 15),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── _SectionLabel ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.icon,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.deepGreen),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
