import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

class StatusDatabase {
  StatusDatabase._(this._db);

  final Database _db;
  int _lastMaintenanceDay = 0;

  static StatusDatabase open(String path) {
    if (path != ':memory:') {
      final file = File(path);
      file.parent.createSync(recursive: true);
    }
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('PRAGMA synchronous=NORMAL;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS checks (
        ts INTEGER PRIMARY KEY,
        ok INTEGER NOT NULL,
        ms INTEGER,
        code INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS holidays (
        slug TEXT PRIMARY KEY,
        start_ts INTEGER NOT NULL,
        end_ts INTEGER NOT NULL,
        name TEXT NOT NULL,
        name_cp TEXT NOT NULL,
        year INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS holidays_meta (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        updated_at INTEGER NOT NULL
      );
    ''');
    return StatusDatabase._(db);
  }

  void insertCheck(CheckRecord record) {
    _db.execute(
      'INSERT OR REPLACE INTO checks (ts, ok, ms, code) VALUES (?, ?, ?, ?)',
      [record.ts, record.ok, record.ms, record.code],
    );
  }

  void insertChecks(Iterable<CheckRecord> records) {
    final stmt = _db.prepare(
      'INSERT OR REPLACE INTO checks (ts, ok, ms, code) VALUES (?, ?, ?, ?)',
    );
    try {
      _db.execute('BEGIN');
      for (final record in records) {
        stmt.execute([record.ts, record.ok, record.ms, record.code]);
      }
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      stmt.close();
    }
  }

  CheckRecord? latestCheck() {
    final rows = _db.select(
      'SELECT ts, ok, ms, code FROM checks ORDER BY ts DESC LIMIT 1',
    );
    if (rows.isEmpty) return null;
    return _checkFromRow(rows.first);
  }

  List<CheckRecord> checksInRange(int from, int to) {
    final rows = _db.select(
      'SELECT ts, ok, ms, code FROM checks WHERE ts >= ? AND ts <= ? ORDER BY ts',
      [from, to],
    );
    return [for (final row in rows) _checkFromRow(row)];
  }

  /// Contiguous failure spans from first failed check until the next success.
  /// Isolated single-probe blips are omitted; a span needs two or more fails.
  List<IncidentSpan> failureIncidents({
    required int from,
    required int to,
    int probeIntervalSeconds = 60,
  }) {
    final checks = checksInRange(from, to);
    if (checks.isEmpty) return [];

    final incidents = <IncidentSpan>[];
    int? start;
    int? lastFailureTs;

    void closeIncident(int end) {
      if (start == null || lastFailureTs == null) return;
      if (lastFailureTs! > start!) {
        incidents.add(IncidentSpan(start: start!, end: end));
      }
      start = null;
      lastFailureTs = null;
    }

    for (final check in checks) {
      if (check.ok == 0) {
        start ??= check.ts;
        lastFailureTs = check.ts;
      } else if (start != null) {
        closeIncident(check.ts);
      }
    }

    if (start != null) {
      closeIncident(lastFailureTs! + probeIntervalSeconds);
    }
    return incidents;
  }

  WindowStats statsInRange(int from, int to) {
    final row = _db
        .select(
          '''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN ok = 0 THEN 1 ELSE 0 END) AS failures,
        AVG(ms) AS avg_ms
      FROM checks
      WHERE ts >= ? AND ts <= ?
      ''',
          [from, to],
        )
        .first;
    final total = row['total'] as int;
    final failures = (row['failures'] as int?) ?? 0;
    final avg = row['avg_ms'];
    final uptime = total == 0 ? 100.0 : ((total - failures) / total) * 100.0;
    return WindowStats(
      uptime: double.parse(uptime.toStringAsFixed(3)),
      avgMs: avg == null ? null : (avg as num).round(),
      checks: total,
      failures: failures,
    );
  }

  List<HistoryPoint> bucketedHistory({
    required int from,
    required int to,
    required int bucketSeconds,
  }) {
    final alignedFrom = from - (from % bucketSeconds);
    final alignedTo = to - (to % bucketSeconds);
    final rows = _db.select(
      '''
      SELECT
        (ts / ?) * ? AS bucket,
        MIN(ok) AS ok,
        AVG(ms) AS avg_ms
      FROM checks
      WHERE ts >= ? AND ts <= ?
      GROUP BY bucket
      ORDER BY bucket
      ''',
      [bucketSeconds, bucketSeconds, alignedFrom, to],
    );
    final byBucket = {
      for (final row in rows) row['bucket'] as int: row,
    };
    final points = <HistoryPoint>[];
    for (var bucket = alignedFrom; bucket <= alignedTo; bucket += bucketSeconds) {
      final row = byBucket[bucket];
      if (row == null) {
        points.add(HistoryPoint(ts: bucket, ms: null, ok: null));
      } else {
        points.add(
          HistoryPoint(
            ts: bucket,
            ms: row['avg_ms'] == null ? null : (row['avg_ms'] as num).round(),
            ok: row['ok'] as int,
          ),
        );
      }
    }
    return points;
  }

  void replaceHolidays(List<HolidayPeriod> periods, int updatedAt) {
    _db.execute('BEGIN');
    try {
      _db.execute('DELETE FROM holidays');
      final stmt = _db.prepare(
        'INSERT INTO holidays (slug, start_ts, end_ts, name, name_cp, year) '
        'VALUES (?, ?, ?, ?, ?, ?)',
      );
      try {
        for (final period in periods) {
          stmt.execute([
            period.slug ?? '${period.name}-${period.start}',
            period.start,
            period.end,
            period.name,
            period.label,
            period.year ?? 0,
          ]);
        }
      } finally {
        stmt.close();
      }
      _db.execute(
        'INSERT OR REPLACE INTO holidays_meta (id, updated_at) VALUES (1, ?)',
        [updatedAt],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  int? holidaysUpdatedAt() {
    final rows = _db.select(
      'SELECT updated_at FROM holidays_meta WHERE id = 1',
    );
    if (rows.isEmpty) return null;
    return rows.first['updated_at'] as int;
  }

  List<HolidayPeriod> holidays({int? from, int? to}) {
    final sql = StringBuffer(
      'SELECT slug, start_ts, end_ts, name, name_cp, year FROM holidays',
    );
    final args = <Object?>[];
    if (from != null && to != null) {
      sql.write(' WHERE end_ts >= ? AND start_ts <= ?');
      args.addAll([from, to]);
    }
    sql.write(' ORDER BY start_ts');
    final rows = _db.select(sql.toString(), args);
    return [
      for (final row in rows)
        HolidayPeriod(
          start: row['start_ts'] as int,
          end: row['end_ts'] as int,
          name: row['name'] as String,
          label: row['name_cp'] as String,
          slug: row['slug'] as String,
          year: row['year'] as int,
        ),
    ];
  }

  void retain(int cutoffTs) {
    _db.execute('DELETE FROM checks WHERE ts < ?', [cutoffTs]);
  }

  void maybeMaintain(int nowSeconds) {
    final day = nowSeconds ~/ 86400;
    if (day == _lastMaintenanceDay) return;
    _lastMaintenanceDay = day;
    retain(nowSeconds - const Duration(days: 730).inSeconds);
    try {
      _db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      _db.execute('VACUUM;');
    } catch (_) {
      // In-memory or locked DB: skip compaction.
    }
  }

  void dispose() => _db.close();

  CheckRecord _checkFromRow(Row row) {
    return CheckRecord(
      ts: row['ts'] as int,
      ok: row['ok'] as int,
      ms: row['ms'] as int?,
      code: row['code'] as int,
    );
  }
}
