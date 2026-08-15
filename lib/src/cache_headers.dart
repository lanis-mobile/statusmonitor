import 'package:shelf/shelf.dart';

const cacheControlValue =
    'public, max-age=30, s-maxage=30, stale-while-revalidate=30';

const cacheHeaders = {
  'Cache-Control': cacheControlValue,
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
