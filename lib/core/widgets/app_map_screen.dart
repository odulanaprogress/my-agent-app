import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:agent_app/core/widgets/app_loader.dart';
import 'package:agent_app/core/services/permission_service.dart';

/// Full-screen in-app Google Maps viewer with interactive touch controls.
class AppMapScreen extends StatefulWidget {
  final String locationQuery;
  final String? title;

  const AppMapScreen({
    super.key,
    required this.locationQuery,
    this.title,
  });

  /// Launch the in-app map screen from anywhere in the app
  static Future<void> show(
    BuildContext context, {
    required String locationQuery,
    String? title,
  }) async {
    // 1. On mobile devices, require location permission first.
    // If user denies or taps anywhere outside the dialog, stop and do not open map.
    if (!kIsWeb) {
      final allowed = await PermissionService.requestLocationPermission(context);
      if (!allowed || !context.mounted) {
        return;
      }
    }

    final query = Uri.encodeComponent(locationQuery.trim());
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    // On web, opening Google Maps directly in a new tab avoids WebGL/canvas/iframe blocking
    if (kIsWeb) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {}
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppMapScreen(
          locationQuery: locationQuery,
          title: title,
        ),
      ),
    );
  }

  @override
  State<AppMapScreen> createState() => _AppMapScreenState();
}

class _AppMapScreenState extends State<AppMapScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initWebView();
    } else {
      _isLoading = false;
    }
  }

  void _initWebView() {
    final query = Uri.encodeComponent(widget.locationQuery.trim());
    final mapUrl = 'https://maps.google.com/maps?q=$query&t=&z=15&ie=UTF8&iwloc=&output=embed';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(mapUrl));
  }

  Future<void> _openInExternalMaps() async {
    final query = Uri.encodeComponent(widget.locationQuery.trim());
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _buildWebMapContent() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 64,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.title ?? 'Property Location',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.locationQuery,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _openInExternalMaps,
                icon: const Icon(Icons.directions_rounded, size: 22),
                label: const Text(
                  'Open in Google Maps / Live GPS 🗺️',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.locationQuery));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address copied to clipboard! 📋'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Address'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? 'Location Map',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.locationQuery,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_rounded, color: Color(0xFF6366F1)),
            tooltip: 'Directions in Google Maps',
            onPressed: _openInExternalMaps,
          ),
        ],
      ),
      body: kIsWeb
          ? _buildWebMapContent()
          : Stack(
              children: [
                if (_errorMessage == null && _controller != null)
                  WebViewWidget(controller: _controller!)
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 54, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not load in-app map',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ?? 'Map viewer unavailable',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openInExternalMaps,
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text('Open External Maps'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isLoading)
                  Container(
                    color: Colors.white.withValues(alpha: 0.8),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppLoader(size: 40),
                          SizedBox(height: 12),
                          Text(
                            'Loading in-app map...',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

