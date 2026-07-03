import 'package:web/web.dart' as web;

void playNotificationChime() {
  final audioCtx = web.AudioContext();
  _playTone(audioCtx, 880, 0.1, 0.0, 0.08);
  _playTone(audioCtx, 1200, 0.25, 0.08, 0.001);
}

void _playTone(
  web.AudioContext ctx,
  double frequency,
  double duration,
  double delay,
  double initialGain,
) {
  final osc = ctx.createOscillator();
  final gainNode = ctx.createGain();

  osc.connect(gainNode);
  gainNode.connect(ctx.destination);

  osc.frequency.value = frequency;
  osc.type = 'sine';

  final startTime = ctx.currentTime + delay;
  final endTime = startTime + duration;

  gainNode.gain.setValueAtTime(initialGain, startTime);
  gainNode.gain.exponentialRampToValueAtTime(0.001, endTime);

  osc.start(startTime);
  osc.stop(endTime);
}
