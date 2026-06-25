import 'dart:async';

class ReceiptFile {
  final String name;
  final String base64Data;
  final int size;
  ReceiptFile({required this.name, required this.base64Data, required this.size});
}

typedef ReceiptUploadCallback = void Function(String base64, String name, int size);

// Callback that gets notified when dropzone uploads a file
ReceiptUploadCallback? onReceiptUploadedCallback;

Future<ReceiptFile?> pickReceiptFile() async {
  return null;
}

void registerPlatformDropzone() {
  // Stub
}
