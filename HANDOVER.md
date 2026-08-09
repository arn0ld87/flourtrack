# FlourTrack Handover

Last updated: 2026-08-09T00:43:50Z

## Current Repository

- GitHub: https://github.com/arn0ld87/flourtrack
- Branch: `main`
- Last pushed commit before this handover: `5f81ca9` (`Initial FlourTrack phase 1`)
- Local project path in the active Xcode workspace: `/Users/alexanderschneider/Library/Developer/Xcode/UntitledProjects/Untitled Project`
- Same local path as resolved by the shell: `/Volumes/T7/_mac_offload/Developer/Xcode/UntitledProjects/Untitled Project`
- Remote Docker validation path on `armserver`: `/Volumes/T7/Projekte/iosapp_august`

## Product Scope

FlourTrack is a native iPhone arcade/timing game about virtual flour lines. All quantities, distances, factors, and calculations are fictional game values only. The app must avoid real-world drug, dosage, medical, or health recommendation framing.

The requested development order is strict:

1. Phase 1: Architecture and backend infrastructure
2. Phase 2: iOS skeleton
3. Phase 3: Core game
4. Phase 4: Backend APIs
5. Phase 5: Statistics
6. Phase 6: Social
7. Phase 7: Quality

Only Phase 1 has been implemented so far.

## Phase 1 Status

Implemented:

- Architecture note: `docs/phase-1-architecture.md`
- PostgreSQL schema migration: `backend/migrations/001_initial_schema.sql`
- Redis leaderboard concept
- Docker Compose stack: `compose.yaml`
- Backend Dockerfile: `backend/Dockerfile`
- Environment example: `.env.example`
- Minimal TypeScript/Fastify backend with:
  - `GET /health/live`
  - `GET /health/ready`
  - `GET /openapi.json`
- Git ignore rules for local artifacts

PostgreSQL schema includes:

- `users`
- `profiles`
- `games`
- `friendships`
- `achievements`
- `user_achievements`
- `daily_challenges`
- `user_challenges`
- `yearly_statistics`

Seeded achievements:

- `rookie_baker`
- `millisecond_master`
- `flour_power`
- `precision_machine`
- `around_the_world`
- `early_bird`

## Verified Checks

Local checks:

```bash
cd "/Users/alexanderschneider/Library/Developer/Xcode/UntitledProjects/Untitled Project/backend"
npm run build
npm audit --audit-level=moderate
```

Results:

- TypeScript build passed.
- `npm audit --audit-level=moderate` found 0 vulnerabilities.

Remote checks on `armserver`:

```bash
cd /Volumes/T7/Projekte/iosapp_august
docker compose ps
curl -fsS http://127.0.0.1:18080/health/ready
docker compose exec -T postgres psql -U flourtrack -d flourtrack -c "select table_name from information_schema.tables where table_schema = 'public' order by table_name;"
docker compose exec -T redis redis-cli ping
```

Results:

- PostgreSQL healthy.
- Redis healthy.
- Backend healthy.
- Migration created all 9 required tables.
- Healthcheck returned `{"status":"ready","postgres":"ok","redis":"ok"}`.
- Redis returned `PONG`.

## Remote Docker Notes

Local Docker is currently not usable in the active macOS environment:

```text
failed to connect to the docker API at unix:///Users/alexanderschneider/.docker/run/docker.sock
```

Use `armserver` for Docker validation.

Because ports `5432`, `6379`, and `8080` may already be occupied on `armserver`, the remote `.env` uses:

```text
POSTGRES_PORT=15432
REDIS_PORT=16379
BACKEND_PORT=18080
```

The container-internal backend port is fixed to `8080` in `compose.yaml`; `BACKEND_PORT` only controls the host port mapping.

Start on `armserver`:

```bash
ssh armserver
cd /Volumes/T7/Projekte/iosapp_august
docker compose up -d --build
curl http://127.0.0.1:18080/health/ready
```

## Important Implementation Notes

- Do not commit `.env`, `backend/node_modules/`, `backend/dist/`, or Xcode user state.
- `.env.example` is safe to commit.
- The backend is intentionally minimal. Game/social/statistics APIs are not implemented yet.
- Redis is not a source of truth. It only stores derived leaderboard sorted sets.
- PostgreSQL migrations currently run through the official container init mechanism. This is enough for Phase 1; a real migration runner can be added during backend API work.
- The current Xcode project is still the original minimal app with `MyApp/ContentView.swift`.

## Next Session Recommended Start

Start Phase 2 only after confirming Phase 1 is still green.

Recommended first commands:

```bash
git pull --ff-only
git status --short --branch
ssh armserver 'cd /Volumes/T7/Projekte/iosapp_august && docker compose ps && curl -fsS http://127.0.0.1:18080/health/ready'
```

Then implement Phase 2:

- Xcode project structure
- App entry point
- Native SwiftUI navigation
- Models
- Repository protocols
- SwiftData setup

Phase 2 must compile before moving to Phase 3.
