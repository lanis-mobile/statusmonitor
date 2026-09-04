/// Result codes stored with each probe.
abstract final class CheckCode {
  static const ok = 0;
  static const timeout = 1;
  static const http = 2;
  static const auth = 3;
  static const error = 4;
}

enum MonitorStatus {
  operational,
  down,
  misconfigured;

  String get apiValue => name;
}

class CheckRecord {
  const CheckRecord({
    required this.ts,
    required this.ok,
    required this.ms,
    required this.code,
  });

  final int ts;
  final int ok;
  final int? ms;
  final int code;

  Map<String, Object?> toJson() => {'ts': ts, 'ok': ok, 'ms': ms, 'code': code};
}

class HolidayPeriod {
  const HolidayPeriod({
    required this.start,
    required this.end,
    required this.name,
    required this.label,
    this.slug,
    this.year,
  });

  final int start;
  final int end;
  final String name;
  final String label;
  final String? slug;
  final int? year;

  bool contains(int ts) => ts >= start && ts <= end;

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'name': name,
    'label': label,
  };
}

class WindowStats {
  const WindowStats({
    required this.uptime,
    required this.avgMs,
    required this.checks,
    required this.failures,
  });

  final double uptime;
  final int? avgMs;
  final int checks;
  final int failures;

  Map<String, Object?> toJson() => {
    'uptime': uptime,
    'avgMs': avgMs,
    'checks': checks,
    'failures': failures,
  };
}

class HistoryPoint {
  const HistoryPoint({required this.ts, required this.ms, required this.ok});

  final int ts;
  final int? ms;
  final int? ok;

  List<Object?> toJson() => [ts, ms, ok];
}

class IncidentSpan {
  const IncidentSpan({required this.start, required this.end});

  final int start;
  final int end;

  Map<String, Object?> toJson() => {'start': start, 'end': end};
}

abstract final class HistoryWindows {
  static const ids = ['24h', '7d', '30d', '90d', '180d', '1y', '2y'];

  static const durations = {
    '24h': 24 * 3600,
    '7d': 7 * 24 * 3600,
    '30d': 30 * 24 * 3600,
    '90d': 90 * 24 * 3600,
    '180d': 180 * 24 * 3600,
    '1y': 365 * 24 * 3600,
    '2y': 2 * 365 * 24 * 3600,
  };

  static const bucketSeconds = {
    '24h': 60,
    '7d': 5 * 60,
    '30d': 3600,
    '90d': 2 * 3600,
    '180d': 4 * 3600,
    '1y': 6 * 3600,
    '2y': 6 * 3600,
  };

  static int? durationOf(String id) => durations[id];

  static int? bucketOf(String id) => bucketSeconds[id];
}
