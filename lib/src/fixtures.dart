import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'database.dart';
import 'models.dart';

/// Pinned clock used by committed fixtures and CI.
const fixtureNow = 1784116800; // 2026-07-15T12:00:00Z

class FixtureSet {
  const FixtureSet({
    required this.now,
    required this.checks,
    required this.holidays,
    required this.updatedAt,
  });

  final int now;
  final List<CheckRecord> checks;
  final List<HolidayPeriod> holidays;
  final int updatedAt;
}

FixtureSet loadFixtures(String dir) {
  final checksFile = File(p.join(dir, 'checks.json'));
  final holidaysFile = File(p.join(dir, 'holidays.json'));
  if (!checksFile.existsSync() || !holidaysFile.existsSync()) {
    throw StateError('Fixture files missing in $dir');
  }
  final checksJson =
      jsonDecode(checksFile.readAsStringSync()) as Map<String, dynamic>;
  final holidaysJson =
      jsonDecode(holidaysFile.readAsStringSync()) as Map<String, dynamic>;
  final checks = [
    for (final row in checksJson['checks'] as List<dynamic>)
      CheckRecord(
        ts: row[0] as int,
        ok: row[1] as int,
        ms: row[2] as int?,
        code: row[3] as int,
      ),
  ];
  final holidays = [
    for (final row in holidaysJson['periods'] as List<dynamic>)
      HolidayPeriod(
        start: row['start'] as int,
        end: row['end'] as int,
        name: row['name'] as String,
        label: row['label'] as String,
        slug: row['slug'] as String?,
        year: row['year'] as int?,
      ),
  ];
  return FixtureSet(
    now: checksJson['now'] as int,
    checks: checks,
    holidays: holidays,
    updatedAt: holidaysJson['updatedAt'] as int,
  );
}

void seedDatabase(StatusDatabase db, FixtureSet fixtures) {
  db.insertChecks(fixtures.checks);
  db.replaceHolidays(fixtures.holidays, fixtures.updatedAt);
}

int _stableMs(int ts) {
  final x = (ts * 1103515245 + 12345) & 0x7fffffff;
  return 180 + (x % 221);
}

/// Deterministic series used to generate [test/fixtures].
FixtureSet generateFixtureSet({int now = fixtureNow}) {
  final outageEnd = now - 2 * 3600;
  final outageStart = outageEnd - 30 * 60;
  final oldOutageEnd = now - 14 * 86400;
  final oldOutageStart = oldOutageEnd - 3 * 3600;

  bool inOutage(int ts) =>
      (ts >= outageStart && ts < outageEnd) ||
      (ts >= oldOutageStart && ts < oldOutageEnd);

  final checks = <CheckRecord>[];
  final seen = <int>{};

  void addPoint(int ts) {
    if (!seen.add(ts)) return;
    if (inOutage(ts)) {
      checks.add(CheckRecord(ts: ts, ok: 0, ms: null, code: CheckCode.timeout));
    } else {
      checks.add(
        CheckRecord(ts: ts, ok: 1, ms: _stableMs(ts), code: CheckCode.ok),
      );
    }
  }

  final twoYears = 2 * 365 * 86400;
  for (var ts = now - twoYears; ts < now - 30 * 86400; ts += 6 * 3600) {
    addPoint(ts);
  }
  for (var ts = now - 30 * 86400; ts < now - 7 * 86400; ts += 3600) {
    addPoint(ts);
  }
  for (var ts = now - 7 * 86400; ts < now - 86400; ts += 5 * 60) {
    addPoint(ts);
  }
  for (var ts = now - 86400; ts <= now; ts += 60) {
    addPoint(ts);
  }

  checks.sort((a, b) => a.ts.compareTo(b.ts));

  int utc(int year, int month, int day, [int hour = 0, int minute = 0]) {
    return DateTime.utc(
          year,
          month,
          day,
          hour,
          minute,
        ).millisecondsSinceEpoch ~/
        1000;
  }

  final holidays = [
    HolidayPeriod(
      start: utc(2025, 4, 7),
      end: utc(2025, 4, 21, 23, 59),
      name: 'osterferien',
      label: 'Osterferien',
      slug: 'osterferien-2025-HE',
      year: 2025,
    ),
    HolidayPeriod(
      start: utc(2025, 10, 6),
      end: utc(2025, 10, 18, 23, 59),
      name: 'herbstferien',
      label: 'Herbstferien',
      slug: 'herbstferien-2025-HE',
      year: 2025,
    ),
    HolidayPeriod(
      start: utc(2026, 3, 30),
      end: utc(2026, 4, 10, 23, 59),
      name: 'osterferien',
      label: 'Osterferien',
      slug: 'osterferien-2026-HE',
      year: 2026,
    ),
    HolidayPeriod(
      start: utc(2026, 6, 29),
      end: utc(2026, 8, 7, 23, 59),
      name: 'sommerferien',
      label: 'Sommerferien',
      slug: 'sommerferien-2026-HE',
      year: 2026,
    ),
  ];

  return FixtureSet(
    now: now,
    checks: checks,
    holidays: holidays,
    updatedAt: now,
  );
}

void writeFixtureFiles(String dir, FixtureSet fixtures) {
  Directory(dir).createSync(recursive: true);
  File(p.join(dir, 'checks.json')).writeAsStringSync(
    jsonEncode({
      'now': fixtures.now,
      'checks': [
        for (final c in fixtures.checks) [c.ts, c.ok, c.ms, c.code],
      ],
    }),
  );
  File(p.join(dir, 'holidays.json')).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'updatedAt': fixtures.updatedAt,
      'periods': [
        for (final h in fixtures.holidays)
          {
            'start': h.start,
            'end': h.end,
            'name': h.name,
            'label': h.label,
            'slug': h.slug,
            'year': h.year,
          },
      ],
    }),
  );
}
