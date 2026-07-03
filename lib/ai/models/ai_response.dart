import 'ai_intent.dart';

class AIResponse {
  final String message;
  final AIIntent intent;
  final double confidence;
  final String action;
  final Map<String, dynamic> parameters;

  AIResponse({
    required this.message,
    required this.intent,
    required this.confidence,
    required this.action,
    required this.parameters,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'intent': intent.toMap(),
      'confidence': confidence,
      'action': action,
      'parameters': parameters,
    };
  }
}
