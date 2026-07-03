abstract class AIIntent {
  final String intentName;
  final double confidence;
  final Map<String, dynamic> parameters;

  const AIIntent({
    required this.intentName,
    required this.confidence,
    this.parameters = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'intentName': intentName,
      'confidence': confidence,
      'parameters': parameters,
    };
  }
}

class NavigationIntent extends AIIntent {
  const NavigationIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'NavigationIntent');
}

class BookingIntent extends AIIntent {
  const BookingIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'BookingIntent');
}

class VehicleSearchIntent extends AIIntent {
  const VehicleSearchIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'VehicleSearchIntent');
}

class RewardIntent extends AIIntent {
  const RewardIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'RewardIntent');
}

class ReceiptIntent extends AIIntent {
  const ReceiptIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'ReceiptIntent');
}

class SupportIntent extends AIIntent {
  const SupportIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'SupportIntent');
}

class ProfileIntent extends AIIntent {
  const ProfileIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'ProfileIntent');
}

class HistoryIntent extends AIIntent {
  const HistoryIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'HistoryIntent');
}

class NotificationIntent extends AIIntent {
  const NotificationIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'NotificationIntent');
}

class BranchIntent extends AIIntent {
  const BranchIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'BranchIntent');
}

class DashboardIntent extends AIIntent {
  const DashboardIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'DashboardIntent');
}

class PaymentIntent extends AIIntent {
  const PaymentIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'PaymentIntent');
}

class MaintenanceIntent extends AIIntent {
  const MaintenanceIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'MaintenanceIntent');
}

class ReportIntent extends AIIntent {
  const ReportIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'ReportIntent');
}

class CustomerIntent extends AIIntent {
  const CustomerIntent({
    required super.confidence,
    super.parameters = const {},
  }) : super(intentName: 'CustomerIntent');
}

class UnknownIntent extends AIIntent {
  const UnknownIntent({
    super.confidence = 0.0,
    super.parameters = const {},
  }) : super(intentName: 'UnknownIntent');
}
