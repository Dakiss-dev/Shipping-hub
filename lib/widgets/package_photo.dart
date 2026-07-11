import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Renders a package photo from any of the three shapes [photoPath] can take:
/// a remote storage URL (http/https), a local device file path (mobile), or
/// an image_picker blob path (web). Falls back to a neutral placeholder when
/// the path is null/empty or the image fails to load.
class PackagePhoto extends StatelessWidget {
  final String? photoPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const PackagePhoto({
    super.key,
    required this.photoPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  bool get _hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasPhoto) return _placeholder();
    final path = photoPath!;
    // Web image_picker returns a blob: URL usable by Image.network; a synced
    // storage URL is also http(s). Only a real mobile file path uses File.
    if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined,
          size: 44, color: AppColors.textSecondary),
    );
  }
}
