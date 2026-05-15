import bcrypt from "bcryptjs";
import Database from "better-sqlite3";
import cors from "cors";
import dotenv from "dotenv";
import express from "express";
import jwt from "jsonwebtoken";
import { mkdirSync } from "fs";
import { dirname } from "path";
import { fileURLToPath } from "url";
import { v4 as uuidv4 } from "uuid";

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: `${__dirname}/../.env` });

const PORT = Number(process.env.PORT || 8787);
const JWT_SECRET = process.env.JWT_SECRET || "dev-insecure-change-me";
const SQLITE_PATH = process.env.SQLITE_PATH || `${__dirname}/../data/rally.sqlite`;

mkdirSync(dirname(SQLITE_PATH), { recursive: true });

const db = new Database(SQLITE_PATH);
db.pragma("foreign_keys = ON");
db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY NOT NULL,
  email TEXT UNIQUE NOT NULL COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS user_sync (
  user_id TEXT PRIMARY KEY NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
`);

function defaultSnapshot() {
  const now = new Date().toISOString();
  return {
    version: 1,
    updatedAt: now,
    avatar: {
      id: uuidv4(),
      playerName: "",
      skinToneRaw: "medium",
      hairStyleRaw: "short",
      hairColorHex: "#3A2A1A",
      bodyTypeRaw: "athletic",
      equippedTopID: "rally.default.top",
      equippedBottomID: "rally.default.bottom",
      equippedShoesID: "rally.default.shoes",
      equippedRacketID: "rally.default.racket",
      hasCompletedSetup: false,
    },
    progress: {
      id: uuidv4(),
      coins: 0,
      xp: 0,
      bestScore: 0,
      bestCombo: 0,
      totalSessions: 0,
      totalPerfectHits: 0,
      totalGreatHits: 0,
      totalGoodHits: 0,
      totalMisses: 0,
      dailyStreak: 0,
      lastPlayDate: null,
    },
    trainingSessions: [],
    matchEntries: [],
    journalEntries: [],
  };
}

const insertUser = db.prepare(
  `INSERT INTO users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)`
);
const insertSync = db.prepare(
  `INSERT INTO user_sync (user_id, payload, updated_at) VALUES (?, ?, ?)`
);
const selectUserByEmail = db.prepare(`SELECT * FROM users WHERE email = ? COLLATE NOCASE`);
const selectUserById = db.prepare(`SELECT * FROM users WHERE id = ?`);
const selectSync = db.prepare(`SELECT payload, updated_at FROM user_sync WHERE user_id = ?`);
const updateSync = db.prepare(
  `UPDATE user_sync SET payload = ?, updated_at = ? WHERE user_id = ?`
);

function signToken(user) {
  return jwt.sign({ sub: user.id, email: user.email }, JWT_SECRET, { expiresIn: "30d" });
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing bearer token" });
  }
  try {
    const payload = jwt.verify(header.slice(7), JWT_SECRET);
    req.user = payload;
    next();
  } catch {
    return res.status(401).json({ error: "Invalid or expired token" });
  }
}

const app = express();
app.use(cors());
app.use(express.json({ limit: "12mb" }));

app.get("/health", (_, res) => {
  res.json({ ok: true });
});

app.post("/api/auth/register", (req, res) => {
  const email = String(req.body?.email || "")
    .trim()
    .toLowerCase();
  const password = String(req.body?.password || "");
  if (!email.includes("@") || email.length < 5) {
    return res.status(400).json({ error: "Valid email required" });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: "Password must be at least 8 characters" });
  }
  if (selectUserByEmail.get(email)) {
    return res.status(409).json({ error: "Email already registered" });
  }
  const id = uuidv4();
  const hash = bcrypt.hashSync(password, 12);
  const createdAt = new Date().toISOString();
  const snapshot = defaultSnapshot();

  const txn = db.transaction(() => {
    insertUser.run(id, email, hash, createdAt);
    insertSync.run(id, JSON.stringify(snapshot), snapshot.updatedAt);
  });
  try {
    txn();
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "Could not create account" });
  }

  const user = { id, email };
  const token = signToken(user);
  res.status(201).json({ token, user });
});

app.post("/api/auth/login", (req, res) => {
  const email = String(req.body?.email || "")
    .trim()
    .toLowerCase();
  const password = String(req.body?.password || "");
  const row = selectUserByEmail.get(email);
  if (!row || !bcrypt.compareSync(password, row.password_hash)) {
    return res.status(401).json({ error: "Invalid email or password" });
  }
  const user = { id: row.id, email: row.email };
  res.json({ token: signToken(user), user });
});

app.get("/api/me/sync", authMiddleware, (req, res) => {
  const row = selectSync.get(req.user.sub);
  if (!row) {
    return res.status(404).json({ error: "No sync data" });
  }
  let payload;
  try {
    payload = JSON.parse(row.payload);
  } catch {
    return res.status(500).json({ error: "Corrupt sync payload" });
  }
  payload.updatedAt = row.updated_at;
  res.json(payload);
});

/**
 * Conflict-aware PUT.
 *
 * - PlayerProgress numerics (best*, total*, dailyStreak, coins, xp,
 *   lastPlayDate) merge max-wins against whatever the server already has.
 *   That keeps multi-device users from losing accrued totals when a stale
 *   device pushes after a fresh one.
 * - Avatar, collections (training/match/journal), and singleton IDs come
 *   from the request body — these are user-edited, not accrued, so
 *   client-wins is correct there.
 *
 * The merged snapshot is echoed in the response under `merged` so the
 * client can apply just the reconciled progress fields locally without a
 * second GET round-trip. See `RallySyncPayload.swift` for the mirrored
 * client-side merge helper.
 */
function mergeProgressMaxWins(serverProgress, clientProgress) {
  if (!serverProgress) return clientProgress;
  if (!clientProgress) return serverProgress;
  const max = (a, b) => Math.max(Number(a) || 0, Number(b) || 0);
  const latestDate = (a, b) => {
    if (!a) return b;
    if (!b) return a;
    return new Date(a) > new Date(b) ? a : b;
  };
  return {
    id: clientProgress.id || serverProgress.id,
    coins: max(serverProgress.coins, clientProgress.coins),
    xp: max(serverProgress.xp, clientProgress.xp),
    bestScore: max(serverProgress.bestScore, clientProgress.bestScore),
    bestCombo: max(serverProgress.bestCombo, clientProgress.bestCombo),
    totalSessions: max(serverProgress.totalSessions, clientProgress.totalSessions),
    totalPerfectHits: max(serverProgress.totalPerfectHits, clientProgress.totalPerfectHits),
    totalGreatHits: max(serverProgress.totalGreatHits, clientProgress.totalGreatHits),
    totalGoodHits: max(serverProgress.totalGoodHits, clientProgress.totalGoodHits),
    totalMisses: max(serverProgress.totalMisses, clientProgress.totalMisses),
    dailyStreak: max(serverProgress.dailyStreak, clientProgress.dailyStreak),
    lastPlayDate: latestDate(serverProgress.lastPlayDate, clientProgress.lastPlayDate),
  };
}

app.put("/api/me/sync", authMiddleware, (req, res) => {
  const body = req.body;
  if (!body || typeof body !== "object") {
    return res.status(400).json({ error: "JSON body required" });
  }

  let serverSnapshot = null;
  const existing = selectSync.get(req.user.sub);
  if (existing) {
    try {
      serverSnapshot = JSON.parse(existing.payload);
    } catch {
      serverSnapshot = null;
    }
  }

  if (serverSnapshot && body.progress) {
    body.progress = mergeProgressMaxWins(serverSnapshot.progress, body.progress);
  }

  const updatedAt = new Date().toISOString();
  body.updatedAt = updatedAt;
  const json = JSON.stringify(body);
  const result = updateSync.run(json, updatedAt, req.user.sub);
  if (result.changes === 0) {
    return res.status(404).json({ error: "No sync row — re-register or contact support" });
  }
  res.json({ ok: true, updatedAt, merged: body });
});

app.listen(PORT, () => {
  console.log(`Rally API listening on http://127.0.0.1:${PORT}`);
});
