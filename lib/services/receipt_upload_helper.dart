import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptFile {
  final String name;
  final String base64Data;
  final int size;
  ReceiptFile({
    required this.name,
    required this.base64Data,
    required this.size,
  });
}

typedef ReceiptUploadCallback =
    void Function(String base64, String name, int size);

// Callback that gets notified when dropzone uploads a file
ReceiptUploadCallback? onReceiptUploadedCallback;

Future<ReceiptFile?> pickReceiptFile() async {
  // Non-web flow: open gallery picker on mobile and desktop.
  if (kIsWeb) {
    return null;
  }

  final XFile? pickedFile = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 100,
  );

  if (pickedFile == null) {
    return null;
  }

  final bytes = await pickedFile.readAsBytes();
  final size = bytes.length;

  if (size > 10 * 1024 * 1024) {
    return ReceiptFile(
      name: pickedFile.name,
      base64Data: 'error:size',
      size: size,
    );
  }

  final lowerName = pickedFile.name.toLowerCase();
  String mimeType = 'image/jpeg';
  if (lowerName.endsWith('.png')) {
    mimeType = 'image/png';
  } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
    mimeType = 'image/jpeg';
  } else if (lowerName.endsWith('.webp')) {
    mimeType = 'image/webp';
  }

  return ReceiptFile(
    name: pickedFile.name,
    base64Data: 'data:$mimeType;base64,${base64Encode(bytes)}',
    size: size,
  );
}

void registerPlatformDropzone() {
  // Stub
}
