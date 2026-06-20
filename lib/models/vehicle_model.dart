class VehicleModel {
  final String id;
  final String brand;
  final String model;
  final int year;
  final String plateNumber;
  final String color;
  final String transmission;
  final String fuelType;
  final int seats;
  final double pricePerDay;
  final bool isAvailable;
  final String mainImage;
  final String description;
  final String createdAt;
  final String branchId;
  final String branchName;

  VehicleModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.plateNumber,
    required this.color,
    required this.transmission,
    required this.fuelType,
    required this.seats,
    required this.pricePerDay,
    required this.isAvailable,
    required this.mainImage,
    required this.description,
    required this.createdAt,
    this.branchId = '',
    this.branchName = '',
  });

  factory VehicleModel.fromMap(
    String id,
    Map<dynamic, dynamic> data,
  ) {
    return VehicleModel(
      id: id,
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? 0,
      plateNumber: data['plateNumber'] ?? '',
      color: data['color'] ?? '',
      transmission: data['transmission'] ?? '',
      fuelType: data['fuelType'] ?? '',
      seats: data['seats'] ?? 4,
      pricePerDay: (data['pricePerDay'] ?? 0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      mainImage: data['mainImage'] ?? '',
      description: data['description'] ?? '',
      createdAt: data['createdAt'] ?? '',
      branchId: data['branchId'] ?? '',
      branchName: data['branchName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'plateNumber': plateNumber,
      'color': color,
      'transmission': transmission,
      'fuelType': fuelType,
      'seats': seats,
      'pricePerDay': pricePerDay,
      'isAvailable': isAvailable,
      'mainImage': mainImage,
      'description': description,
      'createdAt': createdAt,
      'branchId': branchId,
      'branchName': branchName,
    };
  }
}
