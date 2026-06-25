import 'dart:convert';
import 'package:flutter/material.dart';

ImageProvider? getAppImageProvider(String? imageSrc) {
  if (imageSrc == null || imageSrc.trim().isEmpty) {
    return null;
  }
  if (imageSrc.startsWith('http://') || imageSrc.startsWith('https://')) {
    return NetworkImage(imageSrc);
  }
  try {
    String base64Str = imageSrc;
    if (imageSrc.contains(',')) {
      base64Str = imageSrc.split(',').last;
    }
    final decodedBytes = base64Decode(base64Str.trim());
    return MemoryImage(decodedBytes);
  } catch (e) {
    return null;
  }
}

class AppImage extends StatelessWidget {
  final String? imageSrc;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const AppImage({
    super.key,
    required this.imageSrc,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final src = imageSrc;
    if (src == null || src.trim().isEmpty) {
      return placeholder ?? _defaultPlaceholder();
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder ?? _defaultPlaceholder(),
      );
    }
    try {
      String base64Str = src;
      if (src.contains(',')) {
        base64Str = src.split(',').last;
      }
      final decodedBytes = base64Decode(base64Str.trim());
      return Image.memory(
        decodedBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder ?? _defaultPlaceholder(),
      );
    } catch (e) {
      return placeholder ?? _defaultPlaceholder();
    }
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, size: 28, color: Colors.grey),
    );
  }
}
