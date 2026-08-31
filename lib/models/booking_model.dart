class BookingModel {
  final String id;
  final String vehicleId;
  final String vehicleName;
  final String userId;
  final String userName;
  final String userPhone;
  final DateTime pickUpDate;
  final DateTime? returnDate;
  final double totalPrice;
  final double depositAmount;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int pointsRedeemed;
  final double discountAmount;
  final bool pointsRedeemedProcessed;
  final bool rewardPointsAwarded;
  final bool isReturned;
  
  // New scheduling fields
  final String? actualPickupTime;
  final String? actualReturnTime;
  final bool pickupReminderSent;
  final bool returnReminderSent;
  final String? customerStatus;
  final String? paymentMethod;

  // New Extension & Return Inspection fields
  final Map<String, dynamic>? extensionRequest;
  final Map<String, dynamic>? returnInspection;
  final double lateFees;
  final double finalAmount;

  // Open Rental fields
  final bool isOpenRental;
  final DateTime? actualPickupTimestamp;
  final DateTime? actualReturnTimestamp;

  // Promotional Discount fields
  final String? promotionId;
  final String? promotionCode;
  final String? promotionName;
  final double promotionDiscountAmount;

  // Employee Assignment & Staff Tracking fields
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final String? handedOverByEmployeeId;
  final String? handedOverByEmployeeName;
  final String? receivedByEmployeeId;
  final String? receivedByEmployeeName;

  // Booking Source field ('system', 'whatsapp', 'phone', 'walkIn')
  final String bookingSource;

  // Passport & Driving License fields
  final String? passportNumber;
  final String? drivingLicenseNumber;

  // Delivery fields
  final double deliveryFee;
  final bool isDelivery;
  final String? deliveryAddress;
  final DateTime? deliveryDate;
  final String? deliveryTime;
  final String deliveryStatus;

  BookingModel({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.pickUpDate,
    DateTime? returnDate,
    this.totalPrice = 0.0,
    this.depositAmount = 0.0,
    this.status = 'Pending',
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.pointsRedeemed = 0,
    this.discountAmount = 0.0,
    this.pointsRedeemedProcessed = false,
    this.rewardPointsAwarded = false,
    this.isReturned = false,
    this.actualPickupTime,
    this.actualReturnTime,
    this.pickupReminderSent = false,
    this.returnReminderSent = false,
    this.customerStatus,
    this.paymentMethod = 'Online',
    this.extensionRequest,
    this.returnInspection,
    this.lateFees = 0.0,
    this.finalAmount = 0.0,
    this.isOpenRental = false,
    this.actualPickupTimestamp,
    this.actualReturnTimestamp,
    this.promotionId,
    this.promotionCode,
    this.promotionName,
    this.promotionDiscountAmount = 0.0,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.handedOverByEmployeeId,
    this.handedOverByEmployeeName,
    this.receivedByEmployeeId,
    this.receivedByEmployeeName,
    this.bookingSource = 'system',
    this.passportNumber,
    this.drivingLicenseNumber,
    this.deliveryFee = 0.0,
    this.isDelivery = false,
    this.deliveryAddress,
    this.deliveryDate,
    this.deliveryTime,
    this.deliveryStatus = 'Scheduled',
  }) : returnDate = isOpenRental ? null : returnDate;

  String get normalizedBookingSource {
    final s = bookingSource.toLowerCase().trim();
    if (s == 'phone' || s == 'phone call' || s == 'phone_call') return 'phone';
    if (s == 'walkin' || s == 'walk_in' || s == 'walk-in') return 'walkIn';
    if (s == 'whatsapp' || s == 'wa') return 'whatsapp';
    return 'system';
  }

  String get bookingSourceLabel {
    switch (normalizedBookingSource) {
      case 'phone':
        return 'Phone Call';
      case 'walkIn':
        return 'Walk-in';
      case 'whatsapp':
        return 'WhatsApp';
      case 'system':
      default:
        return 'System App';
    }
  }

  factory BookingModel.fromMap(String id, Map<dynamic, dynamic> data) {
    final isOpen = data['isOpenRental'] ?? false;
    final rawReturnDate = data['returnDate'];

    return BookingModel(
      id: id,
      vehicleId: data['vehicleId'] ?? '',
      vehicleName: data['vehicleName'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      pickUpDate: data['pickUpDate'] != null
          ? DateTime.parse(data['pickUpDate'] as String)
          : DateTime.now(),
      returnDate: rawReturnDate != null
          ? DateTime.parse(rawReturnDate as String)
          : null,
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
      depositAmount: (data['depositAmount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'Pending',
      notes: data['notes'],
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'] as String)
          : null,
      pointsRedeemed: data['pointsRedeemed'] ?? 0,
      discountAmount: (data['discountAmount'] ?? 0.0).toDouble(),
      pointsRedeemedProcessed: data['pointsRedeemedProcessed'] ?? false,
      rewardPointsAwarded: data['rewardPointsAwarded'] ?? false,
      isReturned: data['isReturned'] ?? false,
      actualPickupTime: data['actualPickupTime'],
      actualReturnTime: data['actualReturnTime'],
      pickupReminderSent: data['pickupReminderSent'] ?? false,
      returnReminderSent: data['returnReminderSent'] ?? false,
      customerStatus: data['customerStatus'],
      paymentMethod: data['paymentMethod'] ?? 'Online',
      extensionRequest: data['extensionRequest'] != null
          ? Map<String, dynamic>.from(data['extensionRequest'])
          : null,
      returnInspection: data['returnInspection'] != null
          ? Map<String, dynamic>.from(data['returnInspection'])
          : null,
      lateFees: (data['lateFees'] ?? 0.0).toDouble(),
      finalAmount: (data['finalAmount'] ?? 0.0).toDouble(),
      isOpenRental: isOpen,
      actualPickupTimestamp: data['actualPickupTimestamp'] != null
          ? DateTime.parse(data['actualPickupTimestamp'] as String)
          : null,
      actualReturnTimestamp: data['actualReturnTimestamp'] != null
          ? DateTime.parse(data['actualReturnTimestamp'] as String)
          : null,
      promotionId: data['promotionId'],
      promotionCode: data['promotionCode'],
      promotionName: data['promotionName'],
      promotionDiscountAmount:
          (data['promotionDiscountAmount'] ?? 0.0).toDouble(),
      assignedEmployeeId: data['assignedEmployeeId'] ?? data['assignedStaffId'] ?? data['employeeId'],
      assignedEmployeeName: data['assignedEmployeeName'] ?? data['assignedStaffName'],
      handedOverByEmployeeId: data['handedOverByEmployeeId'],
      handedOverByEmployeeName: data['handedOverByEmployeeName'],
      receivedByEmployeeId: data['receivedByEmployeeId'],
      receivedByEmployeeName: data['receivedByEmployeeName'],
      bookingSource: data['bookingSource']?.toString() ?? 'system',
      passportNumber: data['passportNumber'] ?? data['idNumber'],
      drivingLicenseNumber: data['drivingLicenseNumber'] ?? data['licenseNumber'],
      deliveryFee: (data['deliveryFee'] ?? 0.0).toDouble(),
      isDelivery: data['isDelivery'] ?? false,
      deliveryAddress: data['deliveryAddress'],
      deliveryDate: data['deliveryDate'] != null
          ? DateTime.parse(data['deliveryDate'] as String)
          : null,
      deliveryTime: data['deliveryTime'],
      deliveryStatus: data['deliveryStatus'] ?? 'Scheduled',
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
      'returnDate': (isOpenRental || returnDate == null) ? null : returnDate!.toIso8601String(),
      'totalPrice': totalPrice,
      'depositAmount': depositAmount,
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'pointsRedeemed': pointsRedeemed,
      'discountAmount': discountAmount,
      'pointsRedeemedProcessed': pointsRedeemedProcessed,
      'rewardPointsAwarded': rewardPointsAwarded,
      'isReturned': isReturned,
      'actualPickupTime': actualPickupTime,
      'actualReturnTime': actualReturnTime,
      'pickupReminderSent': pickupReminderSent,
      'returnReminderSent': returnReminderSent,
      'customerStatus': customerStatus,
      'paymentMethod': paymentMethod,
      'extensionRequest': extensionRequest,
      'returnInspection': returnInspection,
      'lateFees': lateFees,
      'finalAmount': finalAmount,
      'isOpenRental': isOpenRental,
      'actualPickupTimestamp': actualPickupTimestamp?.toIso8601String(),
      'actualReturnTimestamp': actualReturnTimestamp?.toIso8601String(),
      'promotionId': promotionId,
      'promotionCode': promotionCode,
      'promotionName': promotionName,
      'promotionDiscountAmount': promotionDiscountAmount,
      'assignedEmployeeId': assignedEmployeeId,
      'assignedEmployeeName': assignedEmployeeName,
      'handedOverByEmployeeId': handedOverByEmployeeId,
      'handedOverByEmployeeName': handedOverByEmployeeName,
      'receivedByEmployeeId': receivedByEmployeeId,
      'receivedByEmployeeName': receivedByEmployeeName,
      'bookingSource': bookingSource,
      'passportNumber': passportNumber,
      'drivingLicenseNumber': drivingLicenseNumber,
      'deliveryFee': deliveryFee,
      'isDelivery': isDelivery,
      'deliveryAddress': deliveryAddress,
      'deliveryDate': deliveryDate?.toIso8601String(),
      'deliveryTime': deliveryTime,
      'deliveryStatus': deliveryStatus,
    };
  }

  int get rentalDays {
    if (isOpenRental) {
      final start = actualPickupTimestamp ?? pickUpDate;
      final end = actualReturnTimestamp ?? DateTime.now();
      if (end.isBefore(start)) return 1;
      final hrs = end.difference(start).inHours;
      final days = (hrs / 24).ceil();
      return days <= 0 ? 1 : days;
    }
    if (returnDate == null) return 1;
    final diff = returnDate!.difference(pickUpDate).inDays;
    return diff <= 0 ? 1 : diff;
  }

  double calculateAccruedTotal(double pricePerDay) {
    if (status.trim().toLowerCase() == 'completed' && finalAmount > 0) {
      return finalAmount;
    }
    final days = rentalDays;
    final gross = days * pricePerDay;
    final net = gross - discountAmount - promotionDiscountAmount + lateFees;
    return net < 0 ? 0.0 : net;
  }
}
