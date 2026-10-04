# Wardrift API Docs

This is the practical integration guide for Wardrift clients. If you are
building firmware, a mobile companion app, or a desktop helper, this is the stuff
you need to store user keys, send device telemetry, and pull back the player
state that matters.

The big thing to know up front: live device telemetry uses API keys. Dashboard,
wardrive archive, mesh dashboard, and map reads use a signed-in user session.

## Ground Rules

- Start every path from the deployed API host, for example
  `https://api.example.com/v1/...`.
- JSON uses `snake_case` property names.
- Enums are lower snake case strings, for example `router`, `heatmap`,
  `character_xp`, and `hex_influence`.
- Send timestamps as ISO 8601 strings with offsets, for example
  `2026-07-04T18:30:00Z`.
- When something goes wrong, errors come back as JSON:

```json
{
  "error": "bad_request",
  "message": "missing bbox"
}
```

## Auth

Wardrift has two auth paths. Pick the one that matches what your client is
doing.

### API Keys

Use API keys for device telemetry only.

```http
X-API-Key: wdk_user_or_device_key
Content-Type: application/json
```

These endpoints accept `X-API-Key`:

- `POST /v1/ingest/signals`
- `POST /v1/ingest/mesh`

This API surface consumes API keys, but it does not expose create, list, or
revoke key-management endpoints yet. For now, ask the user to paste a
Wardrift-provisioned plaintext key, then store it securely.

Heads up: dashboard, wardrive archive, mesh dashboard, and map viewport reads do
not accept `X-API-Key`. They need a signed-in user session.

For firmware, keep these values around:

- The plaintext Wardrift API key.
- The last successful `sequence_no` for that key.
- Any pending request `idempotency_key` values until the server confirms them.

Increase `sequence_no` for each new batch on the same API key. If you reuse or
lower it, the API treats that as a replay. If you resend the same
`idempotency_key` for the same API key, the API returns the original accepted
response with `duplicate: true` and does not double count awards.

The `signature` field can be an empty string while the API key has no registered
device public key. Once a public key is registered server-side, requests need a
base64 Ed25519 signature for the backend's canonical payload.

### Session Tokens

Use a session token for dashboard, wardrive archive, mesh dashboard, and map
reads. The API accepts either its session cookie or a bearer token:

```http
Authorization: Bearer <session_token>
```

A companion app can get a token by signing in:

```http
POST /v1/auth/sign-in/username
Content-Type: application/json

{
  "username": "player_name",
  "password": "correct-horse-battery",
  "remember_me": true
}
```

The response includes `session.token`. Treat it like a password.

## Telemetry Envelope

All API-key telemetry endpoints use this wrapper. The `items` array changes by
endpoint, but the outer envelope stays the same.

```json
{
  "idempotency_key": "0f3e1f6c-45d7-4e41-9f4a-46953a5ec63f",
  "sequence_no": 42,
  "device_ts": "2026-07-04T18:30:00Z",
  "signature": "",
  "items": []
}
```

Common response:

```json
{
  "batch_id": "8f3437b0-2d88-4e61-bf1e-7712f7d7f24a",
  "accepted": true,
  "duplicate": false,
  "item_count": 1,
  "awarded_exp": 3,
  "awarded_currency": 5,
  "validation_score": 75,
  "flags": ["SignatureMissing"]
}
```

## Dashboard

### GET /v1/dashboard

Gives you the signed-in user's dashboard in one round trip.

Auth: session bearer token or session cookie.

Request:

```http
GET /v1/dashboard
Authorization: Bearer <session_token>
```

Response body:

```json
{
  "characters": [
    {
      "id": "guid",
      "user_id": "guid",
      "faction_id": 1,
      "race_id": 1,
      "name": "Callsign",
      "level": 4,
      "exp": 1200,
      "currency": 250,
      "exp_into_level": 200,
      "exp_for_level": 1000,
      "exp_to_next_level": 800,
      "created_at": "2026-07-04T18:30:00Z"
    }
  ],
  "nodes": [
    {
      "id": "guid",
      "user_id": "guid",
      "faction_id": 1,
      "kind": "router",
      "name": "Roof Relay",
      "last_seen_lat": 40.7128,
      "last_seen_lon": -74.006,
      "last_seen_at": "2026-07-04T18:25:00Z",
      "created_at": "2026-07-01T12:00:00Z"
    }
  ],
  "relics": [
    {
      "id": "guid",
      "name": "Relic Name",
      "origin_faction_id": 1,
      "holding_faction_id": 2
    }
  ],
  "wardrive": {},
  "recent_routes": {},
  "mesh": {}
}
```

`wardrive` matches `GET /v1/wardrive/me`. `recent_routes` matches
`GET /v1/wardrive/routes`, fixed to the 5 newest routes. `mesh` matches
`GET /v1/mesh/me?includeTables=false`, so `owned_nodes` and `feed` are empty
arrays in this aggregate.

## Wardrive

If your firmware is doing live wardriving with a stored API key, use
`POST /v1/ingest/signals`. This is a character-device telemetry endpoint and
requires a character-bound API key.

Threat-like detections belong in `signals` too. Send them as `kind: "airtag"`
or `kind: "deauth"` when that is what the device found. CSV uploads follow the
same idea: threat-like rows are parsed into signal rows and still count toward
route threat totals.

The `/v1/wardrive/*` endpoints are for archive reads and browser-style uploads.
They are session-gated and do not accept `X-API-Key`.

### POST /v1/ingest/signals

Send wardrive signal telemetry from a character-bound device key.

Auth:

```http
X-API-Key: <character_api_key>
Content-Type: application/json
```

Request:

```json
{
  "idempotency_key": "0f3e1f6c-45d7-4e41-9f4a-46953a5ec63f",
  "sequence_no": 42,
  "device_ts": "2026-07-04T18:30:00Z",
  "signature": "",
  "items": [
    {
      "ts": "2026-07-04T18:30:00Z",
      "source_ts": "2026-07-04T18:29:58Z",
      "lat": 40.7128,
      "lon": -74.006,
      "kind": "wifi",
      "rssi": -55,
      "ssid_hash": "base64-or-hex-hash",
      "bssid_hash": "base64-or-hex-hash",
      "metadata": {
        "channel": "6",
        "source": "firmware"
      }
    }
  ]
}
```

Signal `kind` values:

- `wifi`
- `bluetooth`
- `cellular`
- `airtag`
- `deauth`
- `other`

Response uses the common ingest response shape.

### GET /v1/wardrive/me

Gets route stats for the signed-in user.

Auth: session bearer token or session cookie.

Response:

```json
{
  "lifetime": {
    "routes_logged": 2,
    "access_points_discovered": 145,
    "threats_flagged": 4,
    "distance_km": 12.384
  },
  "this_week": {
    "routes_logged": 1,
    "access_points_discovered": 65,
    "threats_flagged": 2,
    "distance_km": 5.219
  },
  "last_upload": {
    "id": "guid",
    "title": "Evening Scan",
    "source": "WiGLE CSV",
    "original_file_name": "evening.wiglecsv",
    "public_route": false,
    "started_at": "2026-07-04T18:00:00Z",
    "ended_at": "2026-07-04T18:20:00Z",
    "uploaded_at": "2026-07-04T18:25:00Z",
    "distance_km": 5.219,
    "access_point_count": 65,
    "threat_count": 2,
    "validation_score": 100,
    "awarded_exp": 120,
    "awarded_currency": 0,
    "preview_points": [{ "x": 14.0, "y": 88.4 }]
  },
  "streak_days": 3
}
```

`last_upload` is `null` when the user has not uploaded any routes yet.

### GET /v1/wardrive/routes

Lists the signed-in user's archived routes.

Auth: session bearer token or session cookie.

Query params:

- `limit`: default `10`, min `1`, max `50`.
- `offset`: default `0`, negative values are clamped to `0`.
- `sort`: `date`, `distance`, `access_points`, or `confidence`. Aliases such as
  `newest`, `oldest`, `distance_km`, `aps`, and `validation_score` are accepted.
- `direction`: `asc` or `desc`. Default is `desc`, except legacy `sort=oldest`
  and `sort=uploaded_asc` imply `asc`.

Request:

```http
GET /v1/wardrive/routes?limit=10&offset=0&sort=date&direction=desc
Authorization: Bearer <session_token>
```

Response:

```json
{
  "limit": 10,
  "offset": 0,
  "next_offset": null,
  "has_more": false,
  "sort": "date",
  "direction": "desc",
  "items": []
}
```

Each `items[]` entry uses the same route-list shape shown in `last_upload`.

### GET /v1/wardrive/routes/{routeId}/export

Downloads one of the signed-in user's routes as CSV.

Auth: session bearer token or session cookie.

Response content type:

```http
text/csv; charset=utf-8
```

CSV columns:

```csv
route_id,title,sequence,timestamp,latitude,longitude,kind,rssi
```

You get `404` if the route does not exist or belongs to someone else.

### POST /v1/wardrive/logs

Uploads a WiGLE CSV wardrive log and saves it as an archived route.

Auth: session bearer token or session cookie.

Content type:

```http
multipart/form-data
```

Form fields:

- `file`: required. Accepted extensions are `.csv` and `.wiglecsv`.
- `public_route` or `publicRoute`: optional boolean. Defaults to `false`.

Limits and parsing:

- Maximum file size is 200 MB.
- The parser expects WiGLE CSV columns including `MAC`, `FirstSeen`,
  `CurrentLatitude`, and `CurrentLongitude`.
- Duplicate uploads of the same file are rejected with `409 duplicate_route`.
- The upload is internally handled as character signal telemetry, so it can award
  EXP and contribute hex influence.

Example:

```bash
curl -X POST "$BASE_URL/v1/wardrive/logs" \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  -F "file=@run.wiglecsv" \
  -F "public_route=false"
```

Response:

```json
{
  "batch_id": "guid",
  "accepted": true,
  "duplicate": false,
  "parsed_rows": 5,
  "accepted_signals": 5,
  "skipped_rows": 0,
  "awarded_exp": 8,
  "awarded_currency": 0,
  "validation_score": 75,
  "flags": ["SignatureMissing"],
  "warnings": []
}
```

## Mesh

Mesh has two surfaces:

- `POST /v1/ingest/mesh` for node telemetry, authenticated by `X-API-Key`.
- `/v1/mesh/*` dashboard reads, authenticated by signed-in user session.

### POST /v1/ingest/mesh

Send periodic Meshtastic-style node reports here. This endpoint requires a
node-bound API key. Character device keys are rejected.

Auth:

```http
X-API-Key: <node_api_key>
Content-Type: application/json
```

Request:

```json
{
  "idempotency_key": "0f3e1f6c-45d7-4e41-9f4a-46953a5ec63f",
  "sequence_no": 42,
  "device_ts": "2026-07-04T18:30:00Z",
  "signature": "",
  "items": [
    {
      "ts": "2026-07-04T18:30:00Z",
      "source_ts": null,
      "lat": 40.7128,
      "lon": -74.006,
      "uptime_seconds": 900,
      "battery_level": 87,
      "voltage": 4.1,
      "channel_utilization": 12.5,
      "air_util_tx": 2.4,
      "num_packets_tx": 4,
      "num_packets_rx": 8,
      "num_packets_rx_bad": 0,
      "num_tx_relay": 2,
      "num_tx_relay_canceled": 0,
      "num_rx_dupe": 0,
      "num_online_nodes": 5,
      "num_total_nodes": 9,
      "metadata": {
        "firmware": "example-1.0.0"
      }
    }
  ]
}
```

Field notes:

- `ts`: report timestamp.
- `source_ts`: optional source telemetry timestamp.
- `lat` and `lon`: optional. If omitted, the API uses the node's stored
  `last_seen_lat` and `last_seen_lon` for mesh influence.
- `uptime_seconds`: node uptime at report time.
- `battery_level`: optional percentage-like short integer.
- `voltage`, `channel_utilization`, and `air_util_tx`: optional telemetry floats.
- Packet counters are treated as the report window's counters when awards are
  calculated.
- `metadata`: optional arbitrary JSON object.

Response uses the common ingest response shape.

### GET /v1/mesh/me

Gets the signed-in user's mesh dashboard summary.

Auth: session bearer token or session cookie.

Query params:

- `includeTables`: optional boolean, default `true`. When `false`,
  `owned_nodes` and `feed` are empty arrays.

Request:

```http
GET /v1/mesh/me?includeTables=true
Authorization: Bearer <session_token>
```

Response:

```json
{
  "uplink_online": true,
  "reporting_node_count": 1,
  "owned_node_count": 3,
  "metrics": [
    {
      "key": "client_xp_awarded",
      "label": "Client XP Awarded",
      "value": "3",
      "delta": "+2",
      "caption": "To Character",
      "accent": "#a855f7",
      "icon": "zap",
      "chart": "bars",
      "series": [0, 35, 100]
    }
  ],
  "contributions": [
    {
      "key": "availability",
      "label": "Availability",
      "percent": 30,
      "value_label": "80% useful uptime",
      "color": "#00ff66",
      "definition": "availability = percent of time your useful nodes were online."
    }
  ],
  "owned_nodes": [],
  "feed": []
}
```

Metric keys currently include:

- `client_xp_awarded`
- `hex_influence_routed`
- `currency_awarded`
- `fleet_uptime`

### GET /v1/mesh/owned-nodes

Lists mesh nodes owned by the signed-in user.

Auth: session bearer token or session cookie.

Query params:

- `limit`: default `10`, min `1`, max `50`.
- `offset`: default `0`, negative values are clamped to `0`.

Response:

```json
{
  "limit": 10,
  "offset": 0,
  "next_offset": null,
  "has_more": false,
  "items": [
    {
      "id": "guid",
      "name": "Roof Relay",
      "kind": "router",
      "role": "router",
      "status": "Online",
      "uptime_seconds": 900,
      "uptime_percent": 87,
      "trend": "up",
      "last_seen_at": "2026-07-04T18:25:00Z",
      "last_report_ts": "2026-07-04T18:30:00Z",
      "battery_level": 87,
      "channel_utilization": 12.5,
      "air_util_tx": 2.4
    }
  ]
}
```

### GET /v1/mesh/feed

Lists recent mesh report feed entries for the signed-in user's nodes.

Auth: session bearer token or session cookie.

Query params:

- `limit`: default `10`, min `1`, max `50`.
- `offset`: default `0`, negative values are clamped to `0`.

Response:

```json
{
  "limit": 10,
  "offset": 0,
  "next_offset": null,
  "has_more": false,
  "items": [
    {
      "node_id": "guid",
      "name": "Roof Relay",
      "kind": "router",
      "packets": 6,
      "ts": "2026-07-04T18:30:00Z",
      "last_seen": "4m ago",
      "reward_kind": "hex_influence",
      "reward_label": "Influence",
      "reward_value": 2,
      "currency": 5
    }
  ]
}
```

## Map

### GET /v1/map/viewport

Gets the map data for one settled viewport. Hex mode returns territory and
outposts. Heatmap mode returns bucketed influence points.

Auth: session bearer token or session cookie.

Required query params:

- `south`
- `north`
- `west`
- `east`

Validation:

- All four bounding-box values are required.
- `south` must be less than or equal to `north`.
- `west` must be less than or equal to `east`.

Common query params:

- `mode`: `hex` or `heatmap`. Defaults to `hex`.

Hex mode query params:

- `territoryLimit`: default `2000`, min `1`, max `4000`.
- `outpostLimit`: default `200`, min `1`, max `200`.

Heatmap mode query params:

- `buckets`: default `48`, min `8`, max `80`.
- `heatmapLimit`: default `500`, min `1`, max `600`.

Hex request:

```http
GET /v1/map/viewport?mode=hex&south=33.8&north=34.3&west=-118.6&east=-117.9
Authorization: Bearer <session_token>
```

Hex response:

```json
{
  "mode": "hex",
  "territory": [
    {
      "h3_index": "862a1072fffffff",
      "resolution": 6,
      "center_lat": 34.05,
      "center_lon": -118.25,
      "controlling_faction_id": 1,
      "controlling_guild_id": "guid",
      "controlling_guild_name": "Guild Name",
      "owning_outpost_id": "guid",
      "influence": [
        {
          "faction_id": 1,
          "score": 42.0
        }
      ]
    }
  ],
  "outposts": [
    {
      "id": "guid",
      "name": "Relay Tower",
      "lat": 34.05,
      "lon": -118.25,
      "owning_faction_id": 2,
      "owning_guild_id": "guid",
      "owning_guild_name": "Guild Name",
      "defense_level": 2,
      "max_defense_level": 5,
      "kind": "tower",
      "upgrade_locked_until": null,
      "created_at": "2026-07-04T18:30:00Z",
      "action": {
        "available": "siege",
        "can_act": true,
        "siege_cooldown_until": null,
        "drive_through_expires_at": "2026-07-05T18:30:00Z",
        "next_upgrade_cost": null,
        "at_max_defense": false
      }
    }
  ],
  "heatmap": []
}
```

Heatmap request:

```http
GET /v1/map/viewport?mode=heatmap&south=33.8&north=34.3&west=-118.6&east=-117.9
Authorization: Bearer <session_token>
```

Heatmap response:

```json
{
  "mode": "heatmap",
  "territory": [],
  "outposts": [],
  "heatmap": [
    {
      "lat": 34.05,
      "lon": -118.25,
      "faction_id": 1,
      "score": 42.0,
      "weight": 1.0
    }
  ]
}
```

## Firmware Checklist

1. Ask the user for the right Wardrift API key type.
   - Mesh telemetry requires a node-bound key.
   - Wardrive signal telemetry requires a character-bound key.
2. Store the plaintext API key securely on the device.
3. Save `sequence_no` locally and increment it only when creating a new envelope.
4. Generate a new UUID `idempotency_key` for each new batch.
5. Retry network failures with the same `idempotency_key` and `sequence_no`.
6. Treat `duplicate: true` as a successful retry.
7. Use session tokens, not API keys, for dashboard, wardrive archive, mesh
   dashboard, and map viewport reads.
