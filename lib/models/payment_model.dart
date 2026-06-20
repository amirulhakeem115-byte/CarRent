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
  });

  factory PaymentModel.fromMap(
    String id,
    Map<dynamic, dynamic> data,
  ) {
    return PaymentModel(
      id: id,
      bookingId: data['bookingId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      depositAmount: (data['depositAmount'] ?? 0).toDouble(),
      balanceAmount: (data['balanceAmount'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      status: data['status'] ?? 'pending',
      transactionId: data['transactionId'],
      paymentDate: DateTime.parse(
        data['paymentDate'] ?? DateTime.now().toIso8601String(),
      ),
      refundDate: data['refundDate'] != null
          ? DateTime.parse(data['refundDate'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'amount': amount,
      'depositAmount': depositAmount,
      'balanceAmount': balanceAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'transactionId': transactionId,
      'paymentDate': paymentDate.toIso8601String(),
      'refundDate': refundDate?.toIso8601String(),
    };
  }
}
