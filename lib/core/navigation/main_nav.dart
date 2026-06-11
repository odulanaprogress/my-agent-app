import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/properties/screens/add_property_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int currentIndex = 0;

  final List<Widget> screens = [
    const HomeScreen(),
    const FavoritesScreen(),
    const AddPropertyScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        type: BottomNavigationBarType.fixed,

        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,

        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'Home'),

          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite),

            label: 'Favorites',
          ),

          const BottomNavigationBarItem(
            icon: Icon(Icons.add_business),

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
}
