// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'dart:js_interop';

import 'receipt_upload_helper.dart';
export 'receipt_upload_helper.dart';

Future<ReceiptFile?> pickReceiptFile() async {
  final completer = Completer<ReceiptFile?>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'image/jpeg,image/png,application/pdf';
  
  input.addEventListener('change', (web.Event e) {
    if (input.files != null && input.files!.length > 0) {
      final file = input.files!.item(0);
      if (file != null) {
        if (file.size > 10 * 1024 * 1024) {
          completer.complete(ReceiptFile(name: file.name, base64Data: 'error:size', size: file.size));
          return;
        }
        final reader = web.FileReader();
        reader.readAsDataURL(file);
        reader.onloadend = (web.Event ev) {
          completer.complete(ReceiptFile(
            name: file.name,
            base64Data: reader.result.toString(),
            size: file.size,
          ));
        }.toJS;
      } else {
        completer.complete(null);
      }
    } else {
      completer.complete(null);
    }
  }.toJS);
  
  input.click();
  return completer.future;
}

void registerPlatformDropzone() {
  ui_web.platformViewRegistry.registerViewFactory('receipt-dropzone', (int viewId) {
    final element = web.document.createElement('div') as web.HTMLDivElement;
    element.style.width = '100%';
    element.style.height = '100%';
    element.style.border = '2px dashed #ff9800';
    element.style.borderRadius = '12px';
    element.style.display = 'flex';
    element.style.flexDirection = 'column';
    element.style.alignItems = 'center';
    element.style.justifyContent = 'center';
    element.style.backgroundColor = '#fafafa';
    element.style.cursor = 'pointer';

    final text = web.document.createElement('p') as web.HTMLParagraphElement;
    text.textContent = 'Drag & Drop Receipt PDF/Image Here or Click to Upload';
    text.style.color = '#757575';
    text.style.fontFamily = 'sans-serif';
    text.style.fontSize = '14px';
    element.appendChild(text);

    // Click handler to trigger file selection
    element.addEventListener('click', (web.Event e) {
      final input = web.document.createElement('input') as web.HTMLInputElement;
      input.type = 'file';
      input.accept = 'image/jpeg,image/png,application/pdf';
      input.addEventListener('change', (web.Event ev) {
        if (input.files != null && input.files!.length > 0) {
          final file = input.files!.item(0);
          if (file != null) {
            _processWebFile(file);
          }
        }
      }.toJS);
      input.click();
    }.toJS);

    // Drag-and-drop handlers
    element.addEventListener('dragover', (web.Event e) {
      e.preventDefault();
      element.style.borderColor = '#2ecc71';
      element.style.backgroundColor = '#e8f8f5';
    }.toJS);

    element.addEventListener('dragleave', (web.Event e) {
      element.style.borderColor = '#ff9800';
      element.style.backgroundColor = '#fafafa';
    }.toJS);

    element.addEventListener('drop', (web.Event e) {
      final dragEvent = e as web.DragEvent;
      dragEvent.preventDefault();
      element.style.borderColor = '#ff9800';
      element.style.backgroundColor = '#fafafa';

      if (dragEvent.dataTransfer != null && dragEvent.dataTransfer!.files.length > 0) {
        final file = dragEvent.dataTransfer!.files.item(0);
        if (file != null) {
          _processWebFile(file);
        }
      }
    }.toJS);

    return element;
  });
}

void _processWebFile(web.File file) {
  if (file.size > 10 * 1024 * 1024) {
    if (onReceiptUploadedCallback != null) {
      onReceiptUploadedCallback!('error:size', file.name, file.size);
    }
    return;
  }
  
  final fileType = file.type.toLowerCase();
  final fileName = file.name.toLowerCase();
  final isAccepted = fileType.contains('jpeg') || 
                     fileType.contains('jpg') || 
                     fileType.contains('png') || 
                     fileType.contains('pdf') ||
                     fileName.endsWith('.jpg') ||
                     fileName.endsWith('.jpeg') ||
                     fileName.endsWith('.png') ||
                     fileName.endsWith('.pdf');

  if (!isAccepted) {
    if (onReceiptUploadedCallback != null) {
      onReceiptUploadedCallback!('error:format', file.name, file.size);
    }
    return;
  }

  final reader = web.FileReader();
  reader.readAsDataURL(file);
  reader.onloadend = (web.Event e) {
    final result = reader.result.toString();
    if (onReceiptUploadedCallback != null) {
      onReceiptUploadedCallback!(result, file.name, file.size);
    }
  }.toJS;
}
