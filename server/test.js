'use strict';

// End-to-end checks for the crew server. Run with: node server/test.js

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp, cleanName } = require('./server.js');
const legal = require('./legal.json');

const DAY = 24 * 3600 * 1000;

async function main() {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'germigo-test-'));
  let now = Date.UTC(2026, 10, 17, 15, 0, 0);
  const options = {
    dataDir, adminToken: 'admin-secret', supportEmail: 'help@example.org', publisherName: 'Test Publisher',
    writeDelay: 0, now: () => now,
  };
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
    return {
      status: response.status, headers: response.headers,
      data: type.includes('json') && text ? JSON.parse(text) : text,
    };
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
  assert.ok(privacy.data.includes(legal.web.privacyTitle.en));
  assert.ok(privacy.data.includes('Test Publisher'));
  assert.ok((await call('GET', '/privacy?lang=fr')).data.includes(legal.web.privacyTitle.fr));
  const frenchTerms = (await call('GET', '/terms', { headers: { 'Accept-Language': 'fr-CA' } })).data;
  assert.ok(frenchTerms.includes(legal.web.eulaLabel.fr));
  assert.match((await call('GET', '/terms')).data, /stdeula/);
  const support = (await call('GET', '/support?lang=fr')).data;
  assert.match(support, /help@example\.org/);
  assert.ok(support.includes(legal.web.supportIntro.fr.split(' ')[0]));

  // The landing page a share card points to
  const landing = await call('GET', '/get');
  assert.equal(landing.status, 200);
  assert.ok(landing.data.includes(legal.web.landingTagline.en));
  assert.ok(landing.data.includes(legal.web.landingSoon.en));
  assert.ok((await call('GET', '/?lang=fr')).data.includes(legal.web.landingTagline.fr));

  // Security headers, and a moderation page that carries no data
  assert.equal(privacy.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(privacy.headers.get('x-frame-options'), 'DENY');
  assert.match(privacy.headers.get('content-security-policy'), /default-src 'none'/);
  assert.equal(privacy.headers.get('content-security-policy').includes('script-src'), false);
  assert.equal((await call('GET', '/health')).headers.get('x-content-type-options'), 'nosniff');
  const adminPage = await call('GET', '/admin');
  assert.equal(adminPage.status, 200);
  const nonce = /script-src 'nonce-([^']+)'/.exec(adminPage.headers.get('content-security-policy'))[1];
  assert.ok(adminPage.data.includes(`<script nonce="${nonce}">`));
  assert.equal(adminPage.data.includes('admin-secret'), false);

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

  // A member of another crew cannot touch this one
  const outsider = (await call('POST', '/v1/crews', { body: { name: 'Wasps', displayName: 'Zed', emblem: 1 } })).data;
  assert.equal((await call('POST', `/v1/crew/events/${eventID}/reactions`, { token: outsider.token, body: { kind: 'tea' } })).status, 404);
  const alexID = state.members.find((member) => member.name === 'Alex').id;
  assert.equal((await call('POST', '/v1/crew/reports', { token: outsider.token, body: { memberID: alexID, reason: 'name' } })).data.error, 'invalid');
  const outsiderView = (await call('GET', '/v1/crew', { token: outsider.token })).data;
  assert.equal(outsiderView.crew.name, 'Wasps');
  assert.equal(outsiderView.members.length, 1);
  assert.deepEqual(outsiderView.feed, []);
  assert.equal((await call('GET', '/v1/crew', { token: alex })).data.feed[0].reactions.tea, undefined);
  assert.equal((await call('DELETE', '/v1/crew/me', { token: outsider.token })).status, 204);

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
  assert.equal((await call('GET', '/admin/reports', { token: 'admin-secre' })).status, 401);
  assert.equal((await call('GET', '/admin/reports', { token: 'admin-secret-and-more' })).status, 401);
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
  const stored = JSON.parse(fs.readFileSync(path.join(dataDir, 'germigo.json'), 'utf8'));
  assert.equal(stored.members.some((member) => member.id === marieID), false);
  assert.equal(stored.events.some((event) => event.memberID === marieID), false);
  assert.equal(JSON.stringify(stored).includes(alex), false);

  // Admin removal, then an emptied crew disappears
  const jonID = state.members.find((member) => member.name === 'Jonathan').id;
  await call('POST', `/admin/members/${jonID}/remove`, { token: 'admin-secret' });
  assert.equal((await call('GET', '/v1/crew', { token: jon })).status, 401);
  const rotated = (await call('GET', '/v1/crew', { token: alex })).data.crew.code;
  assert.notEqual(rotated, code);
  assert.equal((await call('POST', '/v1/crews/join', { body: { code, displayName: 'Jonathan' } })).data.error, 'invalid_code');
  assert.equal((await call('DELETE', '/v1/crew/me', { token: alex })).status, 204);
  assert.equal(JSON.parse(fs.readFileSync(path.join(dataDir, 'germigo.json'), 'utf8')).crews.length, 0);

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
  assert.equal(JSON.parse(fs.readFileSync(path.join(dataDir, 'germigo.json'), 'utf8')).events.length, 1);

  // A member who has not connected for that long is removed with the old events
  assert.equal((await call('GET', '/v1/crew', { token: second.token })).status, 401);
  assert.equal((await call('GET', '/v1/crew', { token: pat })).data.crew.families, 1);

  // A retried share is stored once
  now += 61000;
  const clientID = '0b0e7a52-2f0c-4a43-9a53-3d5a0c1b2e11';
  await call('POST', '/v1/crew/events', { token: pat, body: { germID: 'strep', named: true, clientID } });
  state = (await call('POST', '/v1/crew/events', { token: pat, body: { germID: 'strep', named: true, clientID } })).data;
  assert.equal(state.feed.filter((event) => event.germID === 'strep').length, 1);

  // A win shows in the feed under a name, and stays out of the radar and the germ count
  now += 61000;
  const hornets = (await call('POST', '/v1/crews', { body: { name: 'Hornets', displayName: 'Kim', emblem: 2 } })).data;
  const lee = (await call('POST', '/v1/crews/join', { body: { code: hornets.state.crew.code, displayName: 'Lee' } })).data.token;
  const win = (body) => call('POST', '/v1/crew/events', { token: hornets.token, body: { germID: 'flu', ...body } });
  assert.equal((await win({ kind: 'beat', named: false })).data.error, 'invalid');
  assert.equal((await win({ kind: 'won', named: true })).data.error, 'invalid');
  await win({ named: true });
  now += 1000;
  state = (await win({ kind: 'beat', named: true })).data;
  assert.deepEqual(state.feed.map((event) => event.kind), ['beat', 'caught']);
  assert.equal(state.me.germs, 1);
  state = (await call('POST', '/v1/crew/events', { token: lee, body: { germID: 'flu', kind: 'beat', named: true } })).data;
  assert.deepEqual(state.radar, []);
  assert.equal(state.me.germs, 0);

  // Daily cap on shares per member
  let accepted = 0;
  let capped = false;
  for (let attempt = 0; attempt < 45; attempt += 1) {
    now += 7000;
    const result = await call('POST', '/v1/crew/events', { token: pat, body: { germID: 'rhino', named: false } });
    if (result.status === 200) accepted += 1;
    if (result.status === 429) capped = true;
  }
  assert.equal(accepted, 38);
  assert.equal(capped, true);

  // Rate limit on sign-ups; a forged forwarding header does not reset it
  now += DAY;
  let limited = 0;
  for (let attempt = 0; attempt < 14; attempt += 1) {
    const result = await call('POST', '/v1/crews/join', {
      body: { code: 'AAAAAA', displayName: 'Spam' }, headers: { 'X-Forwarded-For': `10.0.0.${attempt}` },
    });
    if (result.status === 429) limited += 1;
  }
  assert.equal(limited, 4);

  // Oversized and malformed bodies
  now += 61000;
  assert.equal((await call('POST', '/v1/crews', { body: { name: 'x'.repeat(5000), displayName: 'Sam' } })).status, 413);
  const malformed = await fetch(base + '/v1/crews', { method: 'POST', body: '{nope' });
  assert.equal(malformed.status, 400);
  assert.equal((await call('GET', '/v1/unknown', { token: pat })).status, 404);

  await new Promise((resolve) => server.close(resolve));

  // Behind one trusted proxy, the address the proxy appended decides, not the client's own claim
  const proxied = createApp({ ...options, dataDir: fs.mkdtempSync(path.join(os.tmpdir(), 'germigo-proxy-')), trustProxyHops: 1 });
  const listed = createApp({ ...options, dataDir: fs.mkdtempSync(path.join(os.tmpdir(), 'germigo-store-')),
    appStoreURL: 'https://apps.apple.com/app/id000000000' });
  await new Promise((resolve) => listed.listen(0, resolve));
  const listedPage = await (await fetch(`http://127.0.0.1:${listed.address().port}/get`)).text();
  assert.ok(listedPage.includes('https://apps.apple.com/app/id000000000'));
  await new Promise((resolve) => listed.close(resolve));
  await new Promise((resolve) => proxied.listen(0, resolve));
  base = `http://127.0.0.1:${proxied.address().port}`;
  now += DAY;
  let blocked = 0;
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const result = await call('POST', '/v1/crews/join', {
      body: { code: 'AAAAAA', displayName: 'Spam' }, headers: { 'X-Forwarded-For': `10.9.9.${attempt}, 203.0.113.7` },
    });
    if (result.status === 429) blocked += 1;
  }
  assert.equal(blocked, 2);
  const other = await call('POST', '/v1/crews/join', {
    body: { code: 'AAAAAA', displayName: 'Spam' }, headers: { 'X-Forwarded-For': '203.0.113.8' },
  });
  assert.equal(other.status, 404);
  await new Promise((resolve) => proxied.close(resolve));

  // Small changes are grouped into one write; membership changes are written at once
  const slowDir = fs.mkdtempSync(path.join(os.tmpdir(), 'germigo-slow-'));
  const slow = createApp({ ...options, dataDir: slowDir, writeDelay: 60000 });
  await new Promise((resolve) => slow.listen(0, resolve));
  base = `http://127.0.0.1:${slow.address().port}`;
  now += DAY;
  const solo = (await call('POST', '/v1/crews', { body: { name: 'Fireflies', displayName: 'Lou', emblem: 1 } })).data;
  const slowFile = path.join(slowDir, 'germigo.json');
  assert.equal(JSON.parse(fs.readFileSync(slowFile, 'utf8')).members.length, 1);
  await call('POST', '/v1/crew/events', { token: solo.token, body: { germID: 'flu', named: true } });
  assert.equal(JSON.parse(fs.readFileSync(slowFile, 'utf8')).events.length, 0);
  slow.flush();
  assert.equal(JSON.parse(fs.readFileSync(slowFile, 'utf8')).events.length, 1);
  await call('POST', '/v1/crew/events', { token: solo.token, body: { germID: 'noro', named: true } });

  // One address cannot create crews without end
  let crewsMade = 1;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    now += 7000;
    const made = await call('POST', '/v1/crews', { body: { name: `Hive ${attempt + 1}`, displayName: 'Lou', emblem: 0 } });
    if (made.status === 200) crewsMade += 1;
  }
  assert.equal(crewsMade, 5);

  await new Promise((resolve) => slow.close(resolve));
  assert.equal(JSON.parse(fs.readFileSync(slowFile, 'utf8')).events.length, 2);

  fs.rmSync(dataDir, { recursive: true, force: true });
  fs.rmSync(slowDir, { recursive: true, force: true });
  console.log('crew server: all checks passed');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
