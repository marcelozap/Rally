import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import net from 'node:net';
import Database from 'better-sqlite3';

test('deletion requires password, cascades data, revokes tokens and isolates users', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'vela-delete-'));
  const databasePath = join(directory, 'test.sqlite');
  const probe = net.createServer();
  await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  const server = spawn(process.execPath, ['src/server.js'], { cwd: new URL('..', import.meta.url), env: { ...process.env, PORT: String(port), SQLITE_PATH: databasePath, JWT_SECRET: 'test-secret' }, stdio: 'pipe' });
  let output = '';
  server.stderr.on('data', c => { output += c; });
  const request = (path, method = 'GET', body, token) => fetch(`http://127.0.0.1:${port}${path}`, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) });
  try {
    let ready = false;
    for (let i = 0; i < 100; i++) {
      try { ready = (await request('/health')).ok; } catch {}
      if (ready) break;
      if (server.exitCode !== null) throw new Error(output);
      await new Promise(r => setTimeout(r, 50));
    }
    assert.ok(ready, output);
    const credentials = { email: 'delete@example.com', password: 'test-password' };
    const account = await (await request('/api/auth/register', 'POST', credentials)).json();
    const other = await (await request('/api/auth/register', 'POST', { email: 'keep@example.com', password: 'other-password' })).json();
    assert.equal((await request('/api/me', 'DELETE', credentials)).status, 401);
    assert.equal((await request('/api/me', 'DELETE', { password: 'wrong' }, account.token)).status, 403);
    assert.equal((await request('/api/me/sync', 'GET', undefined, account.token)).status, 200);
    assert.equal((await request('/api/me', 'DELETE', credentials, account.token)).status, 204);
    assert.equal((await request('/api/me/sync', 'GET', undefined, account.token)).status, 401);
    assert.equal((await request('/api/me/sync', 'PUT', {}, account.token)).status, 401);
    assert.equal((await request('/api/auth/login', 'POST', credentials)).status, 401);
    assert.equal((await request('/api/me/sync', 'GET', undefined, other.token)).status, 200);
    const db = new Database(databasePath, { readonly: true });
    try {
      assert.equal(db.prepare('SELECT COUNT(*) AS n FROM users WHERE id = ?').get(account.user.id).n, 0);
      assert.equal(db.prepare('SELECT COUNT(*) AS n FROM user_sync WHERE user_id = ?').get(account.user.id).n, 0);
    } finally { db.close(); }
    const replacement = await request('/api/auth/register', 'POST', credentials);
    assert.equal(replacement.status, 201);
    assert.notEqual((await replacement.json()).user.id, account.user.id);
    assert.equal((await request('/api/me/sync', 'GET', undefined, account.token)).status, 401);
  } finally {
    server.kill();
    if (server.exitCode === null) await new Promise(r => server.once('exit', r));
    rmSync(directory, { recursive: true, force: true });
  }
});
