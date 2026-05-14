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
| PUT | `/api/me/sync` | Bearer JWT | Replace full sync payload |

Health: `GET /health`

## Notes

- Passwords are hashed with bcrypt; JWTs expire in 30 days.
- Sync is **replace-by-snapshot**: `PUT` stores the entire JSON document the client sends.
- **[Production checklist → `./DEPLOYMENT.md`](./DEPLOYMENT.md)** — HTTPS, Postgres, rate limits, ATS on iOS, etc.
