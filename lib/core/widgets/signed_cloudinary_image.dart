import 'package:flutter/material.dart';

import '../network/api_client.dart';

/// Displays a Cloudinary asset that was uploaded with `type: authenticated`
/// (see CloudinaryService.uploadVerificationDocument and
/// backend/controllers/uploadController.js). These assets have no public
/// URL — [publicId] is a Cloudinary identifier, not a fetchable link. This
/// widget asks the backend for a short-lived signed delivery URL (verifying
/// the current user is the document's owner or an admin) and renders that
/// once resolved.
class SignedCloudinaryImage extends StatefulWidget {
  const SignedCloudinaryImage({
    super.key,
    required this.publicId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String publicId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  State<SignedCloudinaryImage> createState() => _SignedCloudinaryImageState();
}

class _SignedCloudinaryImageState extends State<SignedCloudinaryImage> {
  late Future<String> _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _signedUrlFuture = _resolveSignedUrl(widget.publicId);
  }

  @override
  void didUpdateWidget(covariant SignedCloudinaryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publicId != widget.publicId) {
      _signedUrlFuture = _resolveSignedUrl(widget.publicId);
    }
  }

  Future<String> _resolveSignedUrl(String publicId) async {
    // If this ever receives a plain http(s) URL (e.g. legacy data uploaded
    // before this fix, or a non-sensitive image reused with this widget by
    // mistake), just use it directly rather than trying to "resolve" it.
    if (publicId.startsWith('http://') || publicId.startsWith('https://')) {
      return publicId;
    }

    final res = await ApiClient.get(
      '/uploads/cloudinary-signed-url?publicId=${Uri.encodeComponent(publicId)}',
    );
    if (res['success'] == true && res['url'] != null) {
      return res['url'].toString();
    }
    throw Exception(res['error']?.toString() ?? 'Unable to load document.');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _signedUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return widget.errorBuilder?.call(context, snapshot.error ?? 'unknown', null) ??
              SizedBox(
                width: widget.width,
                height: widget.height,
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
              );
        }

        return Image.network(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: widget.errorBuilder,
        );
      },
    );
  }
}
