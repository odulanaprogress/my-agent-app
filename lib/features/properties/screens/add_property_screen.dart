import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/cloudinary_service.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final locationController = TextEditingController();
  final contactController = TextEditingController();
  final whatsappController = TextEditingController();

  File? imageFile;
  Uint8List? webImage;
  String imageUrl = '';

  bool isLoading = false;

  List<String> amenities = [];
  final amenityController = TextEditingController();

  // 📷 PICK IMAGE
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => webImage = bytes);
      } else {
        setState(() => imageFile = File(picked.path));
      }
    }
  }

  // ☁️ UPLOAD IMAGE (Cloudinary)
  Future<void> uploadImage() async {
    final cloudinary = CloudinaryService();

    try {
      if (kIsWeb) {
        throw Exception('Web upload not supported in this build');
      }

      if (imageFile == null) {
        throw Exception('No image selected');
      }

      final url = await cloudinary.uploadImage(imageFile!);
      if (url == null) {
        throw Exception('Image upload failed');
      }

      imageUrl = url;
    } catch (e) {
      throw Exception("Image upload failed: $e");
    }
  }

  // 🚀 ADD PROPERTY
  Future<void> addProperty() async {
    if (titleController.text.isEmpty ||
        priceController.text.isEmpty ||
        locationController.text.isEmpty ||
        contactController.text.isEmpty ||
        whatsappController.text.isEmpty ||
        (imageFile == null && webImage == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill all fields + image')));
      return;
    }

    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      await uploadImage();
      if (!mounted) return;

      await FirebaseFirestore.instance.collection('properties').add({
        'title': titleController.text,
        'price': priceController.text,
        'location': locationController.text,
        'imageUrl': imageUrl,
        'contact': contactController.text,
        'whatsapp': whatsappController.text,
        'ownerId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'isPremium': false,
        'favorites': [],
        'amenities': amenities,
        'createdAt': Timestamp.now(),
      });
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property uploaded successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    locationController.dispose();
    contactController.dispose();
    whatsappController.dispose();
    amenityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Property')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 📸 IMAGE
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: webImage != null
                    ? Image.memory(webImage!, fit: BoxFit.cover)
                    : imageFile != null
                    ? Image.file(imageFile!, fit: BoxFit.cover)
                    : const Center(child: Text('Tap to select image')),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),

            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),

            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location (e.g. Lekki, Lagos)',
              ),
            ),

            TextField(
              controller: contactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact Number'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: whatsappController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp Number'),
            ),

            const SizedBox(height: 20),

            // 🏡 AMENITIES
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amenityController,
                    decoration: const InputDecoration(labelText: 'Add Amenity'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (amenityController.text.isNotEmpty) {
                      setState(() {
                        amenities.add(amenityController.text);
                        amenityController.clear();
                      });
                    }
                  },
                ),
              ],
            ),

            Wrap(
              spacing: 8,
              children: amenities
                  .map(
                    (e) => Chip(
                      label: Text(e),
                      onDeleted: () {
                        setState(() => amenities.remove(e));
                      },
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : addProperty,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Upload Property'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
