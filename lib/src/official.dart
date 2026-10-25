import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'clock.dart';
import 'database.dart';

const officialStatusUrl = 'https://status.schulportal.hessen.de/';
const officialRefreshInterval = Duration(minutes: 5);
const _serviceIds = ['IdM', 'PaedOrg', 'LernSys', 'PaedNet', 'BS', 'Support'];

/// Only text and locally defined status values cross this boundary. Upstream
/// markup, attributes, URLs, CSS and executable content are never forwarded.
List<Map<String, Object?>> parseOfficialStatus(String source) {
  final document = html.parse(source);
  final article = document.querySelector('.entry-content');
  if (article == null) throw const FormatException('Missing status article');
  article
      .querySelectorAll(
        'script, style, iframe, object, embed, svg, math, template, noscript, '
        'form, input, button, .kopiervorlagen, [hidden], [aria-hidden="true"]',
      )
      .forEach((element) => element.remove());

  final symbols = <String, String>{};
  for (final table in article.querySelectorAll('table.status')) {
    final rows = table.querySelectorAll('tr');
    if (rows.length < 2) continue;
    final labels = rows[0].querySelectorAll('td');
    final values = rows[1].querySelectorAll('td');
    for (var i = 0; i < labels.length && i < values.length; i++) {
      final href = labels[i].querySelector('a[href]')?.attributes['href'];
      final id = href == null ? null : Uri.tryParse(href)?.fragment;
      if (id != null && _serviceIds.contains(id)) symbols[id] = values[i].text;
    }
  }

  final services = <Map<String, Object?>>[];
  for (final id in _serviceIds) {
    final anchor = article.querySelector('[id="$id"]');
    Element? heading = anchor;
    while (heading != null &&
        !RegExp(r'^h[1-6]$').hasMatch(heading.localName ?? '')) {
      heading = heading.parent;
    }
    final name = heading == null ? '' : _text(heading);
    final rows = <String, String>{};
    // WordPress currently places the detail table after each anchored heading.
    // Traverse siblings instead of relying on versioned post/widget IDs.
    for (
      var node = heading?.nextElementSibling;
      node != null;
      node = node.nextElementSibling
    ) {
      if (RegExp(r'^h[1-6]$').hasMatch(node.localName ?? '')) break;
      if (node.localName != 'table') continue;
      for (final row in node.querySelectorAll('tr')) {
        final cells = row.children.where((c) => c.localName == 'td').toList();
        if (cells.length != 2) continue;
        final label = _text(cells[0]).trim();
        if (label == 'Status:' || label == 'Update:') {
          rows[label] = _text(cells[1]);
        }
      }
      break;
    }
    if (name.isEmpty ||
        (rows['Status:'] ?? '').isEmpty ||
        (rows['Update:'] ?? '').isEmpty) {
      throw FormatException('Incomplete official status section: $id');
    }
    final symbol = symbols[id] ?? '';
    services.add({
      'id': id,
      'name': name,
      'status': symbol.contains('❗')
          ? 'restricted'
          : symbol.contains('🆗')
          ? 'operational'
          : 'unknown',
      'maintenance': symbol.contains('🛠'),
      'notice': rows['Status:'],
      'update': rows['Update:'],
    });
  }
  return services;
}

String _text(Element element) {
  final buffer = StringBuffer();
  void visit(Node node) {
    if (node is Text) {
      buffer.write(node.data);
    } else if (node is Element) {
      final block = const {
        'p',
        'div',
        'h1',
        'h2',
        'h3',
        'h4',
        'li',
        'br',
      }.contains(node.localName);
      if (block) buffer.write('\n');
      for (final child in node.nodes) {
        visit(child);
      }
      if (block) buffer.write('\n');
    }
  }

  visit(element);
  return buffer
      .toString()
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[\s\u00a0]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

/// Redirects may change the page path or official subdomain, but cannot switch
/// protocol, escape the official domain or introduce credentials/custom ports.
bool isOfficialStatusUri(Uri uri) =>
    uri.scheme == 'https' &&
    (uri.host == 'schulportal.hessen.de' ||
        uri.host.endsWith('.schulportal.hessen.de')) &&
    uri.userInfo.isEmpty &&
    uri.port == 443;

class OfficialStatusService {
  OfficialStatusService({required this.db, required this.clock, this.fetch});
  final StatusDatabase db;
  final Clock clock;
  final Future<String> Function()? fetch;
  bool _refreshing = false;
  bool _failed = false;

  Map<String, Object?> payload() {
    final snapshot = db.officialStatus();
    final fetchedAt = snapshot?['fetchedAt'] as int?;
    return {
      'sourceUrl': officialStatusUrl,
      'fetchedAt': fetchedAt,
      'stale':
          _failed || fetchedAt == null || clock.nowSeconds - fetchedAt >= 600,
      'services': snapshot?['services'] ?? [],
    };
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final services = parseOfficialStatus(await (fetch?.call() ?? _fetch()));
      db.saveOfficialStatus({
        'fetchedAt': clock.nowSeconds,
        'services': services,
      });
      _failed = false;
    } catch (error) {
      _failed = true;
      stderr.writeln(
        'Official status refresh failed; retaining snapshot: $error',
      );
    } finally {
      _refreshing = false;
    }
  }

  void seed(String source) {
    db.saveOfficialStatus({
      'fetchedAt': clock.nowSeconds,
      'services': parseOfficialStatus(source),
    });
  }

  Future<String> _fetch() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await _fetchRedirects(client).timeout(const Duration(seconds: 25));
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _fetchRedirects(HttpClient client) async {
    var uri = Uri.parse(officialStatusUrl);
    for (var hop = 0; hop <= 5; hop++) {
      if (!isOfficialStatusUri(uri)) {
        throw const FormatException('Unsafe official redirect');
      }
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'lanis-mobile-statusmonitor/1.0',
      );
      final response = await request.close();
      if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) {
          throw const FormatException('Missing redirect location');
        }
        uri = uri.resolve(location);
        // Do not download an arbitrary redirect body.
        continue;
      }
      if (response.statusCode != 200 ||
          response.headers.contentType?.mimeType != 'text/html') {
        throw const FormatException('Invalid official status response');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const FormatException('Official status response too large');
        }
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    }
    throw const FormatException('Too many official status redirects');
  }
}
