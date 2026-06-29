class MaintenanceJobModel {
  final String id; // maps to maintenanceId in DB or key
  final String vehicleId;
  final String vehicleName;
  final String title;
  final String description;
  final double cost;
  final String startDate;
  final String endDate;
  final String status; // Scheduled, In Progress, Completed, Cancelled
  final bool showToCustomer;
  final String createdAt;
  final String updatedAt;

  MaintenanceJobModel({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.title,
    required this.description,
    required this.cost,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.showToCustomer = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaintenanceJobModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return MaintenanceJobModel(
      id: id,
      vehicleId: map['vehicleId'] ?? '',
      vehicleName: map['vehicleName'] ?? '',
      title: map['title'] ?? map['serviceType'] ?? '',
      description: map['description'] ?? map['notes'] ?? '',
      cost: (map['cost'] ?? 0.0).toDouble(),
      startDate: map['startDate'] ?? map['date'] ?? '',
      endDate: map['endDate'] ?? map['date'] ?? '',
      status: map['status'] ?? 'Scheduled',
      showToCustomer: map['showToCustomer'] ?? false,
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maintenanceId': id,
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'title': title,
      'description': description,
      'cost': cost,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'showToCustomer': showToCustomer,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}


