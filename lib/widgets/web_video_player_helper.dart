export 'web_video_player_stub.dart'
    if (dart.library.js_interop) 'web_video_player_real.dart'
    if (dart.library.html) 'web_video_player_real.dart';
