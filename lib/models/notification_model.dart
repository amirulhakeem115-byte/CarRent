class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
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
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'icon': icon,
      'color': color,
      'relatedId': relatedId,
      'actionRoute': actionRoute,
    };
  }
}
