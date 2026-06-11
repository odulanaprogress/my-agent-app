import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/property_repository.dart';
import '../../../core/services/access_control_service.dart';

class UploadPropertyScreen extends StatefulWidget {
  const UploadPropertyScreen({super.key});

  @override
  State<UploadPropertyScreen> createState() => _UploadPropertyScreenState();
}

class _UploadPropertyScreenState extends State<UploadPropertyScreen> {
  final PropertyRepository repository = PropertyRepository();
  final AccessControlService accessControlService = AccessControlService();
  final ImagePicker picker = ImagePicker();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final addressController = TextEditingController();
  final lgaController = TextEditingController();
  final communityController = TextEditingController();
  final phoneController = TextEditingController();
  final whatsappController = TextEditingController();

  String category = 'Apartment';
  String state = 'Lagos';
  String listingType = 'Rent'; // Sell, Rent, Lease, Shortlet
  String rentalDurationUnit = 'Months'; // Hours, Days, Weeks, Months, Years
  final durationController = TextEditingController(text: '12');

  List<File> selectedImages = [];
  File? selectedVideo;
  bool isLoading = false;

  // ── Amenities ───────────────────────────────────────────────────────────
  final List<String> _allAmenities = [
    'Swimming Pool',
    'Gym / Fitness Center',
    'Security / CCTV',
    '24h Electricity',
    'Borehole / Water',
    'Boys Quarters (BQ)',
    'Parking Space',
    'Air Conditioning',
    'Furnished',
    'Generator',
    'Smart Home',
    'Garden / Lawn',
    'Balcony',
    'Elevator / Lift',
    'Internet / Wi-Fi',
    'Gate House',
  ];
  final Set<String> _selectedAmenities = {};

  // ── Media pickers ────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty) {
      setState(() {
        selectedImages = images.map((e) => File(e.path)).toList();
      });
    }
  }

  Future<void> _pickVideo() async {
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => selectedVideo = File(video.path));
    }
  }

  // ── Upload ───────────────────────────────────────────────────────────────
  Future<void> _upload() async {
    final isOwner = await accessControlService.isPropertyOwner();
    if (!isOwner) {
      if (!mounted) return;
      _snack('Only property owners can upload properties.');
      return;
    }

    if (titleController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty) {
      _snack('Title and price are required.');
      return;
    }

    if (selectedImages.isEmpty) {
      _snack('Please select at least one property image.');
      return;
    }

    setState(() => isLoading = true);

    final String typeVal = listingType.toLowerCase().replaceAll(' ', '');
    final String? unitVal = typeVal == 'sell' ? null : rentalDurationUnit.toLowerCase();
    final int? valueVal = typeVal == 'sell' ? null : (int.tryParse(durationController.text.trim()) ?? 1);

    final error = await repository.uploadProperty(
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      price: double.tryParse(priceController.text.trim()) ?? 0,
      category: category,
      state: state,
      lga: lgaController.text.trim(),
      community: communityController.text.trim(),
      address: addressController.text.trim(),
      amenities: _selectedAmenities.toList(),
      images: selectedImages,
      videoFile: selectedVideo,
      contactPhone: phoneController.text.trim(),
      whatsappNumber: whatsappController.text.trim(),
      listingType: typeVal,
      rentalDurationUnit: unitVal,
      rentalDurationValue: valueVal,
    );

    setState(() => isLoading = false);
    if (!mounted) return;

    if (error == null) {
      _snack('Property uploaded successfully! ✅', success: true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) context.pop();
      });
    } else {
      _snack('Upload failed: $error');
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Widgets ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    addressController.dispose();
    lgaController.dispose();
    communityController.dispose();
    phoneController.dispose();
    whatsappController.dispose();
    durationController.dispose();
    super.dispose();
  }

  InputDecoration _inputDec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: const Color(0xFF6366F1)) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text(
          'List Your Property',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Images section ──────────────────────────────────────────
            _sectionTitle('📸 Property Photos'),
            GestureDetector(
              onTap: _pickImages,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: selectedImages.isEmpty ? 140 : 170,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFFEEF2FF),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: selectedImages.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined,
                              size: 42, color: Color(0xFF6366F1)),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap to add photos',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You can select multiple images',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(10),
                            itemCount: selectedImages.length + 1,
                            itemBuilder: (context, i) {
                              if (i == selectedImages.length) {
                                return GestureDetector(
                                  onTap: _pickImages,
                                  child: Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFF6366F1)
                                              .withValues(alpha: 0.5)),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add,
                                            color: Color(0xFF6366F1)),
                                        SizedBox(height: 4),
                                        Text(
                                          'Add more',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6366F1)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 130,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: FileImage(selectedImages[i]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(
                                            () => selectedImages.removeAt(i));
                                      },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(3),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          Positioned(
                            bottom: 6,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${selectedImages.length} photo${selectedImages.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Video section ───────────────────────────────────────────
            _sectionTitle('🎬 Property Video (Optional)'),
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selectedVideo == null
                      ? Colors.white
                      : const Color(0xFFF0FDF4),
                  border: Border.all(
                    color: selectedVideo == null
                        ? Colors.grey.shade200
                        : const Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selectedVideo == null
                          ? Icons.video_library_outlined
                          : Icons.check_circle_rounded,
                      color: selectedVideo == null
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      selectedVideo == null
                          ? 'Tap to add a video tour'
                          : 'Video selected ✓  (tap to change)',
                      style: TextStyle(
                        color: selectedVideo == null
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (selectedVideo != null) ...[
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.grey),
                        onPressed: () => setState(() => selectedVideo = null),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Basic Info ─────────────────────────────────────────────
            _sectionTitle('🏠 Property Details'),
            TextField(
                controller: titleController,
                decoration: _inputDec('Property Title', icon: Icons.home)),
            const SizedBox(height: 14),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: _inputDec('Description (features, unique points…)',
                  icon: Icons.description_outlined),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDec('Price (₦)', icon: Icons.payments_outlined),
            ),
            const SizedBox(height: 14),

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: _inputDec('Category', icon: Icons.category_outlined),
              items: [
                'Apartment',
                'House',
                'Duplex',
                'Villa',
                'Office',
                'Land',
                'Shop / Commercial',
                'Short Let',
              ]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: listingType,
              decoration: _inputDec('Listing Option', icon: Icons.sell_outlined),
              items: ['Sell', 'Rent', 'Lease', 'Shortlet']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => listingType = v!),
            ),
            if (listingType != 'Sell') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: rentalDurationUnit,
                      decoration: _inputDec('Duration Unit', icon: Icons.timer_outlined),
                      items: ['Hours', 'Days', 'Weeks', 'Months', 'Years']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => rentalDurationUnit = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDec('Value'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── Location ───────────────────────────────────────────────
            _sectionTitle('📍 Location'),
            DropdownButtonFormField<String>(
              initialValue: state,
              decoration: _inputDec('State', icon: Icons.map_outlined),
              isExpanded: true,
              items: [
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
                'FCT',
              ]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => state = v!),
            ),
            const SizedBox(height: 14),
            TextField(
                controller: lgaController,
                decoration: _inputDec('LGA', icon: Icons.location_city)),
            const SizedBox(height: 14),
            TextField(
                controller: communityController,
                decoration: _inputDec('Community / Estate',
                    icon: Icons.holiday_village_outlined)),
            const SizedBox(height: 14),
            TextField(
                controller: addressController,
                decoration:
                    _inputDec('Full Address', icon: Icons.place_outlined)),

            const SizedBox(height: 24),

            // ── Amenities ──────────────────────────────────────────────
            _sectionTitle('✅ Amenities'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _allAmenities.map((amenity) {
                  final selected = _selectedAmenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected
                              ? const Color(0xFF6366F1)
                              : Colors.grey.shade700,
                        )),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedAmenities.add(amenity);
                        } else {
                          _selectedAmenities.remove(amenity);
                        }
                      });
                    },
                    selectedColor:
                        const Color(0xFF6366F1).withValues(alpha: 0.12),
                    checkmarkColor: const Color(0xFF6366F1),
                    backgroundColor: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(
                        color: selected
                            ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                            : Colors.grey.shade200),
                    showCheckmark: true,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // ── Contact Info ───────────────────────────────────────────
            _sectionTitle('📞 Contact Information'),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDec('Phone Number', icon: Icons.phone_outlined),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: whatsappController,
              keyboardType: TextInputType.phone,
              decoration:
                  _inputDec('WhatsApp Number', icon: Icons.chat),
            ),

            const SizedBox(height: 32),

            // ── Upload Button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: isLoading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF6366F1).withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Publish Property',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
