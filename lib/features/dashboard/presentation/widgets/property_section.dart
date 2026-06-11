import 'package:flutter/material.dart';

import 'property_card.dart';

class PropertySection extends StatelessWidget {
  const PropertySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Featured Properties',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('See All')),
          ],
        ),
        const SizedBox(height: 20),
        const PropertyCard(
          image: 'https://images.unsplash.com/photo-1568605114967-8130f3a36994',
          title: 'Modern Family House',
          location: 'Lekki, Lagos',
          price: '₦250,000,000',
        ),
        const SizedBox(height: 24),
        const PropertyCard(
          image: 'https://images.unsplash.com/photo-1570129477492-45c003edd2be',
          title: 'Luxury Apartment',
          location: 'Victoria Island, Lagos',
          price: '₦180,000,000',
        ),
      ],
    );
  }
}
