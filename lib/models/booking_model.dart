class BookingModel {
  final String id;
  final String vehicleId;
  final String vehicleName;
  final String userId;
  final String userName;
  final String userPhone;
  final DateTime pickUpDate;
  final DateTime returnDate;
  final double totalPrice;
  final double depositAmount;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BookingModel({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.pickUpDate,
    required this.returnDate,
    required this.totalPrice,
    required this.depositAmount,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory BookingModel.fromMap(
    String id,
    Map<dynamic, dynamic> data,
  ) {
    return BookingModel(
      id: id,
      vehicleId: data['vehicleId'] ?? '',
      vehicleName: data['vehicleName'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      pickUpDate: DateTime.parse(
        data['pickUpDate'] ?? DateTime.now().toIso8601String(),
      ),
      returnDate: DateTime.parse(
        data['returnDate'] ?? DateTime.now().toIso8601String(),
      ),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      depositAmount: (data['depositAmount'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'pickUpDate': pickUpDate.toIso8601String(),
      'returnDate': returnDate.toIso8601String(),
      'totalPrice': totalPrice,
      'depositAmount': depositAmount,
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  int get rentalDays {
    return returnDate.difference(pickUpDate).inDays;
  }
}
