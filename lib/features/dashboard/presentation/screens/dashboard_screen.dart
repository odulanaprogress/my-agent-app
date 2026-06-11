import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';

import '../screens/favorites_tab_screen.dart';
import '../screens/profile_tab_screen.dart';
import '../../../properties/screens/add_property_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Welcome Back 👋',

                        style: TextStyle(
                          color: Colors.grey.shade600,

                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Agent',

                        style: TextStyle(
                          fontSize: 28,

                          fontWeight: FontWeight.bold,

                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,

                          borderRadius: BorderRadius.circular(16),
                        ),

                        child: IconButton(
                          onPressed: () {},

                          icon: const Icon(Icons.notifications_none_rounded),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,

                          borderRadius: BorderRadius.circular(16),
                        ),

                        child: IconButton(
                          onPressed: () async {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .logout();
                            if (!context.mounted) return;
                            context.go('/login');
                          },

                          icon: const Icon(Icons.logout, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(20),
                ),

                child: const TextField(
                  decoration: InputDecoration(
                    border: InputBorder.none,

                    hintText: 'Search properties...',

                    icon: Icon(Icons.search),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  ),

                  borderRadius: BorderRadius.circular(30),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Find Your Dream Property',

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 28,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Explore luxury homes, apartments, and modern properties with Agent.',

                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),

                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 25),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,

                        foregroundColor: AppColors.primary,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      onPressed: () {},

                      child: const Text('Explore Now'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: const [
                  Text(
                    'Featured Properties',

                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  Text(
                    'See All',

                    style: TextStyle(
                      color: AppColors.primary,

                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              _propertyCard(
                image:
                    'https://images.unsplash.com/photo-1568605114967-8130f3a36994',

                title: 'Modern Family House',

                location: 'Lekki, Lagos',

                price: '₦250,000,000',
              ),

              _propertyCard(
                image:
                    'https://images.unsplash.com/photo-1570129477492-45c003edd2be',

                title: 'Luxury Apartment',

                location: 'Victoria Island',

                price: '₦180,000,000',
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,

        selectedItemColor: AppColors.primary,

        unselectedItemColor: Colors.grey,

        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          setState(() => currentIndex = index);

          // Project functionality for dashboard navigation.
          // 0: Home, 1: Favorites, 2: Upload, 3: Profile
          switch (index) {
            case 0:
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => DashboardScreen()),
              );
              break;
            case 1:
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const FavoritesTabScreen()),
              );
              break;
            case 2:
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
              );
              break;
            case 3:
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ProfileTabScreen()),
              );
              break;
          }
        },

        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),

          if (ref.watch(currentUserProvider)?.isLandlord ?? false)
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: 'Upload',
            ),

          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _propertyCard({
    required String image,
    required String title,
    required String location,
    required String price,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(28),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),

            blurRadius: 25,

            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),

                child: Image.network(
                  image,

                  width: double.infinity,

                  height: 220,

                  fit: BoxFit.cover,
                ),
              ),

              Positioned(
                right: 18,
                top: 18,

                child: Container(
                  padding: const EdgeInsets.all(10),

                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),

                  child: const Icon(Icons.favorite_border),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(
                    fontSize: 22,

                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      Icons.location_on,

                      color: Colors.grey.shade600,

                      size: 18,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      location,

                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    Text(
                      price,

                      style: const TextStyle(
                        color: AppColors.primary,

                        fontWeight: FontWeight.bold,

                        fontSize: 20,
                      ),
                    ),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      onPressed: () {},

                      child: const Text(
                        'View',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
