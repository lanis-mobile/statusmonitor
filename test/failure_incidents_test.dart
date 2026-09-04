import 'package:statusmonitor/statusmonitor.dart';
import 'package:test/test.dart';

CheckRecord _fail(int ts, {int code = CheckCode.timeout, int? ms}) =>
    CheckRecord(ts: ts, ok: 0, ms: ms, code: code);

CheckRecord _ok(int ts, {int ms = 200}) =>
    CheckRecord(ts: ts, ok: 1, ms: ms, code: CheckCode.ok);

void main() {
  late StatusDatabase db;

  setUp(() {
    db = StatusDatabase.open(':memory:');
  });

  tearDown(() => db.dispose());

  group('IncidentSpan', () {
    test('toJson exposes only start and end', () {
      expect(const IncidentSpan(start: 10, end: 70).toJson(), {
        'start': 10,
        'end': 70,
      });
    });
  });

  group('failureIncidents empty and all-up', () {
    test('returns nothing when there are no checks', () {
      expect(db.failureIncidents(from: 0, to: 1000), isEmpty);
    });

    test('returns nothing when every check succeeded', () {
      db.insertChecks([_ok(1000), _ok(1060), _ok(1120)]);
      expect(db.failureIncidents(from: 0, to: 2000), isEmpty);
    });
  });

  group('failureIncidents span boundaries', () {
    test('a single failed check until the next success is one minute', () {
      db.insertChecks([_fail(1000), _ok(1060)]);
      final incidents = db.failureIncidents(from: 0, to: 2000);
      expect(incidents.length, 1);
      expect(incidents.single.start, 1000);
      expect(incidents.single.end, 1060);
      expect(incidents.single.end - incidents.single.start, 60);
    });

    test('consecutive failures stay one span until the first success', () {
      db.insertChecks([
        _fail(1000),
        _fail(1060),
        _fail(1120),
        _ok(1180),
      ]);
      final incidents = db.failureIncidents(from: 0, to: 2000);
      expect(incidents.length, 1);
      expect(incidents.single.start, 1000);
      expect(incidents.single.end, 1180);
      expect(incidents.single.end - incidents.single.start, 180);
    });

    test('leading successes are ignored', () {
      db.insertChecks([_ok(1000), _ok(1060), _fail(1120), _ok(1180)]);
      final incidents = db.failureIncidents(from: 0, to: 2000);
      expect(incidents.single.start, 1120);
      expect(incidents.single.end, 1180);
    });

    test('trailing successes after recovery are ignored', () {
      db.insertChecks([_fail(1000), _ok(1060), _ok(1120), _ok(1180)]);
      expect(db.failureIncidents(from: 0, to: 2000).length, 1);
    });

    test('an unresolved outage ends at last failure plus probe interval', () {
      db.insertChecks([_fail(1000), _fail(1060), _fail(1120)]);
      final incidents = db.failureIncidents(from: 0, to: 2000);
      expect(incidents.single.start, 1000);
      expect(incidents.single.end, 1180);
    });

    test('custom probe interval is used only for unresolved outages', () {
      db.insertChecks([_fail(1000), _ok(1060), _fail(2000)]);
      final incidents = db.failureIncidents(
        from: 0,
        to: 3000,
        probeIntervalSeconds: 300,
      );
      expect(incidents[0].end, 1060);
      expect(incidents[1].start, 2000);
      expect(incidents[1].end, 2300);
    });
  });

  group('failureIncidents does not merge distinct outages', () {
    test('a successful check between failures splits spans', () {
      db.insertChecks([
        _fail(1000),
        _ok(1060),
        _fail(1240),
        _fail(1300),
        _fail(1360),
        _ok(1420),
      ]);
      final incidents = db.failureIncidents(from: 0, to: 2000);
      expect(incidents.length, 2);
      expect(incidents[0].start, 1000);
      expect(incidents[0].end, 1060);
      expect(incidents[1].start, 1240);
      expect(incidents[1].end, 1420);
    });

    test('production 15:26 and 15:31 outages stay separate', () {
      db.insertChecks([
        _fail(1_788_182_760, code: CheckCode.http, ms: 530),
        _ok(1_788_182_820),
        _fail(1_788_183_060),
        _fail(1_788_183_120),
        _fail(1_788_183_180),
        _fail(1_788_183_240),
        _fail(1_788_183_300),
        _fail(1_788_183_360),
        _ok(1_788_183_420),
        _fail(1_788_191_220),
        _ok(1_788_191_280),
      ]);

      final incidents = db.failureIncidents(from: 0, to: 2_000_000_000);
      expect(incidents.length, 3);
      expect(incidents[0].end - incidents[0].start, 60);
      expect(incidents[1].end - incidents[1].start, 360);
      expect(incidents[2].end - incidents[2].start, 60);
    });

    test('a one-minute outage older than 24h is still 60 seconds', () {
      const now = 1_788_264_000;
      const old = now - 10 * 86400;
      db.insertChecks([
        _ok(old - 60),
        _fail(old),
        _ok(old + 60),
        _ok(now),
      ]);
      final incidents = db.failureIncidents(from: now - 30 * 86400, to: now);
      expect(incidents.single.end - incidents.single.start, 60);
    });
  });

  group('failureIncidents failure codes', () {
    test('timeout, http, auth, and error all count as down', () {
      db.insertChecks([
        _fail(1000, code: CheckCode.timeout),
        _ok(1060),
        _fail(2000, code: CheckCode.http),
        _ok(2060),
        _fail(3000, code: CheckCode.auth),
        _ok(3060),
        _fail(4000, code: CheckCode.error),
        _ok(4060),
      ]);
      final incidents = db.failureIncidents(from: 0, to: 5000);
      expect(incidents.map((i) => i.start), [1000, 2000, 3000, 4000]);
    });

    test('mixed failure codes in one stretch stay one incident', () {
      db.insertChecks([
        _fail(1000, code: CheckCode.timeout),
        _fail(1060, code: CheckCode.http),
        _fail(1120, code: CheckCode.error),
        _ok(1180),
      ]);
      expect(db.failureIncidents(from: 0, to: 2000).length, 1);
    });
  });

  group('failureIncidents range clipping', () {
    test('excludes outages entirely before from', () {
      db.insertChecks([_fail(1000), _ok(1060), _fail(5000), _ok(5060)]);
      final incidents = db.failureIncidents(from: 4000, to: 6000);
      expect(incidents.length, 1);
      expect(incidents.single.start, 5000);
    });

    test('excludes outages entirely after to', () {
      db.insertChecks([_fail(1000), _ok(1060), _fail(5000), _ok(5060)]);
      final incidents = db.failureIncidents(from: 0, to: 2000);
      expect(incidents.length, 1);
      expect(incidents.single.start, 1000);
    });

    test('includes a failure exactly at from', () {
      db.insertChecks([_fail(1000), _ok(1060)]);
      expect(db.failureIncidents(from: 1000, to: 2000).single.start, 1000);
    });

    test('includes a failure exactly at to', () {
      db.insertChecks([_ok(1000), _fail(2000)]);
      final incidents = db.failureIncidents(from: 0, to: 2000);
      expect(incidents.single.start, 2000);
      expect(incidents.single.end, 2060);
    });

    test('an outage that started before from begins at the first in-range failure', () {
      db.insertChecks([_fail(1000), _fail(1060), _fail(1120), _ok(1180)]);
      final incidents = db.failureIncidents(from: 1060, to: 2000);
      expect(incidents.single.start, 1060);
      expect(incidents.single.end, 1180);
    });

    test('an outage whose recovery is after to is treated as unresolved', () {
      db.insertChecks([_fail(1000), _fail(1060), _ok(2000)]);
      final incidents = db.failureIncidents(from: 0, to: 1500);
      expect(incidents.single.start, 1000);
      expect(incidents.single.end, 1120);
    });

    test('a recovered outage that ends exactly at to is closed at that success', () {
      db.insertChecks([_fail(1000), _ok(1060)]);
      expect(db.failureIncidents(from: 0, to: 1060).single.end, 1060);
    });
  });

  group('failureIncidents ordering', () {
    test('returns spans in chronological order', () {
      db.insertChecks([
        _fail(3000),
        _ok(3060),
        _fail(1000),
        _ok(1060),
        _fail(2000),
        _ok(2060),
      ]);
      expect(
        db.failureIncidents(from: 0, to: 4000).map((i) => i.start),
        [1000, 2000, 3000],
      );
    });
  });
}
