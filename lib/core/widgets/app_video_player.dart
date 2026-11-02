import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:agent_app/core/widgets/app_loader.dart';

/// Full-screen in-app video player with Chewie controls and Cloudinary thumbnail helper.
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

  /// Automatically generates a thumbnail preview image URL for Cloudinary videos.
  /// Cloudinary automatically extracts a frame preview if you replace the video
  /// extension (.mp4, .mov, etc.) with `.jpg`.
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

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final uri = Uri.tryParse(widget.videoUrl.trim());
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
      final controller = VideoPlayerController.networkUrl(uri);
      _videoPlayerController = controller;

      await controller.initialize();

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
                    'Unable to play video',
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
          _errorMessage = 'Failed to load video: $e';
        });
      }
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
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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

