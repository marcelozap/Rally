# Rally API — production checklist

The bundled server (`src/server.js` + SQLite) is aimed at **local development**. Before external testers or production, walk through this list.

## Transport & hosting

1. **HTTPS only** — terminate TLS at your host (Fly.io, Railway, Render, ECS, etc.). Do not ship cleartext JWTs over the public internet.
2. **Secrets** — `JWT_SECRET` must be long, random, and stored in the platform secret manager (not committed). Rotate if leaked.
3. **CORS** — replace wide-open `cors()` with an allowlist of your app / web origins.
4. **Rate limiting** — add middleware (e.g. `express-rate-limit`) on `/api/auth/*` to reduce brute force.

## Data layer

5. **Database** — migrate from SQLite to **PostgreSQL** (or another managed DB) for concurrency and backups.
6. **Migrations** — introduce explicit schema migrations (Prisma, Drizzle, Knex, etc.) instead of `CREATE TABLE IF NOT EXISTS` only.
7. **Backups** — automated snapshots + tested restore path.

## Application hardening

8. **Validation** — stricter email normalization, password policy (length + entropy hints); optional email verification flow.
9. **Observability** — structured logs, request IDs, error reporting (Sentry, etc.).
10. **Payload limits** — tune `express.json` limit; consider gzip and pagination if snapshots grow.
11. **JWT lifecycle** — shorter expiry + refresh tokens if sessions must stay long-lived securely.

## iOS client

12. **ATS** — remove localhost exceptions from release builds; use HTTPS API URLs via remote config or build settings.
13. **Token storage** — Keychain is appropriate; consider biometric gate for sensitive installs.

## Ops

14. **Health checks** — `GET /health` wired into load balancer.
15. **Staging** — mirror prod topology before inviting testers.

When this checklist is satisfied, link your deployment URL in internal docs and set `rally.apiBaseURL` (Developer field) or a release-time default for TestFlight builds.
