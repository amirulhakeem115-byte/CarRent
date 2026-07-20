class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String category;
  final String customerName;
  final String vehicleName;
  final String bookingId;
  final String paymentId;
  final String priority; // 'high', 'normal', 'low'
  final bool isRead;
  final DateTime createdAt;
  final String icon;
  final String color;
  final String relatedId;
  final String actionRoute;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.category = 'General',
    this.customerName = '',
    this.vehicleName = '',
    this.bookingId = '',
    this.paymentId = '',
    this.priority = 'normal',
    required this.isRead,
    required this.createdAt,
    this.icon = '⚙️',
    this.color = '0xFF64748B',
    this.relatedId = '',
    this.actionRoute = 'Dashboard',
  });

  factory NotificationModel.fromMap(String id, Map<dynamic, dynamic> data) {
    return NotificationModel(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      category: data['category'] ?? 'General',
      customerName: data['customerName'] ?? '',
      vehicleName: data['vehicleName'] ?? '',
      bookingId: data['bookingId'] ?? '',
      paymentId: data['paymentId'] ?? '',
      priority: data['priority'] ?? 'normal',
      isRead: data['isRead'] ?? false,
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      icon: data['icon'] ?? '⚙️',
      color: data['color'] ?? '0xFF64748B',
      relatedId: data['relatedId'] ?? '',
      actionRoute: data['actionRoute'] ?? 'Dashboard',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'category': category,
      'customerName': customerName,
      'vehicleName': vehicleName,
      'bookingId': bookingId,
      'paymentId': paymentId,
      'priority': priority,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'icon': icon,
      'color': color,
      'relatedId': relatedId,
      'actionRoute': actionRoute,
    };
  }
}
