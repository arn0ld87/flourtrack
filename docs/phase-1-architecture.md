# FlourTrack Phase 1 Architecture

## Architecture Decision

FlourTrack uses an offline-first native iOS client backed by a stateless REST API. PostgreSQL is the source of truth for accounts, profiles, game attempts, achievements, challenges, friendships, and yearly aggregates. Redis is limited to derived leaderboard views backed by PostgreSQL data.

REST is the first backend API because it keeps the mobile sync surface explicit, cacheable, easy to document with OpenAPI, and simple to exercise from tests and local tooling. Game Center support will be isolated later behind the same leaderboard protocol as the backend service, so the client can switch providers without changing feature views.

The Phase 1 container stack is intentionally small:

- `postgres:17-alpine` for durable relational state.
- `redis:7.4-alpine` for leaderboard sorted sets.
- `node:22-alpine` for the TypeScript API. The image is Alpine-based, so no Debian or Ubuntu package installation is needed.

## Redis Data Structure

Redis stores only recomputable leaderboard projections.

| Key | Type | Score | Member | TTL |
| --- | --- | --- | --- | --- |
| `leaderboard:daily:global:YYYY-MM-DD` | Sorted Set | daily total score | `public_user_id` | 14 days |
| `leaderboard:weekly:global:YYYY-WW` | Sorted Set | weekly total score | `public_user_id` | 10 weeks |
| `leaderboard:alltime:global` | Sorted Set | all-time total score | `public_user_id` | none |
| `leaderboard:daily:friends:{userId}:YYYY-MM-DD` | Sorted Set | daily friend score | `public_user_id` | 14 days |
| `leaderboard:weekly:friends:{userId}:YYYY-WW` | Sorted Set | weekly friend score | `public_user_id` | 10 weeks |

Write path:

1. Store game in PostgreSQL in a transaction.
2. Recompute or increment affected aggregate rows in PostgreSQL.
3. Update Redis sorted sets after commit.
4. If Redis is unavailable, keep PostgreSQL successful and rebuild Redis projections later.

Read path:

1. Query Redis for leaderboard ranks and scores.
2. Hydrate display data from PostgreSQL profiles.
3. Fall back to PostgreSQL aggregate queries if Redis misses.

Conflict policy for future offline sync:

- `games.client_game_id` is unique per user, making retries idempotent.
- Game attempts are append-only.
- Aggregates are recalculated deterministically from accepted game rows.
- `played_at` is client supplied, stored as UTC, and accepted only after validation in later API phases.
