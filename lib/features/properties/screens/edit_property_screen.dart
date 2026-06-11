import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/cloudinary_service.dart';
import '../models/property_model.dart';

class EditPropertyScreen extends StatefulWidget {
  final PropertyModel property;
  const EditPropertyScreen({super.key, required this.property});

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final ImagePicker picker = ImagePicker();

  late final titleController = TextEditingController(text: widget.property.title);
  late final descriptionController = TextEditingController(text: widget.property.description);
  late final priceController = TextEditingController(text: widget.property.price.toStringAsFixed(0));
  late final addressController = TextEditingController(text: widget.property.address);
  late final lgaController = TextEditingController(text: widget.property.lga);
  late final communityController = TextEditingController(text: widget.property.community);
  late final phoneController = TextEditingController(text: widget.property.contactPhone);
  late final whatsappController = TextEditingController(text: widget.property.whatsappNumber);

  late String category = widget.property.category;
  late String state = widget.property.state;

  // Existing URLs (from Firestore)
  late List<String> existingImageUrls = List.from(widget.property.imageUrls);

  // Newly picked files
  List<File> newImages = [];
  File? newVideo;
  bool isLoading = false;

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
  late final Set<String> _selectedAmenities = Set.from(widget.property.amenities);

  Future<void> _pickMoreImages() async {
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty) {
      setState(() {
        newImages = images.map((e) => File(e.path)).toList();
      });
    }
  }

  Future<void> _pickVideo() async {
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => newVideo = File(video.path));
    }
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty || priceController.text.trim().isEmpty) {
      _snack('Title and price are required.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final List<String> finalImageUrls = List.from(existingImageUrls);
      final List<String> finalVideoUrls = List.from(widget.property.videoUrls);

      // Upload new images
      for (final image in newImages) {
        final imageUrl = await CloudinaryService().uploadImage(image);
        if (imageUrl != null) finalImageUrls.add(imageUrl);
      }

      // Upload new video if picked
      if (newVideo != null) {
        final videoUrl = await CloudinaryService().uploadVideo(newVideo!);
        if (videoUrl != null) {
          finalVideoUrls.clear();
          finalVideoUrls.add(videoUrl);
        }
      }

      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.property.id)
          .update({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'price': double.tryParse(priceController.text.trim()) ?? widget.property.price,
        'category': category,
        'state': state,
        'lga': lgaController.text.trim(),
        'community': communityController.text.trim(),
        'address': addressController.text.trim(),
        'amenities': _selectedAmenities.toList(),
        'imageUrls': finalImageUrls,
        'videoUrls': finalVideoUrls,
        'contactPhone': phoneController.text.trim(),
        'whatsappNumber': whatsappController.text.trim(),
        'approvalStatus': 'pending',
        'isApproved': false,
      });

      setState(() => isLoading = false);
      if (!mounted) return;
      _snack('Property updated! Awaiting re-approval.', success: true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) context.pop();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) _snack('Update failed: $e');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Property',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: isLoading ? null : _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Approval notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Editing will reset approval status to "pending".',
                      style: TextStyle(color: Colors.amber.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Existing Photos ─────────────────────────────────────────
            _sectionTitle('📸 Current Photos'),
            if (existingImageUrls.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: existingImageUrls.length,
                  itemBuilder: (context, i) => Stack(
                    children: [
                      Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(existingImageUrls[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => setState(() => existingImageUrls.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickMoreImages,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFEEF2FF),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Text(
                      newImages.isEmpty ? 'Add / Replace Photos' : '${newImages.length} new photo(s) selected',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Video ─────────────────────────────────────────────────
            _sectionTitle('🎬 Video Tour (Optional)'),
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: newVideo == null ? Colors.white : const Color(0xFFF0FDF4),
                  border: Border.all(
                    color: newVideo == null
                        ? Colors.grey.shade200
                        : const Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      newVideo == null ? Icons.video_library_outlined : Icons.check_circle_rounded,
                      color: newVideo == null ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      newVideo == null
                          ? (widget.property.videoUrls.isNotEmpty ? 'Replace Video Tour' : 'Add Video Tour')
                          : 'New video selected ✓',
                      style: TextStyle(
                        color: newVideo == null ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Basic Info ──────────────────────────────────────────────
            _sectionTitle('🏠 Property Details'),
            TextField(
              controller: titleController,
              decoration: _inputDec('Property Title', icon: Icons.home),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: _inputDec('Description', icon: Icons.description_outlined),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDec('Price (₦)', icon: Icons.payments_outlined),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: _inputDec('Category', icon: Icons.category_outlined),
              items: [
                'Apartment', 'House', 'Duplex', 'Villa',
                'Office', 'Land', 'Shop / Commercial', 'Short Let',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => category = v!),
            ),

            const SizedBox(height: 24),

            // ── Location ────────────────────────────────────────────────
            _sectionTitle('📍 Location'),
            DropdownButtonFormField<String>(
              initialValue: state,
              decoration: _inputDec('State', icon: Icons.map_outlined),
              isExpanded: true,
              items: [
                'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa',
                'Benue', 'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo',
                'Ekiti', 'Enugu', 'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano',
                'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos', 'Nasarawa',
                'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers',
                'Sokoto', 'Taraba', 'Yobe', 'Zamfara', 'FCT',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => state = v!),
            ),
            const SizedBox(height: 14),
            TextField(controller: lgaController, decoration: _inputDec('LGA', icon: Icons.location_city)),
            const SizedBox(height: 14),
            TextField(controller: communityController, decoration: _inputDec('Community / Estate', icon: Icons.holiday_village_outlined)),
            const SizedBox(height: 14),
            TextField(controller: addressController, decoration: _inputDec('Full Address', icon: Icons.place_outlined)),

            const SizedBox(height: 24),

            // ── Amenities ───────────────────────────────────────────────
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
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? const Color(0xFF6366F1) : Colors.grey.shade700,
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
                    selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    checkmarkColor: const Color(0xFF6366F1),
                    backgroundColor: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

            // ── Contact ─────────────────────────────────────────────────
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
              decoration: _inputDec('WhatsApp Number', icon: Icons.chat),
            ),

            const SizedBox(height: 32),

            // ── Save Button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_outlined, size: 22),
                          SizedBox(width: 10),
                          Text('Save Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
