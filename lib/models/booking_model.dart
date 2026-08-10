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

  // Return Video Evidence fields
  final Map<String, dynamic>? returnVideos;
  final bool returnVideoSkipped;

  BookingModel({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.pickUpDate,
    this.returnDate,
    required this.totalPrice,
    required this.depositAmount,
    required this.status,
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
    this.paymentMethod,
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
    this.returnVideos,
    this.returnVideoSkipped = false,
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
      returnDate: data['returnDate'] != null
          ? DateTime.parse(data['returnDate'] as String)
          : null,
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
      pointsRedeemed: data['pointsRedeemed'] is int
          ? data['pointsRedeemed'] as int
          : int.tryParse(data['pointsRedeemed']?.toString() ?? '') ?? 0,
      discountAmount: (data['discountAmount'] ?? 0.0).toDouble(),
      pointsRedeemedProcessed: data['pointsRedeemedProcessed'] ?? false,
      rewardPointsAwarded: data['rewardPointsAwarded'] ?? false,
      isReturned: data['isReturned'] ?? false,
      actualPickupTime: data['actualPickupTime'],
      actualReturnTime: data['actualReturnTime'],
      pickupReminderSent: data['pickupReminderSent'] ?? false,
      returnReminderSent: data['returnReminderSent'] ?? false,
      customerStatus: data['customerStatus'],
      paymentMethod: data['paymentMethod'],
      extensionRequest: data['extensionRequest'] != null
          ? Map<String, dynamic>.from(data['extensionRequest'] as Map)
          : null,
      returnInspection: data['returnInspection'] != null
          ? Map<String, dynamic>.from(data['returnInspection'] as Map)
          : null,
      lateFees: (data['lateFees'] ?? 0.0).toDouble(),
      finalAmount: (data['finalAmount'] ?? 0.0).toDouble(),
      isOpenRental: data['isOpenRental'] ?? false,
      actualPickupTimestamp: data['actualPickupTimestamp'] != null
          ? DateTime.parse(data['actualPickupTimestamp'] as String)
          : null,
      actualReturnTimestamp: data['actualReturnTimestamp'] != null
          ? DateTime.parse(data['actualReturnTimestamp'] as String)
          : null,
      promotionId: data['promotionId'],
      promotionCode: data['promotionCode'],
      promotionName: data['promotionName'],
      promotionDiscountAmount: (data['promotionDiscountAmount'] ?? 0.0).toDouble(),
      assignedEmployeeId: data['assignedEmployeeId'] ?? data['assignedStaffId'] ?? data['employeeId'],
      assignedEmployeeName: data['assignedEmployeeName'] ?? data['assignedStaffName'],
      handedOverByEmployeeId: data['handedOverByEmployeeId'],
      handedOverByEmployeeName: data['handedOverByEmployeeName'],
      receivedByEmployeeId: data['receivedByEmployeeId'],
      receivedByEmployeeName: data['receivedByEmployeeName'],
      returnVideos: data['returnVideos'] != null
          ? Map<String, dynamic>.from(data['returnVideos'] as Map)
          : null,
      returnVideoSkipped: data['returnVideoSkipped'] ?? false,
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
      'returnDate': returnDate?.toIso8601String(),
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
      'returnVideos': returnVideos,
      'returnVideoSkipped': returnVideoSkipped,
    };
  }

  List<Map<String, dynamic>> get returnVideosList {
    if (returnVideos == null || returnVideos!.isEmpty) return [];
    final list = <Map<String, dynamic>>[];
    returnVideos!.forEach((k, v) {
      if (v is Map) {
        final map = Map<String, dynamic>.from(v);
        if (!map.containsKey('videoId')) map['videoId'] = k;
        list.add(map);
      }
    });
    list.sort((a, b) {
      final tA = a['uploadedAt']?.toString() ?? '';
      final tB = b['uploadedAt']?.toString() ?? '';
      return tA.compareTo(tB);
    });
    return list;
  }

  Map<String, dynamic>? get customerReturnVideo {
    final list = returnVideosList;
    for (final v in list) {
      if ((v['uploaderRole']?.toString().toLowerCase() ?? '') == 'customer') {
        return v;
      }
    }
    return null;
  }

  Map<String, dynamic>? get employeeReturnVideo {
    final list = returnVideosList;
    for (final v in list) {
      if ((v['uploaderRole']?.toString().toLowerCase() ?? '') == 'employee') {
        return v;
      }
    }
    return null;
  }

  bool get hasCustomerReturnVideo => customerReturnVideo != null;
  bool get hasEmployeeReturnVideo => employeeReturnVideo != null;
  bool get hasAnyReturnVideo => returnVideosList.isNotEmpty;

  int get rentalDays {
    if (isOpenRental) return 1;
    if (returnDate == null) return 0;
    final diff = returnDate!.difference(pickUpDate).inDays;
    return diff <= 0 ? 1 : diff;
  }
}
