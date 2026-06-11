import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.location.status;
    if (status.isGranted) return true;

    // Show request explanation dialog
    if (context.mounted) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.location_on_outlined, color: Color(0xFF6366F1)),
              SizedBox(width: 10),
              Text('Location Permission'),
            ],
          ),
          content: const Text(
            'AGENT needs access to your device location to show listings near you and verify property coordinates.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Deny', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Allow'),
            ),
          ],
        ),
      );

      if (proceed != true) return false;
    }

    final result = await Permission.location.request();
    return result.isGranted;
  }

  static Future<bool> requestStoragePermission(BuildContext context) async {
    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    if (context.mounted) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.storage_outlined, color: Color(0xFF6366F1)),
              SizedBox(width: 10),
              Text('Storage Permission'),
            ],
          ),
          content: const Text(
            'AGENT needs access to your device storage to save agreements, download PDFs, and cache property photos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Deny', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Allow'),
            ),
          ],
        ),
      );

      if (proceed != true) return false;
    }

    final result = await Permission.storage.request();
    return result.isGranted;
  }
}
