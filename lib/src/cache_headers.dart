import 'package:shelf/shelf.dart';

const cacheControlValue =
    'public, max-age=30, s-maxage=30, stale-while-revalidate=30';

const cacheHeaders = {
  'Cache-Control': cacheControlValue,
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Content-Security-Policy':
      "default-src 'self'; script-src 'self'; "
      "style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; "
      "object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
  'CDN-Cache-Control': 'max-age=30',
  'Cloudflare-CDN-Cache-Control': 'max-age=30',
};

Middleware cacheHeadersMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      return response.change(
        headers: {...response.headersAll, ...cacheHeaders},
      );
    };
  };
}
