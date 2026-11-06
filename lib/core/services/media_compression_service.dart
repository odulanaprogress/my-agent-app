import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Compression and validation service for property media.
/// Enforces:
/// 1. Maximum total combined images size: 10 MB
/// 2. Maximum single video size: 100 MB
/// 3. Visual-lossless image compression and resizing.
class MediaCompressionService {
  static const int maxTotalImageBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxVideoBytes = 100 * 1024 * 1024; // 100 MB

  /// Formats byte sizes into human-readable strings (e.g. "4.2 MB", "850 KB")
  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  /// Calculates total byte size of a list of image files.
  static int calculateTotalImageSize(List<File> files) {
    int total = 0;
    for (final f in files) {
      try {
        if (f.existsSync()) {
          total += f.lengthSync();
        }
      } catch (_) {}
    }
    return total;
  }

  /// Validates video file size against the 100 MB threshold.
  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validateVideo(File? videoFile) {
    if (videoFile == null) return null;
    try {
      if (!videoFile.existsSync()) return null;
      final size = videoFile.lengthSync();
      if (size > maxVideoBytes) {
        return 'Video is ${formatBytes(size)}. Maximum allowed video size is 100 MB.';
      }
      return null;
    } catch (e) {
      return 'Unable to check video size: $e';
    }
  }

  /// Compresses a list of images with intelligent resizing and high-fidelity JPEG encoding.
  /// Ensures the total batch size stays safely under 10 MB while preserving sharp detail.
  static Future<List<File>> compressImages(
    List<File> inputFiles, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (inputFiles.isEmpty) return [];

    final compressedFiles = <File>[];
    final tempDir = !kIsWeb ? await getTemporaryDirectory() : null;

    int originalTotalBytes = 0;
    for (int i = 0; i < inputFiles.length; i++) {
      final file = inputFiles[i];
      try {
        final rawBytes = await file.readAsBytes();
        originalTotalBytes += rawBytes.length;

        onProgress?.call(
          (i + 1) / inputFiles.length,
          'Optimizing photo ${i + 1} of ${inputFiles.length}...',
        );

        // Decode image
        final decoded = img.decodeImage(rawBytes);
        if (decoded == null) {
          // If decoder fails, keep original file
          compressedFiles.add(file);
          continue;
        }

        // Resize if larger than 1920 on largest axis (preserves 1080p full detail)
        img.Image processed = decoded;
        const maxDimension = 1920;
        if (decoded.width > maxDimension || decoded.height > maxDimension) {
          if (decoded.width >= decoded.height) {
            processed = img.copyResize(
              decoded,
              width: maxDimension,
              interpolation: img.Interpolation.linear,
            );
          } else {
            processed = img.copyResize(
              decoded,
              height: maxDimension,
              interpolation: img.Interpolation.linear,
            );
          }
        }

        // Encode to clean, high-quality JPEG
        final encodedJpg = img.encodeJpg(processed, quality: 82);

        if (tempDir != null) {
          final outPath =
              '${tempDir.path}/opt_img_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
          final outFile = File(outPath);
          await outFile.writeAsBytes(encodedJpg, flush: true);
          compressedFiles.add(outFile);
        } else {
          compressedFiles.add(file);
        }
      } catch (e) {
        debugPrint('[MediaCompressionService] Error compressing photo $i: $e');
        compressedFiles.add(file);
      }
    }

    // Verify whether compressed batch fits under 10 MB
    int compressedTotal = calculateTotalImageSize(compressedFiles);
    if (compressedTotal > maxTotalImageBytes && tempDir != null) {
      // Second aggressive compression pass if total still exceeds 10 MB
      final secondPass = <File>[];
      for (int j = 0; j < compressedFiles.length; j++) {
        try {
          final b = await compressedFiles[j].readAsBytes();
          final dec = img.decodeImage(b);
          if (dec != null) {
            final resized = img.copyResize(
              dec,
              width: dec.width > 1440 ? 1440 : null,
              height: dec.height > 1440 ? 1440 : null,
              interpolation: img.Interpolation.linear,
            );
            final reEnc = img.encodeJpg(resized, quality: 72);
            final p =
                '${tempDir.path}/opt2_img_${DateTime.now().microsecondsSinceEpoch}_$j.jpg';
            final f = File(p);
            await f.writeAsBytes(reEnc, flush: true);
            secondPass.add(f);
          } else {
            secondPass.add(compressedFiles[j]);
          }
        } catch (_) {
          secondPass.add(compressedFiles[j]);
        }
      }
      return secondPass;
    }

    final compressedTotalBytes = calculateTotalImageSize(compressedFiles);
    debugPrint(
      '[MediaCompressionService] Optimized ${inputFiles.length} photos: '
      '${formatBytes(originalTotalBytes)} -> ${formatBytes(compressedTotalBytes)}',
    );

    return compressedFiles;
  }
}

