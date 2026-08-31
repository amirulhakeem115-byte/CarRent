import 'package:flutter/material.dart';

/// Compact badge indicating the source of a booking.
/// Sources:
/// - system (Blue, Laptop Icon: "System App")
/// - whatsapp (Green, Chat Icon: "WhatsApp")
/// - phone (Orange, Phone Icon: "Phone Call")
/// - walkIn (Purple, Walk Icon: "Walk-in")
class BookingSourceBadge extends StatelessWidget {
  final String bookingSource;
  final bool compact;

  const BookingSourceBadge({
    super.key,
    required this.bookingSource,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = bookingSource.toLowerCase().trim();
    String label = 'System App';
    IconData icon = Icons.devices_rounded;
    Color color = const Color(0xFF3B82F6); // Blue

    if (s == 'phone' || s == 'phone call' || s == 'phone_call') {
      label = 'Phone Call';
      icon = Icons.phone_in_talk_rounded;
      color = const Color(0xFFF59E0B); // Amber / Orange
    } else if (s == 'walkin' || s == 'walk_in' || s == 'walk-in') {
      label = 'Walk-in';
      icon = Icons.directions_walk_rounded;
      color = const Color(0xFF8B5CF6); // Purple
    } else if (s == 'whatsapp' || s == 'wa') {
      label = 'WhatsApp';
      icon = Icons.chat_rounded;
      color = const Color(0xFF10B981); // Emerald Green
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
