import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:statusmonitor/statusmonitor.dart';
import 'package:test/test.dart';

void main() {
  late StatusDatabase db;
  late StatusApp app;
  late Handler handler;
  late FixtureSet fixtures;
  late Directory staticDir;

  setUp(() {
    fixtures = loadFixtures('test/fixtures');
    db = StatusDatabase.open(':memory:');
    seedDatabase(db, fixtures);
    staticDir = Directory.systemTemp.createTempSync('statusmonitor-static-');
    File(
      '${staticDir.path}/index.html',
    ).writeAsStringSync('<!doctype html><title>Statusmonitor</title>');
    final config = AppConfig(
      mode: AppMode.fixture,
      port: 0,
      databasePath: ':memory:',
      staticDir: staticDir.path,
      schoolId: 0,
      username: 'fixture',
      password: 'fixture',
      now: fixtures.now,
      fixtureDir: 'test/fixtures',
    );
    app = StatusApp(
      db: db,
      config: config,
      clock: Clock(fixedNow: fixtures.now),
    );
    handler = app.handler;
  });

  tearDown(() {
    db.dispose();
    staticDir.deleteSync(recursive: true);
  });

  Future<Response> get(String path) async {
    return handler(Request('GET', Uri.parse('http://localhost$path')));
  }

  Future<Map<String, dynamic>> jsonBody(Response response) async {
    return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  }

  void expectCacheHeaders(Response response) {
    expect(response.headers['cache-control'], contains('max-age=30'));
    expect(response.headers['cdn-cache-control'], 'max-age=30');
    expect(response.headers['cloudflare-cdn-cache-control'], 'max-age=30');
  }

  test('API and static responses send 30s cache headers', () async {
    final status = await get('/api/status');
    expectCacheHeaders(status);
    final page = await get('/');
    expect(page.statusCode, 200);
    expectCacheHeaders(page);
  });

  test('/api/status matches the latest fixture check', () async {
    final response = await get('/api/status');
    expect(response.statusCode, 200);
    final body = await jsonBody(response);
    final latest = fixtures.checks.last;
    expect(body['online'], isTrue);
    expect(body['status'], 'operational');
    expect(body['checkedAt'], latest.ts);
    expect(body['responseMs'], latest.ms);
    expect(body['code'], CheckCode.ok);
    expect(body['inHolidays'], isTrue);
    expect(body['holidayLabel'], 'Sommerferien');
  });

  test('/api/summary 24h uptime matches the known outage', () async {
    final response = await get('/api/summary');
    expect(response.statusCode, 200);
    final body = await jsonBody(response);
    final window = body['windows']['24h'] as Map<String, dynamic>;
    final from = fixtures.now - HistoryWindows.durationOf('24h')!;
    final inWindow = fixtures.checks.where(
      (c) => c.ts >= from && c.ts <= fixtures.now,
    );
    final failures = inWindow.where((c) => c.ok == 0).length;
    final total = inWindow.length;
    final expected = ((total - failures) / total) * 100.0;
    expect(window['checks'], total);
    expect(window['failures'], failures);
    expect(window['failures'], 30);
    expect((window['uptime'] as num).toDouble(), closeTo(expected, 0.1));
  });

  test('/api/history windows contain the outage dip', () async {
    for (final id in HistoryWindows.ids) {
      final response = await get('/api/history/$id');
      expect(response.statusCode, 200, reason: id);
      final body = await jsonBody(response);
      expect(body['window'], id);
      final points = (body['points'] as List<dynamic>)
          .map((e) => e as List<dynamic>)
          .toList();
      expect(points, isNotEmpty, reason: id);
      expect(points.first[0], lessThanOrEqualTo(fixtures.now));
      expect(points.last[0], lessThanOrEqualTo(fixtures.now));
      expect(
        points.any((p) => p[2] == 0),
        isTrue,
        reason: '$id should include an outage',
      );
    }
  });

  test('/api/holidays includes the period covering NOW', () async {
    final response = await get('/api/holidays');
    expect(response.statusCode, 200);
    final body = await jsonBody(response);
    expect(body['state'], 'HE');
    final periods = (body['periods'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(periods, isNotEmpty);
    expect(
      periods.any(
        (p) =>
            p['label'] == 'Sommerferien' &&
            (p['start'] as int) <= fixtures.now &&
            (p['end'] as int) >= fixtures.now,
      ),
      isTrue,
    );
  });

  test('unknown history window is 404', () async {
    final response = await get('/api/history/1h');
    expect(response.statusCode, 404);
  });
}
