import 'dart:convert';
import 'dart:io';

import 'clock.dart';
import 'config.dart';
import 'database.dart';
import 'models.dart';

const holidayUserAgent = 'lanis-mobile-statusmonitor/1.0';
const holidayApiBase = 'https://schulferien-api.de/api/v1';

class HolidayService {
  HolidayService({
    required this.db,
    required this.config,
    required this.clock,
    HttpClient? httpClient,
  }) : _http = httpClient;

  final StatusDatabase db;
  final AppConfig config;
  final Clock clock;
  final HttpClient? _http;

  bool get needsRefresh {
    final updated = db.holidaysUpdatedAt();
    if (updated == null) return true;
    return clock.nowSeconds - updated >= config.holidayTtl.inSeconds;
  }

  Future<void> refreshIfNeeded() async {
    if (config.isFixture) return;
    if (!needsRefresh) return;
    try {
      await refresh();
    } catch (error, stack) {
      stderr.writeln('Holiday refresh failed, keeping last snapshot: $error');
      stderr.writeln(stack);
    }
  }

  Future<void> refresh() async {
    final now = clock.nowUtc;
    final years = [for (var y = now.year - 2; y <= now.year + 1; y++) y];
    final periods = <HolidayPeriod>[];
    for (final year in years) {
      periods.addAll(await _fetchYear(year));
    }
    if (periods.isEmpty && db.holidays().isNotEmpty) return;
    db.replaceHolidays(periods, clock.nowSeconds);
  }

  Future<List<HolidayPeriod>> _fetchYear(int year) async {
    final uri = Uri.parse('$holidayApiBase/$year/HE');
    final client = _http ?? HttpClient();
    final owned = _http == null;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, holidayUserAgent);
      final response = await request.close();
      if (response.statusCode != 200) {
        stderr.writeln('Holiday API $uri returned ${response.statusCode}');
        return const [];
      }
      final body = await utf8.decodeStream(response);
      final list = jsonDecode(body) as List<dynamic>;
      return [
        for (final item in list)
          _periodFromUpstream(item as Map<String, dynamic>),
      ];
    } finally {
      if (owned) client.close(force: true);
    }
  }

  HolidayPeriod _periodFromUpstream(Map<String, dynamic> item) {
    final start = DateTime.parse(item['start'] as String).toUtc();
    final end = DateTime.parse(item['end'] as String).toUtc();
    return HolidayPeriod(
      start: start.millisecondsSinceEpoch ~/ 1000,
      end: end.millisecondsSinceEpoch ~/ 1000,
      name: item['name'] as String,
      label: (item['name_cp'] as String?) ?? (item['name'] as String),
      slug: item['slug'] as String?,
      year: item['year'] as int?,
    );
  }
}
