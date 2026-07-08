import '../models/ai_message.dart';
import '../models/ai_intent.dart';
import '../models/ai_response.dart';

abstract class AIProvider {
  Future<AIResponse> sendMessage(String text, List<AIMessage> history, {required String userRole});
  Future<AIIntent> detectIntent(String text);
}
