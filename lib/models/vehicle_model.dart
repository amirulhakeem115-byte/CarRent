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
  
  // Custom specs for high-fidelity UI references
  final String engine;
  final String condition;
  final bool ac;
  final double rentalDemand;
  final List<String> gallery;
  final List<String> equipment;
  final List<Map<String, dynamic>> maintenance;

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
    this.engine = 'M280',
    this.condition = 'Excellent',
    this.ac = true,
    this.rentalDemand = 85.0,
    this.gallery = const [],
    this.equipment = const [],
    this.maintenance = const [],
  });

  factory VehicleModel.fromMap(
    String id,
    Map<dynamic, dynamic> data,
  ) {
    // Determine vehicle type for smart defaults
    final isCoupe = (data['model'] ?? '').toString().toLowerCase().contains('coupe');
    final defaultEngine = isCoupe ? 'M177' : 'M280';
    
    // Parse gallery
    List<String> parsedGallery = [];
    if (data['gallery'] != null) {
      if (data['gallery'] is List) {
        parsedGallery = List<String>.from(data['gallery']);
      } else if (data['gallery'] is Map) {
        (data['gallery'] as Map).forEach((k, v) {
          parsedGallery.add(v.toString());
        });
      }
    }
    if (parsedGallery.isEmpty) {
      final mainImg = data['mainImage'] ?? '';
      parsedGallery = [
        mainImg,
        'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
        'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
      ];
    }

    // Parse equipment
    List<String> parsedEquipment = [];
    if (data['equipment'] != null) {
      if (data['equipment'] is List) {
        parsedEquipment = List<String>.from(data['equipment']);
      } else if (data['equipment'] is Map) {
        (data['equipment'] as Map).forEach((k, v) {
          parsedEquipment.add(v.toString());
        });
      }
    }
    if (parsedEquipment.isEmpty) {
      parsedEquipment = ['ABS', 'All Bags', 'Cruise Control', 'Extra Tyre', 'Tools', 'First Aid'];
    }

    // Parse maintenance history
    List<Map<String, dynamic>> parsedMaintenance = [];
    if (data['maintenance'] != null) {
      if (data['maintenance'] is List) {
        parsedMaintenance = (data['maintenance'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } else if (data['maintenance'] is Map) {
        (data['maintenance'] as Map).forEach((k, v) {
          parsedMaintenance.add(Map<String, dynamic>.from(v as Map));
        });
      }
    }
    if (parsedMaintenance.isEmpty) {
      parsedMaintenance = [
        {
          'section': 'Broken Window',
          'description': 'Replaced passenger side window after impact damage.',
          'startDate': '2026-05-12',
          'endDate': '2026-05-14',
        },
        {
          'section': 'Engine Failure',
          'description': 'Routine belt replacement and fuel pump calibration.',
          'startDate': '2026-03-20',
          'endDate': '2026-03-25',
        }
      ];
    }

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
      engine: data['engine'] ?? defaultEngine,
      condition: data['condition'] ?? 'Excellent',
      ac: data['ac'] ?? true,
      rentalDemand: (data['rentalDemand'] ?? (isCoupe ? 78.0 : 92.0)).toDouble(),
      gallery: parsedGallery,
      equipment: parsedEquipment,
      maintenance: parsedMaintenance,
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
      'engine': engine,
      'condition': condition,
      'ac': ac,
      'rentalDemand': rentalDemand,
      'gallery': gallery,
      'equipment': equipment,
      'maintenance': maintenance,
    };
  }
}
