class TrackingModel {
  final String vehicleId;
  final double latitude;
  final double longitude;
  final double speed; // in km/h
  final String timestamp;

  TrackingModel({
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });

  factory TrackingModel.fromMap(String vehicleId, Map<dynamic, dynamic> data) {
    return TrackingModel(
      vehicleId: vehicleId,
      latitude: (data['latitude'] ?? 3.1390).toDouble(),
      longitude: (data['longitude'] ?? 101.6869).toDouble(),
      speed: (data['speed'] ?? 0.0).toDouble(),
      timestamp: data['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'timestamp': timestamp,
    };
  }
}
