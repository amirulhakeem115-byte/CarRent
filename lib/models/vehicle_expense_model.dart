class VehicleExpenseModel {
  final String id;
  final String vehicleId;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String description;
  final DateTime createdAt;

  VehicleExpenseModel({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.amount,
    required this.date,
    this.category = 'Other',
    this.description = '',
    required this.createdAt,
  });

  factory VehicleExpenseModel.fromMap(String id, String vehicleId, Map<dynamic, dynamic> map) {
    DateTime parseDate(dynamic dateVal) {
      if (dateVal == null) return DateTime.now();
      if (dateVal is String && dateVal.isNotEmpty) {
        try {
          return DateTime.parse(dateVal);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return VehicleExpenseModel(
      id: id,
      vehicleId: vehicleId,
      title: (map['title'] ?? map['name'] ?? 'Vehicle Expense').toString(),
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: parseDate(map['date']),
      category: (map['category'] ?? 'Other').toString(),
      description: (map['description'] ?? map['notes'] ?? '').toString(),
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expenseId': id,
      'vehicleId': vehicleId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
