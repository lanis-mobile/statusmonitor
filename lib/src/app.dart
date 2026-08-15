import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'cache_headers.dart';
import 'clock.dart';
import 'config.dart';
import 'database.dart';
import 'models.dart';

class StatusApp {
  StatusApp({required this.db, required this.config, required this.clock});

  final StatusDatabase db;
  final AppConfig config;
  final Clock clock;

  Handler get handler {
    final router = Router()
      ..get('/api/status', _status)
      ..get('/api/summary', _summary)
      ..get('/api/history/<window>', _history)
      ..get('/api/holidays', _holidays);

    Handler staticHandler;
    final staticDir = Directory(config.staticDir);
    if (staticDir.existsSync()) {
      staticHandler = createStaticHandler(
        config.staticDir,
        defaultDocument: 'index.html',
      );
    } else {
      staticHandler = (Request request) {
        if (request.url.path.isEmpty || request.url.path == 'index.html') {
          return Response.ok(
            '<!doctype html><title>Statusmonitor</title>',
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return Response.notFound('Not found');
      };
    }

    final cascade = Cascade().add(router.call).add(staticHandler).handler;
    return Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(cacheHeadersMiddleware())
        .addHandler(cascade);
  }

  Response _json(Object body, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Map<String, Object?> _statusPayload() {
    final latest = db.latestCheck();
    final now = clock.nowSeconds;
    HolidayPeriod? currentHoliday;
    for (final holiday in db.holidays()) {
      if (holiday.contains(now)) {
        currentHoliday = holiday;
        break;
      }
    }

    final MonitorStatus status;
    if (latest == null) {
      status = MonitorStatus.down;
    } else if (latest.code == CheckCode.auth) {
      status = MonitorStatus.misconfigured;
    } else if (latest.ok == 1) {
      status = MonitorStatus.operational;
    } else {
      status = MonitorStatus.down;
    }

    return {
      'online': status == MonitorStatus.operational,
      'status': status.apiValue,
      'checkedAt': latest?.ts,
      'responseMs': latest?.ms,
      'code': latest?.code,
      'inHolidays': currentHoliday != null,
      'holidayLabel': currentHoliday?.label,
    };
  }

  Response _status(Request request) => _json(_statusPayload());

  Response _summary(Request request) {
    final now = clock.nowSeconds;
    final windows = <String, Object?>{};
    for (final id in HistoryWindows.ids) {
      final duration = HistoryWindows.durationOf(id)!;
      windows[id] = db.statsInRange(now - duration, now).toJson();
    }
    return _json({'current': _statusPayload(), 'windows': windows});
  }

  Response _history(Request request, String window) {
    final duration = HistoryWindows.durationOf(window);
    final bucket = HistoryWindows.bucketOf(window);
    if (duration == null || bucket == null) {
      return _json({'error': 'unknown window'}, status: 404);
    }
    final now = clock.nowSeconds;
    final from = now - duration;
    final points = db.bucketedHistory(
      from: from,
      to: now,
      bucketSeconds: bucket,
    );
    return _json({
      'window': window,
      'bucketSeconds': bucket,
      'from': from,
      'to': now,
      'points': [for (final p in points) p.toJson()],
    });
  }

  Response _holidays(Request request) {
    final now = clock.nowSeconds;
    final from = now - HistoryWindows.durationOf('2y')!;
    final to = now + 365 * 86400;
    return _json({
      'state': 'HE',
      'updatedAt': db.holidaysUpdatedAt(),
      'periods': [for (final h in db.holidays(from: from, to: to)) h.toJson()],
    });
  }
}
