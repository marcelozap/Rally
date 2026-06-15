# Rally API

Small REST backend for **Rally iOS**: email/password accounts, JWT sessions, and a JSON **sync blob** for avatar, progression, training logs, matches, and journal entries.

## Setup

```bash
cd backend
cp .env.example .env
# Edit .env — set JWT_SECRET to something long and random.
npm install
npm run dev
```

Default URL: `http://127.0.0.1:8787`

The iOS app points at this URL in **Simulator** via `RallyAPIConfig` (override in Settings → Rally API base URL once exposed in-app, or change the default in code for devices).

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/register` | — | `{ "email", "password" }` → `{ token, user }` |
| POST | `/api/auth/login` | — | Same |
| GET | `/api/me/sync` | Bearer JWT | Full sync payload |
| PUT | `/api/me/sync` | Bearer JWT | Replace full sync payload, max-wins merge progression numerics |
| GET | `/api/tunables` | — | Remote gameplay tuning manifest from `data/tunables.json` |
| PUT | `/api/tunables` | `X-Admin-Secret` | Admin-only update for allowed gameplay tuning keys |

Health: `GET /health`

## Notes

- Passwords are hashed with bcrypt; JWTs expire in 30 days.
- Sync is **replace-by-snapshot** with two safeguards: progression numerics merge with max-wins, and avatar/gear saves may send `X-Rally-Expected-Revision` so stale appearance edits return `409` instead of overwriting another device.
- `GET /api/me/sync` and successful `PUT /api/me/sync` return `X-Rally-Current-Revision`.
- Remote tunables are editable in `backend/data/tunables.json`; local SQLite files in that folder stay git-ignored.
- **[Production checklist → `./DEPLOYMENT.md`](./DEPLOYMENT.md)** — HTTPS, Postgres, rate limits, ATS on iOS, etc.
