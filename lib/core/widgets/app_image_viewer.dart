import 'package:flutter/material.dart';

class AppImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const AppImageViewer({
    super.key,
    required this.imageUrl,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? title,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, anim1, anim2) => AppImageViewer(
          imageUrl: imageUrl,
          title: title,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title ?? 'Photo',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6366F1),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Could not load image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
