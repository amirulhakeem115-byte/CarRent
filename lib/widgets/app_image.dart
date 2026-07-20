import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final Map<String, Uint8List> _base64Cache = {};

Uint8List? _getDecodedBase64(String src) {
  if (_base64Cache.containsKey(src)) {
    return _base64Cache[src];
  }
  try {
    String base64Str = src;
    if (src.contains(',')) {
      base64Str = src.split(',').last;
    }
    final decoded = base64Decode(base64Str.trim());
    _base64Cache[src] = decoded;
    return decoded;
  } catch (e) {
    return null;
  }
}

ImageProvider? getAppImageProvider(String? imageSrc) {
  if (imageSrc == null || imageSrc.trim().isEmpty) {
    return null;
  }
  if (imageSrc.startsWith('http://') || imageSrc.startsWith('https://')) {
    return NetworkImage(imageSrc);
  }
  final bytes = _getDecodedBase64(imageSrc);
  if (bytes != null) {
    return MemoryImage(bytes);
  }
  return null;
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
    final decodedBytes = _getDecodedBase64(src);
    if (decodedBytes != null) {
      return Image.memory(
        decodedBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder ?? _defaultPlaceholder(),
      );
    }
    return placeholder ?? _defaultPlaceholder();
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
