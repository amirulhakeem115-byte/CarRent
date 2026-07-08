import 'browser_device_info_stub.dart'
    if (dart.library.html) 'browser_device_info_web.dart'
    as impl;

String getBrowserDeviceInfo() => impl.getBrowserDeviceInfo();
