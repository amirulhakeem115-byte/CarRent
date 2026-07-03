class AIMessage {
  final String id;
  final String role; // 'user', 'assistant', 'system'
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // extra data: vehicles list, bookingId, action, etc.

  AIMessage({
    required this.id,
    required this.role,
    required this.message,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AIMessage.fromMap(Map<String, dynamic> map) {
    return AIMessage(
      id: map['id'] ?? '',
      role: map['role'] ?? 'user',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
    );
  }

  AIMessage copyWith({
    String? id,
    String? role,
    String? message,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return AIMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}
