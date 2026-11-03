import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

/// Full-screen in-app video player with Chewie controls and Cloudinary streaming optimizer.
class AppVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? title;

  const AppVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.title,
  });

  /// Launch the in-app video player screen from anywhere in the app.
  static Future<void> show(
    BuildContext context, {
    required String videoUrl,
    String? title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppVideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
        ),
      ),
    );
  }

  /// Optimize Cloudinary video URLs to stream universally across all mobile devices
  /// using H.264 video codec and AAC audio in an MP4 container.
  static String optimizeVideoUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (!trimmed.contains('cloudinary.com') || !trimmed.contains('/video/upload/')) {
      return trimmed;
    }

    final parts = trimmed.split('/video/upload/');
    final prefix = '${parts[0]}/video/upload/';
    var suffix = parts[1];

    // Replace non-mp4 extensions with .mp4
    suffix = suffix.replaceAll(
      RegExp(r'\.(mov|avi|mkv|webm|flv|wmv|m4v)(\?.*)?$', caseSensitive: false),
      '.mp4',
    );

    // If it doesn't end with an extension or query, add .mp4
    if (!suffix.contains('.mp4') && !suffix.contains('?')) {
      suffix = '$suffix.mp4';
    }

    // Insert Cloudinary on-the-fly MP4 H.264 + AAC transcoding transformation
    if (!suffix.contains('f_mp4')) {
      return '${prefix}f_mp4,vc_h264,ac_aac,q_auto/$suffix';
    }

    return '$prefix$suffix';
  }

  /// Automatically generates a thumbnail preview image URL for Cloudinary videos.
  static String? getCloudinaryThumbnail(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.contains('cloudinary.com') && trimmed.contains('/video/upload/')) {
      return trimmed.replaceAll(
        RegExp(r'\.(mp4|mov|avi|mkv|webm|flv|wmv|m4v)(\?.*)?$', caseSensitive: false),
        '.jpg',
      );
    }
    return null;
  }

  @override
  State<AppVideoPlayerScreen> createState() => _AppVideoPlayerScreenState();
}

class _AppVideoPlayerScreenState extends State<AppVideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  late final String _playableUrl;

  @override
  void initState() {
    super.initState();
    _playableUrl = AppVideoPlayerScreen.optimizeVideoUrl(widget.videoUrl);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final uri = Uri.tryParse(_playableUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid video URL: ${widget.videoUrl}';
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoPlayerController = controller;

      // Timeout after 15 seconds to prevent infinite "Buffering" freeze
      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Video initialization timed out after 15s');
        },
      );

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final double aspect = controller.value.aspectRatio > 0
          ? controller.value.aspectRatio
          : (16 / 9);

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: aspect,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        showControlsOnInitialize: true,
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6366F1),
          handleColor: const Color(0xFF818CF8),
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: AppLoader(size: 38),
          ),
        ),
        errorBuilder: (context, errorText) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to play video in-app',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openInExternalBrowser,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open in Browser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not stream video in-app: $e';
        });
      }
    }
  }

  Future<void> _openInExternalBrowser() async {
    final uri = Uri.tryParse(widget.videoUrl.trim());
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title ?? 'Video Player',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white70),
            tooltip: 'Open in Browser',
            onPressed: _openInExternalBrowser,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLoader(size: 42),
          SizedBox(height: 16),
          Text(
            'Buffering video...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Could not load video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _initPlayer();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _openInExternalBrowser,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('External Player'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Chewie(controller: _chewieController!);
    }

    return const Center(child: AppLoader(size: 38));
  }
}
