import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/property_card.dart';

import 'property_details_screen.dart';

import '../models/property_model.dart';

class PropertyScreen extends StatefulWidget {
  const PropertyScreen({super.key});

  @override
  State<PropertyScreen> createState() => _PropertyScreenState();
}

class _PropertyScreenState extends State<PropertyScreen> {
  String searchQuery = '';

  PropertyModel propertyFromDoc(Map<String, dynamic> data, String id) {
    // Map Firestore fields -> PropertyModel.
    // Supports both legacy and current schema.

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    DateTime parseDateTime(dynamic v) {
      if (v == null) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final imageUrls =
        (data['imageUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        (data['imageUrl'] != null
            ? [data['imageUrl'].toString()]
            : (data['image'] != null
                  ? [data['image'].toString()]
                  : <String>[]));

    return PropertyModel(
      id: id,
      ownerId: (data['ownerId'] ?? '').toString(),
      ownerName: (data['ownerName'] ?? '').toString(),

      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      price: (data['price'] ?? 0) as num,

      category: (data['category'] ?? '').toString(),
      state: (data['state'] ?? '').toString(),
      lga: (data['lga'] ?? '').toString(),
      community: (data['community'] ?? '').toString(),
      address: (data['address'] ?? data['location'] ?? '').toString(),

      amenities:
          (data['amenities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      imageUrls: imageUrls,
      videoUrls: (data['videoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      contactPhone: (data['contactPhone'] ?? '').toString(),
      whatsappNumber: (data['whatsappNumber'] ?? '').toString(),

      approvalStatus: (data['approvalStatus'] ?? 'pending').toString(),
      isApproved:
          (data['isApproved'] ?? false) == true || data['isApproved'] == 1,

      viewsCount: parseInt(data['viewsCount'] ?? 0),
      favoritesCount: parseInt(data['favoritesCount'] ?? 0),
      inquiriesCount: parseInt(data['inquiriesCount'] ?? 0),

      createdAt: parseDateTime(data['createdAt']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(title: Text('Properties', style: AppTextStyles.heading3)),

      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),

            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },

              decoration: InputDecoration(
                hintText: 'Search properties or locations...',

                prefixIcon: const Icon(Icons.search),

                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),

                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: const Icon(Icons.tune, color: Colors.white),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // PROPERTY LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('properties')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),

              builder: (context, snapshot) {
                // LOADING
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ERROR
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),

                      child: Text(
                        'Something went wrong.\nPlease try again.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  );
                }

                // EMPTY
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 90,
                            color: Colors.grey.shade400,
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'No Properties Found',
                            style: AppTextStyles.heading3,
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'Properties added to Firebase will appear here.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final properties = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final title = (data['title'] ?? '').toString().toLowerCase();

                  final location = (data['location'] ?? '')
                      .toString()
                      .toLowerCase();

                  return title.contains(searchQuery) ||
                      location.contains(searchQuery);
                }).toList();

                // SEARCH EMPTY
                if (properties.isEmpty) {
                  return Center(
                    child: Text(
                      'No matching properties found.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),

                  itemCount: properties.length,

                  itemBuilder: (context, index) {
                    final doc = properties[index];

                    final data = doc.data() as Map<String, dynamic>;

                    return PropertyCard(
                      image: (data['imageUrl'] ?? data['image'] ?? ''),
                      title: data['title'] ?? 'Untitled',
                      location: data['location'] ?? 'Unknown Location',

                      price: '₦${data['price'] ?? '0'}',

                      bedrooms: '${data['bedrooms'] ?? '0'} Beds',

                      bathrooms: '${data['bathrooms'] ?? '0'} Baths',

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertyDetailsScreen(
                              property: propertyFromDoc(data, doc.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
