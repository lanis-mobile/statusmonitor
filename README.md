# Statusmonitor

Uptime status page for [Schulportal Hessen](https://start.schulportal.hessen.de). A Dart process logs a `liblanis` test-login every minute, stores response times in SQLite (2-year retention), and serves a statically built Vue page plus a JSON API from one HTTP server.

See [docs/API.md](docs/API.md) for endpoints, cache headers, and the Cloudflare Cache Rule.

## Run locally

```bash
cd frontend && npm ci && npm run build && cd ..
export LANIS_SCHOOL_ID=5151
export LANIS_USERNAME=...
export LANIS_PASSWORD=...
dart pub get
dart run bin/server.dart
```

Open `http://127.0.0.1:8080`.

Fixture mode (no live SPH / schulferien-api.de calls):

```bash
STATUSMONITOR_MODE=fixture STATUSMONITOR_NOW=1784116800 dart run bin/server.dart
```

Regenerate committed fake series:

```bash
dart run tool/generate_fixtures.dart
```

## Tests

```bash
dart analyze
dart test
cd frontend && npm ci && npm run build
STATUSMONITOR_MODE=fixture STATUSMONITOR_NOW=1784116800 \
  STATUSMONITOR_STATIC_DIR=frontend/dist dart run bin/server.dart
cd frontend && npx playwright install --with-deps && npm run test:e2e
```

## Docker

```bash
docker build -t statusmonitor .
docker run --rm -p 8080:8080 \
  -e LANIS_SCHOOL_ID \
  -e LANIS_USERNAME \
  -e LANIS_PASSWORD \
  -v statusmonitor-data:/data \
  statusmonitor
```

Example `docker-compose.yml`:

```yaml
services:
  statusmonitor:
    image: ghcr.io/lanis-mobile/statusmonitor:latest
    # or build locally: build: .
    ports:
      - "8080:8080"
    environment:
      LANIS_SCHOOL_ID: "5151"
      LANIS_USERNAME: "${LANIS_USERNAME}"
      LANIS_PASSWORD: "${LANIS_PASSWORD}"
    volumes:
      - statusmonitor-data:/data
    restart: unless-stopped

volumes:
  statusmonitor-data:
```

Put credentials in a `.env` file next to `docker-compose.yml`:

```env
LANIS_USERNAME=your-monitor-user
LANIS_PASSWORD=your-monitor-password
```

Images are published to `ghcr.io/lanis-mobile/statusmonitor`.