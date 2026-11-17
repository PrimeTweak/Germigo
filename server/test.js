'use strict';

// End-to-end checks for the crew server. Run with: node server/test.js

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp, cleanName } = require('./server.js');

const DAY = 24 * 3600 * 1000;

async function main() {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'petri-test-'));
  let now = Date.UTC(2026, 10, 17, 15, 0, 0);
  const options = { dataDir, adminToken: 'admin-secret', supportEmail: 'help@example.org', now: () => now };
  let server = createApp(options);
  await new Promise((resolve) => server.listen(0, resolve));
  let base = `http://127.0.0.1:${server.address().port}`;

  async function call(method, route, { token, body, headers } = {}) {
    const response = await fetch(base + route, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
        ...(headers || {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await response.text();
    const type = response.headers.get('content-type') || '';
    return { status: response.status, data: type.includes('json') && text ? JSON.parse(text) : text };
  }

  // Name filter
  assert.equal(cleanName('  Marie  ', 20, []), 'Marie');
  assert.equal(cleanName('A', 20, []), null);
  assert.equal(cleanName('x'.repeat(21), 20, []), null);
  assert.equal(cleanName('F.u.c.k you', 20, []), null);
  assert.equal(cleanName('sh1t head', 20, []), null);
  assert.equal(cleanName('Essex Mom', 20, []), 'Essex Mom');
  assert.equal(cleanName('visit www.spam.com', 24, []), null);
  assert.equal(cleanName('Ladybugs', 24, ['ladybug']), null);

  // Public pages
  assert.equal((await call('GET', '/health')).data.ok, true);
  const privacy = await call('GET', '/privacy');
  assert.equal(privacy.status, 200);
  assert.match(privacy.data, /Privacy Policy/);
  assert.match((await call('GET', '/privacy?lang=fr')).data, /Politique de confidentialité/);
  assert.match((await call('GET', '/terms', { headers: { 'Accept-Language': 'fr-CA' } })).data, /Conditions d'utilisation/);
  assert.match((await call('GET', '/terms')).data, /stdeula/);
  assert.match((await call('GET', '/support')).data, /help@example\.org/);

  // Create and join
  assert.equal((await call('POST', '/v1/crews', { body: { name: 'Ladybugs', displayName: 'shit', emblem: 0 } })).data.error, 'name_rejected');
  const created = await call('POST', '/v1/crews', { body: { name: 'Ladybugs', displayName: 'Alex', emblem: 2 } });
  assert.equal(created.status, 200);
  const alex = created.data.token;
  const code = created.data.state.crew.code;
  assert.match(code, /^[A-Z2-9]{6}$/);
  assert.equal(created.data.state.crew.families, 1);
  assert.equal(created.data.state.crew.emblem, 2);

  assert.equal((await call('POST', '/v1/crews/join', { body: { code: 'ZZZZZZ', displayName: 'Marie' } })).data.error, 'invalid_code');
  const marie = (await call('POST', '/v1/crews/join', { body: { code: code.toLowerCase(), displayName: 'Marie' } })).data.token;
  const jon = (await call('POST', '/v1/crews/join', { body: { code, displayName: 'Jon' } })).data.token;
  assert.equal((await call('GET', '/v1/crew', { token: alex })).data.crew.families, 3);
  assert.equal((await call('GET', '/v1/crew', { token: 'nope' })).data.error, 'unauthorized');
  assert.equal((await call('GET', '/v1/crew')).status, 401);

  // Radar needs two families; anonymous events stay out of the feed
  assert.equal((await call('POST', '/v1/crew/events', { token: alex, body: { germID: 'not-a-germ', named: false } })).data.error, 'invalid');
  let state = (await call('POST', '/v1/crew/events', { token: alex, body: { germID: 'noro', named: false } })).data;
  assert.deepEqual(state.radar, []);
  assert.deepEqual(state.feed, []);
  state = (await call('POST', '/v1/crew/events', { token: marie, body: { germID: 'noro', named: true } })).data;
  assert.deepEqual(state.radar, [{ germID: 'noro', families: 2 }]);
  assert.equal(state.feed.length, 1);
  assert.equal(state.feed[0].name, 'Marie');
  assert.equal(state.me.germs, 1);
  const eventID = state.feed[0].id;
  state = (await call('GET', '/v1/crew', { token: alex })).data;
  assert.equal(state.me.germs, 0);
  assert.equal(state.members.find((member) => member.name === 'Marie').germs, 1);

  // Reactions toggle
  state = (await call('POST', `/v1/crew/events/${eventID}/reactions`, { token: alex, body: { kind: 'soup' } })).data;
  assert.deepEqual(state.feed[0].reactions, { soup: 1 });
  assert.deepEqual(state.feed[0].mine, ['soup']);
  state = (await call('POST', `/v1/crew/events/${eventID}/reactions`, { token: jon, body: { kind: 'soup' } })).data;
  assert.deepEqual(state.feed[0].reactions, { soup: 2 });
  state = (await call('POST', `/v1/crew/events/${eventID}/reactions`, { token: alex, body: { kind: 'soup' } })).data;
  assert.deepEqual(state.feed[0].reactions, { soup: 1 });
  assert.deepEqual(state.feed[0].mine, []);
  assert.equal((await call('POST', `/v1/crew/events/${eventID}/reactions`, { token: alex, body: { kind: 'bomb' } })).data.error, 'invalid');

  // Rename
  assert.equal((await call('POST', '/v1/crew/me', { token: jon, body: { displayName: 'c0nnard' } })).data.error, 'name_rejected');
  assert.equal((await call('POST', '/v1/crew/me', { token: jon, body: { displayName: 'Jonathan' } })).data.me.name, 'Jonathan');

  // Reports: two reporters mask the name, and the admin can review and clear
  const marieID = state.members.find((member) => member.name === 'Marie').id;
  await call('POST', '/v1/crew/reports', { token: alex, body: { memberID: marieID, reason: 'name' } });
  await call('POST', '/v1/crew/reports', { token: alex, body: { memberID: marieID, reason: 'name' } });
  state = (await call('GET', '/v1/crew', { token: jon })).data;
  assert.equal(state.members.find((member) => member.id === marieID).name, 'Marie');
  state = (await call('POST', '/v1/crew/reports', { token: jon, body: { memberID: marieID, reason: 'abuse' } })).data;
  assert.equal(state.members.find((member) => member.id === marieID).name, 'Parent');
  assert.equal(state.feed[0].name, 'Parent');
  assert.equal((await call('GET', '/admin/reports')).status, 401);
  const reports = (await call('GET', '/admin/reports', { token: 'admin-secret' })).data.reports;
  assert.equal(reports.length, 2);
  assert.equal(reports[0].memberName, 'Marie');
  assert.equal(reports[0].crewName, 'Ladybugs');
  await call('POST', `/admin/members/${marieID}/clear`, { token: 'admin-secret' });
  state = (await call('GET', '/v1/crew', { token: jon })).data;
  assert.equal(state.members.find((member) => member.id === marieID).name, 'Marie');

  // Data survives a restart
  await new Promise((resolve) => server.close(resolve));
  server = createApp(options);
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
  state = (await call('GET', '/v1/crew', { token: alex })).data;
  assert.equal(state.crew.name, 'Ladybugs');
  assert.equal(state.feed.length, 1);

  // Leaving deletes the member's data
  assert.equal((await call('DELETE', '/v1/crew/me', { token: marie })).status, 204);
  assert.equal((await call('GET', '/v1/crew', { token: marie })).status, 401);
  state = (await call('GET', '/v1/crew', { token: alex })).data;
  assert.equal(state.crew.families, 2);
  assert.deepEqual(state.feed, []);
  assert.deepEqual(state.radar, []);
  const stored = JSON.parse(fs.readFileSync(path.join(dataDir, 'petri.json'), 'utf8'));
  assert.equal(stored.members.some((member) => member.id === marieID), false);
  assert.equal(stored.events.some((event) => event.memberID === marieID), false);
  assert.equal(JSON.stringify(stored).includes(alex), false);

  // Admin removal, then an emptied crew disappears
  const jonID = state.members.find((member) => member.name === 'Jonathan').id;
  await call('POST', `/admin/members/${jonID}/remove`, { token: 'admin-secret' });
  assert.equal((await call('GET', '/v1/crew', { token: jon })).status, 401);
  assert.equal((await call('DELETE', '/v1/crew/me', { token: alex })).status, 204);
  assert.equal(JSON.parse(fs.readFileSync(path.join(dataDir, 'petri.json'), 'utf8')).crews.length, 0);

  // Old events expire and the radar window is seven days
  now += 61000;
  const second = (await call('POST', '/v1/crews', { body: { name: 'Bumblebees', displayName: 'Sam', emblem: 9 } })).data;
  assert.equal(second.state.crew.emblem, 0);
  const pat = (await call('POST', '/v1/crews/join', { body: { code: second.state.crew.code, displayName: 'Pat' } })).data.token;
  await call('POST', '/v1/crew/events', { token: second.token, body: { germID: 'flu', named: true } });
  state = (await call('POST', '/v1/crew/events', { token: pat, body: { germID: 'flu', named: true } })).data;
  assert.equal(state.radar.length, 1);
  now += 8 * DAY;
  state = (await call('GET', '/v1/crew', { token: pat })).data;
  assert.deepEqual(state.radar, []);
  assert.equal(state.feed.length, 2);
  now += 30 * DAY;
  assert.equal((await call('GET', '/v1/crew', { token: pat })).data.feed.length, 0);
  now += 400 * DAY;
  await call('POST', '/v1/crew/events', { token: pat, body: { germID: 'rhino', named: false } });
  assert.equal(JSON.parse(fs.readFileSync(path.join(dataDir, 'petri.json'), 'utf8')).events.length, 1);

  // Rate limit on sign-ups
  now += 61000;
  let limited = false;
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const result = await call('POST', '/v1/crews/join', { body: { code: 'AAAAAA', displayName: 'Spam' } });
    if (result.status === 429) limited = true;
  }
  assert.equal(limited, true);

  // Oversized and malformed bodies
  now += 61000;
  assert.equal((await call('POST', '/v1/crews', { body: { name: 'x'.repeat(5000), displayName: 'Sam' } })).status, 413);
  const malformed = await fetch(base + '/v1/crews', { method: 'POST', body: '{nope' });
  assert.equal(malformed.status, 400);
  assert.equal((await call('GET', '/v1/unknown', { token: pat })).status, 404);

  await new Promise((resolve) => server.close(resolve));
  fs.rmSync(dataDir, { recursive: true, force: true });
  console.log('crew server: all checks passed');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
