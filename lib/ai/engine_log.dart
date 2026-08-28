class EngineLogEntry {
  final DateTime time;
  final String source;
  final String summary;
  final String? detail;
  final Duration? elapsed;
  final bool isError;

  EngineLogEntry({
    required this.source,
    required this.summary,
    this.detail,
    this.elapsed,
    this.isError = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  String get clock {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  String get headline {
    final extras = <String>[
      if (elapsed != null) formatEngineDuration(elapsed!),
    ];
    if (extras.isEmpty) {
      return summary;
    }
    return '$summary  (${extras.join(', ')})';
  }
}

typedef EngineLogSink = void Function(EngineLogEntry entry);

String formatEngineDuration(Duration duration) {
  if (duration.inMilliseconds < 1000) {
    return '${duration.inMilliseconds}ms';
  }
  final seconds = duration.inMilliseconds / 1000;
  if (seconds < 10) {
    return '${seconds.toStringAsFixed(2)}s';
  }
  return '${seconds.toStringAsFixed(1)}s';
}

Duration? durationFromNanos(dynamic value) {
  if (value is num) {
    return Duration(microseconds: (value / 1000).round());
  }
  return null;
}

String? tokensPerSecond(int? count, Duration? duration) {
  if (count == null || duration == null || duration.inMicroseconds == 0) {
    return null;
  }
  final rate = count / (duration.inMicroseconds / 1e6);
  return '${rate.toStringAsFixed(1)} tok/s';
}
