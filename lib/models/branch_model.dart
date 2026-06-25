class BranchModel {
  final String id;
  final String branchName;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;
  final String operatingHours;

  String get name => branchName;

  BranchModel({
    required this.id,
    required this.branchName,
    required this.address,
    required this.phone,
    this.latitude = 3.0166,
    this.longitude = 101.7916,
    this.operatingHours = '09:00 AM - 09:00 PM',
  });

  factory BranchModel.fromMap(String id, Map<dynamic, dynamic> data) {
    return BranchModel(
      id: id,
      branchName: data['branchName'] ?? data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      latitude: (data['latitude'] ?? 3.0166).toDouble(),
      longitude: (data['longitude'] ?? 101.7916).toDouble(),
      operatingHours: data['operatingHours'] ?? '09:00 AM - 09:00 PM',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchName': branchName,
      'name': branchName,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'operatingHours': operatingHours,
    };
  }
}

