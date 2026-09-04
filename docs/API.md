# Statusmonitor API

JSON API served by the same Dart process as the static Vue page. All routes, including static assets, send a 30-second cache policy intended for Cloudflare.

## Cache headers

Every response includes:

```
Cache-Control: public, max-age=30, s-maxage=30, stale-while-revalidate=30
CDN-Cache-Control: max-age=30
Cloudflare-CDN-Cache-Control: max-age=30
```

Cloudflare does not cache extensionless JSON by default. Add a Cache Rule:

- If URI Path starts with `/` (or at least `/api/`)
- Then: Eligible for cache, Edge TTL 30 seconds, respect origin `Cache-Control`

That keeps origin hits close to two per unique URL per minute (plus one per POP on refresh).

## Endpoints

### `GET /api/status`

Secondary check: current online status only.

```json
{
  "online": true,
  "status": "operational",
  "checkedAt": 1784116800,
  "responseMs": 240,
  "code": 0,
  "inHolidays": true,
  "holidayLabel": "Sommerferien"
}
```

`status` is one of `operational`, `down`, `misconfigured`.
`online` is `true` only when `status` is `operational`.

`code` is the last probe result:

| code | meaning |
| --- | --- |
| 0 | ok |
| 1 | timeout |
| 2 | HTTP / network / Lanis down |
| 3 | authentication (monitor credentials) |
| 4 | unexpected error |

Persistent `code=3` is treated as `misconfigured`, not as an SPH outage.

### `GET /api/summary`

Current status plus uptime for fixed windows.

```json
{
  "current": { "online": true, "status": "operational" },
  "windows": {
    "24h": { "uptime": 97.917, "avgMs": 250, "checks": 1441, "failures": 30 },
    "7d": { "uptime": 99.053, "avgMs": 260, "checks": 3169, "failures": 30 },
    "30d": { "uptime": 99.2, "avgMs": 255, "checks": 800, "failures": 4 },
    "90d": { "uptime": 99.4, "avgMs": 252, "checks": 1200, "failures": 6 },
    "180d": { "uptime": 99.6, "avgMs": 250, "checks": 2000, "failures": 7 },
    "1y": { "uptime": 99.7, "avgMs": 249, "checks": 3000, "failures": 8 },
    "2y": { "uptime": 99.8, "avgMs": 248, "checks": 4000, "failures": 8 }
  }
}
```

Uptime is `100 * (checks - failures) / checks` over raw samples in that window.

### `GET /api/incidents`

Measured failure spans for the last 30 days, derived from individual probe results (not chart buckets). Each span runs from the first failed check until the next successful check.

```json
{
  "from": 1781524800,
  "to": 1784116800,
  "incidents": [
    { "start": 1784111400, "end": 1784113200 },
    { "start": 1782900000, "end": 1782910800 }
  ]
}
```

### `GET /api/history/{24h|7d|30d|90d|180d|1y|2y}`

Fixed paths so Cloudflare cache keys stay stable. Unknown windows return `404`.

| window | bucket |
| --- | --- |
| `24h` | 1 minute |
| `7d` | 5 minutes |
| `30d` | 1 hour |
| `90d` | 2 hours |
| `180d` | 4 hours |
| `1y` | 6 hours |
| `2y` | 6 hours |

```json
{
  "window": "24h",
  "bucketSeconds": 60,
  "from": 1784030400,
  "to": 1784116800,
  "points": [[1784030400, 220, 1], [1784030460, null, 0]]
}
```

Each point is `[ts, ms|null, ok|null]`. `ok` is `0` if any sample in the bucket failed, `1` if all succeeded, or `null` if the bucket has no samples. `ms` is the average of successful samples, or `null` when unavailable.

### `GET /api/holidays`

Hesse Schulferien covering the two-year history window. Served only from the local SQLite snapshot. The origin fetches `https://schulferien-api.de/api/v1/{year}/HE` at most once every **7 days**. Client requests never reach that API.

```json
{
  "state": "HE",
  "updatedAt": 1784116800,
  "periods": [
    {
      "start": 1782691200,
      "end": 1786147140,
      "name": "sommerferien",
      "label": "Sommerferien"
    }
  ]
}
```

## Environment

| variable | default | notes |
| --- | --- | --- |
| `LANIS_SCHOOL_ID` | — | required in live mode |
| `LANIS_USERNAME` | — | required in live mode |
| `LANIS_PASSWORD` | — | required in live mode |
| `PORT` | `8080` | listen port |
| `DATABASE_PATH` | `data/status.db` | use `:memory:` in fixture mode |
| `STATUSMONITOR_MODE` | `live` | `fixture` skips probes and holiday refresh |
| `STATUSMONITOR_NOW` | wall clock | pinned unix seconds for fixtures |
| `STATUSMONITOR_STATIC_DIR` | `frontend/dist` | Vue build output |
| `STATUSMONITOR_FIXTURE_DIR` | `test/fixtures` | JSON seed files |

`liblanis` is GPL-3.0. A distributed binary that links it should be treated as GPL-3.0 even though this repository’s `LICENSE` file is MIT.
