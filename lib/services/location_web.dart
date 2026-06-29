// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:latlong2/latlong.dart';

Future<LatLng?> getUserLocation() async {
  final completer = Completer<LatLng?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition position) {
        final double lat = position.coords.latitude;
        final double lng = position.coords.longitude;
        completer.complete(LatLng(lat, lng));
      }.toJS,
      (web.GeolocationPositionError error) {
        completer.complete(null);
      }.toJS,
    );
  } catch (e) {
    completer.complete(null);
  }
  return completer.future;
}
