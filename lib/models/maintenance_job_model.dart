class MaintenanceJobModel {
  final String id;
  final String vehicleId;
  final String vehicleName;
  final String serviceType;
  final double cost;
  final String date;
  final String notes;
  final String status; // Pending, In Progress, Completed
  final bool showToCustomer;

  MaintenanceJobModel({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.serviceType,
    required this.cost,
    required this.date,
    required this.notes,
    required this.status,
    this.showToCustomer = false,
  });

  factory MaintenanceJobModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return MaintenanceJobModel(
      id: id,
      vehicleId: map['vehicleId'] ?? '',
      vehicleName: map['vehicleName'] ?? '',
      serviceType: map['serviceType'] ?? '',
      cost: (map['cost'] ?? 0.0).toDouble(),
      date: map['date'] ?? '',
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'Pending',
      showToCustomer: map['showToCustomer'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'serviceType': serviceType,
      'cost': cost,
      'date': date,
      'notes': notes,
      'status': status,
      'showToCustomer': showToCustomer,
    };
  }
}

