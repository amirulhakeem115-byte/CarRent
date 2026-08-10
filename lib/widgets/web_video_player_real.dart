import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

Widget buildWebVideoPlayer({
  required String videoUrl,
  required bool autoPlay,
}) {
  return _WebVideoElementView(videoUrl: videoUrl, autoPlay: autoPlay);
}

class _WebVideoElementView extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;

  const _WebVideoElementView({
    required this.videoUrl,
    required this.autoPlay,
  });

  @override
  State<_WebVideoElementView> createState() => _WebVideoElementViewState();
}

class _WebVideoElementViewState extends State<_WebVideoElementView> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    final String cleanUrl = widget.videoUrl.split('?').first;
    final String cleanId = cleanUrl.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final String uniqueId = cleanId.length > 20 ? cleanId.substring(cleanId.length - 20) : cleanId;
    _viewType = 'video_elem_${DateTime.now().microsecondsSinceEpoch}_$uniqueId';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = web.document.createElement('video') as web.HTMLVideoElement;
      video.src = widget.videoUrl;
      video.controls = true;
      video.autoplay = widget.autoPlay;
      video.playsInline = true;
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.objectFit = 'contain';
      video.style.backgroundColor = 'black';
      video.style.borderRadius = '12px';

      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
