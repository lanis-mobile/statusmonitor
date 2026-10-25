import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:statusmonitor/statusmonitor.dart';
import 'package:test/test.dart';

void main() {
  final source = File('test/fixtures/official.html').readAsStringSync();
  const now = 1792926000;
  late StatusDatabase db;
  setUp(() => db = StatusDatabase.open(':memory:'));
  tearDown(() => db.dispose());

  test('extracts all six services, notices, history and maintenance', () {
    final services = parseOfficialStatus(source);
    expect(services.length, 6);
    expect(services.first['id'], 'IdM');
    expect(services.first['status'], 'operational');
    expect(services.first['notice'], contains('Letzte Einschränkung:'));
    final paedOrg = services[1];
    expect(paedOrg['status'], 'restricted');
    expect(paedOrg['maintenance'], isTrue);
    expect(paedOrg['notice'], contains('iCloud-Adressen'));
    expect(paedOrg['update'], contains('28.10.2026 12:00 - 14:00 Uhr'));
    expect(paedOrg['update'], contains('28.10.2026 15:00 - 18:00 Uhr'));
    expect(services[2]['status'], 'restricted');
    expect(services[2]['maintenance'], isFalse);
  });

  test('does not depend on the redirected path or WordPress post IDs', () {
    final changed = source
        .replaceAll('status-des-schulportal-hessen-3/', 'new-status-path/')
        .replaceAll('13446', '98765');
    expect(parseOfficialStatus(changed), parseOfficialStatus(source));
  });

  test('drops executable subtrees and returns only inert text', () {
    final malicious = source.replaceFirst(
      'Aktuell keine bekannten Einschränkungen',
      '''
      <script>evilScript()</script><style>evilStyle</style>
      <svg onload="evilSvg()"><text>evilSvg</text></svg>
      <iframe srcdoc="evilFrame"></iframe><object>evilObject</object>
      <template>evilTemplate</template><math>evilMath</math>
      <a href="javascript:evilLink()" onclick="evilClick()">Normaler Text</a>
      <img src=x onerror="evilImage()">
      &lt;img src=x onerror=evilEncoded()&gt;
    ''',
    );
    final services = parseOfficialStatus(malicious);
    final json = jsonEncode(services);
    for (final marker in [
      'evilScript',
      'evilStyle',
      'evilSvg',
      'evilFrame',
      'evilObject',
      'evilTemplate',
      'evilMath',
      'evilLink',
      'evilClick',
      'evilImage',
    ]) {
      expect(json, isNot(contains(marker)));
    }
    // Entity-encoded markup stays literal text; the browser test verifies that
    // this is escaped again at rendering, rather than interpreted as markup.
    expect(
      services.first['notice'],
      contains('<img src=x onerror=evilEncoded()>'),
    );
    expect(services.first['notice'], contains('Normaler Text'));
  });

  test('rejects missing article and partial/unrecognized layouts', () {
    expect(
      () => parseOfficialStatus('<html>maintenance</html>'),
      throwsFormatException,
    );
    expect(
      () => parseOfficialStatus(
        source.replaceFirst('id="Support"', 'id="Other"'),
      ),
      throwsFormatException,
    );
  });

  test('only permits HTTPS redirects within the official domain', () {
    for (final url in [
      officialStatusUrl,
      'https://info.schulportal.hessen.de/a-new-page/',
      'https://schulportal.hessen.de/status',
    ]) {
      expect(isOfficialStatusUri(Uri.parse(url)), isTrue);
    }
    for (final url in [
      'http://info.schulportal.hessen.de/',
      'javascript:alert(1)',
      'https://schulportal.hessen.de.evil.test/',
      'https://evil.test/',
      'https://user:pass@info.schulportal.hessen.de/',
      'https://info.schulportal.hessen.de:8443/',
      'https://127.0.0.1/',
    ]) {
      expect(isOfficialStatusUri(Uri.parse(url)), isFalse, reason: url);
    }
  });

  test(
    'keeps successful snapshot on fetch and parse failures; recovers',
    () async {
      var content = source;
      var fail = false;
      final service = OfficialStatusService(
        db: db,
        clock: Clock(fixedNow: now),
        fetch: () async {
          if (fail) throw const SocketException('offline');
          return content;
        },
      );
      expect(service.payload()['services'], isEmpty);
      expect(service.payload()['stale'], isTrue);
      await service.refresh();
      final original = db.officialStatus();
      expect(service.payload()['stale'], isFalse);
      fail = true;
      await service.refresh();
      expect(service.payload()['stale'], isTrue);
      expect(db.officialStatus(), original);
      fail = false;
      content = '<div class="entry-content">unexpected layout</div>';
      await service.refresh();
      expect(db.officialStatus(), original);
      content = source;
      await service.refresh();
      expect(service.payload()['stale'], isFalse);
      final later = OfficialStatusService(
        db: db,
        clock: Clock(fixedNow: now + 601),
      );
      expect(later.payload()['stale'], isTrue);
    },
  );

  test('overlapping refreshes do not duplicate upstream fetches', () async {
    var calls = 0;
    final pending = Completer<String>();
    final service = OfficialStatusService(
      db: db,
      clock: Clock(fixedNow: now),
      fetch: () {
        calls++;
        return pending.future;
      },
    );
    final first = service.refresh();
    await service.refresh();
    expect(calls, 1);
    pending.complete(source);
    await first;
    expect(service.payload()['stale'], isFalse);
  });

  test(
    'API serves stored snapshot without triggering upstream fetches',
    () async {
      final service = OfficialStatusService(
        db: db,
        clock: Clock(fixedNow: now),
        fetch: () => throw StateError('must not fetch'),
      );
      service.seed(source);
      final app = StatusApp(
        db: db,
        config: AppConfig.fromEnvironment(
          env: {'STATUSMONITOR_MODE': 'fixture'},
        ),
        clock: Clock(fixedNow: now),
        official: service,
      );
      final response = await app.handler(
        Request('GET', Uri.parse('http://localhost/api/official')),
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['content-type'],
        'application/json; charset=utf-8',
      );
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(
        response.headers['content-security-policy'],
        contains("script-src 'self'"),
      );
      final data =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(data['services'], hasLength(6));
      expect(data['sourceUrl'], officialStatusUrl);
    },
  );

  test('snapshot survives reopening the database', () {
    final directory = Directory.systemTemp.createTempSync('official-snapshot-');
    final path = '${directory.path}/status.db';
    final first = StatusDatabase.open(path);
    final service = OfficialStatusService(
      db: first,
      clock: Clock(fixedNow: now),
    );
    service.seed(source);
    first.dispose();
    final reopened = StatusDatabase.open(path);
    try {
      expect(reopened.officialStatus()?['services'], hasLength(6));
      expect(reopened.officialStatus()?['fetchedAt'], now);
    } finally {
      reopened.dispose();
      directory.deleteSync(recursive: true);
    }
  });
}
