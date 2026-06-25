class PaymentModel {
  final String id;
  final String bookingId;
  final String userId;
  final double amount;
  final double depositAmount;
  final double balanceAmount;
  final String paymentMethod;
  final String status;
  final String? transactionId;
  final DateTime paymentDate;
  final DateTime? refundDate;

  // New fields for transaction receipt uploading & verification
  final String? receiptImage;
  final String? receiptFile;
  final String? paymentStatus;
  final String? customerUid;
  final String? uploadedAt;
  final String? verifiedAt;
  final String? verifiedBy;
  final String? rejectionReason;

  PaymentModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.amount,
    required this.depositAmount,
    required this.balanceAmount,
    required this.paymentMethod,
    required this.status,
    this.transactionId,
    required this.paymentDate,
    this.refundDate,
    this.receiptImage,
    this.receiptFile,
    this.paymentStatus,
    this.customerUid,
    this.uploadedAt,
    this.verifiedAt,
    this.verifiedBy,
    this.rejectionReason,
  });

  factory PaymentModel.fromMap(
    String id,
    Map<dynamic, dynamic> data,
  ) {
    final statusVal = data['paymentStatus'] ?? data['status'] ?? 'pending';
    final uidVal = data['customerUid'] ?? data['userId'] ?? '';
    return PaymentModel(
      id: id,
      bookingId: data['bookingId'] ?? '',
      userId: uidVal,
      amount: (data['amount'] ?? 0).toDouble(),
      depositAmount: (data['depositAmount'] ?? 0).toDouble(),
      balanceAmount: (data['balanceAmount'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      status: statusVal,
      transactionId: data['transactionId'],
      paymentDate: DateTime.parse(
        data['paymentDate'] ?? DateTime.now().toIso8601String(),
      ),
      refundDate: data['refundDate'] != null
          ? DateTime.parse(data['refundDate'])
          : null,
      receiptImage: data['receiptImage'] ?? data['receiptFile'],
      receiptFile: data['receiptFile'] ?? data['receiptImage'],
      paymentStatus: statusVal,
      customerUid: uidVal,
      uploadedAt: data['uploadedAt'],
      verifiedAt: data['verifiedAt'],
      verifiedBy: data['verifiedBy'],
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'customerUid': userId,
      'amount': amount,
      'depositAmount': depositAmount,
      'balanceAmount': balanceAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'paymentStatus': status,
      'transactionId': transactionId,
      'paymentDate': paymentDate.toIso8601String(),
      'refundDate': refundDate?.toIso8601String(),
      'receiptImage': receiptImage,
      'receiptFile': receiptFile,
      'uploadedAt': uploadedAt,
      'verifiedAt': verifiedAt,
      'verifiedBy': verifiedBy,
      'rejectionReason': rejectionReason,
    };
  }
}
