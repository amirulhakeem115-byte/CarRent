import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

/// A single event row shown in the vertical timeline, newest first.
class TrackingEvent {
  final String title;
  final String timestamp;
  final bool isActive; // true = the current/latest step (highlighted)

  const TrackingEvent({
    required this.title,
    required this.timestamp,
    this.isActive = false,
  });
}

/// Shopee-style booking tracker: a horizontal progress line with a moving
/// car icon (indicating "on the way" / in-progress), 4 stage labels above
/// it, and a vertical timeline of events below — newest event on top.
///
/// Usage:
///
///   BookingTrackingCard(
///     progress: 0.66, // 0.0 - 1.0 across the 4 stages
///     currentStageLabel: 'On the way',
///     stageLabels: const ['Booked', 'Confirmed', 'On the way', 'Returned'],
///     events: const [
///       TrackingEvent(title: 'Car is on the way for pickup', timestamp: 'Today, 9:42 AM', isActive: true),
///       TrackingEvent(title: 'Booking confirmed by branch', timestamp: 'Today, 8:15 AM'),
///       TrackingEvent(title: 'Payment received', timestamp: 'Yesterday, 6:03 PM'),
///     ],
///   )
class BookingTrackingCard extends StatefulWidget {
  final String vehicleName;
  final double progress;
  final String currentStageLabel;
  final List<String> stageLabels;
  final List<TrackingEvent> events;

  const BookingTrackingCard({
    super.key,
    required this.vehicleName,
    required this.progress,
    required this.currentStageLabel,
    required this.stageLabels,
    required this.events,
  });

  @override
  State<BookingTrackingCard> createState() => _BookingTrackingCardState();
}

class _BookingTrackingCardState extends State<BookingTrackingCard>
    with SingleTickerProviderStateMixin {
  static const Color _activeColor = Color(0xFF185FA5);
  static const Color _doneColor = Color(0xFF3B6D11);

  late final AnimationController _iconController;
  late final Animation<double> _iconOffset;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _iconOffset = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor =>
      _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor =>
      _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _borderColor =>
      _isDark ? const Color(0xFF334155) : AppColors.borderGray;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _liveHeader(),
          const SizedBox(height: 18),
          _progressLine(),
          const SizedBox(height: 8),
          _stageLabelsRow(),
          const SizedBox(height: 18),
          Divider(height: 1, color: _borderColor),
          const SizedBox(height: 14),
          ..._timelineRows(),
        ],
      ),
    );
  }

  Widget _liveHeader() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _iconController,
          builder: (context, child) {
            final t = _iconController.value;
            return Opacity(
              opacity: 0.5 + (0.5 * (1 - t)),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${widget.vehicleName} is ${widget.currentStageLabel.toLowerCase()}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _activeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressLine() {
    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final dotX = (width * widget.progress).clamp(10.0, width - 10.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 9,
                left: 0,
                right: 0,
                child: Container(height: 2, color: _borderColor),
              ),
              Positioned(
                top: 9,
                left: 0,
                width: dotX,
                child: Container(height: 2, color: _activeColor),
              ),
              AnimatedBuilder(
                animation: _iconOffset,
                builder: (context, child) {
                  return Positioned(
                    top: 0,
                    left: dotX - 10 + _iconOffset.value,
                    child: child!,
                  );
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: _activeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_filled,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stageLabelsRow() {
    final activeIndex = (widget.progress * (widget.stageLabels.length - 1))
        .round();
    return Row(
      children: List.generate(widget.stageLabels.length, (i) {
        final isDone = i < activeIndex;
        final isActive = i == activeIndex;
        final color = isActive
            ? _activeColor
            : (isDone ? _doneColor : _subColor.withValues(alpha: 0.7));
        return Expanded(
          child: Text(
            widget.stageLabels[i],
            textAlign: i == 0
                ? TextAlign.left
                : (i == widget.stageLabels.length - 1
                      ? TextAlign.right
                      : TextAlign.center),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _timelineRows() {
    return List.generate(widget.events.length, (i) {
      final e = widget.events[i];
      final isLast = i == widget.events.length - 1;
      final dotColor = e.isActive ? _activeColor : _doneColor;
      return Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1,
                        margin: const EdgeInsets.only(top: 4),
                        color: _borderColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: e.isActive
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: e.isActive ? _textColor : _subColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.timestamp,
                      style: TextStyle(
                        fontSize: 10,
                        color: _subColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
