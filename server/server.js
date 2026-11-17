'use strict';

// Petri crew server: private daycare groups, an anonymous outbreak radar,
// a small feed with preset reactions, and the app's legal pages.

const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const GERM_IDS = new Set([
  'rhino', 'mystery', 'lingerer', 'chesty', 'whisper', 'pressure', 'noro', 'pinky', 'rona', 'arsy', 'strep', 'flu',
  'addy', 'meta', 'para', 'rota', 'coxy', 'slappy', 'lousy', 'wiggles', 'crusty', 'ringo', 'whoopy', 'poxy',
]);
const REACTIONS = new Set(['soup', 'tissue', 'tea', 'heart']);
const REPORT_REASONS = new Set(['name', 'abuse', 'other']);
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const MAX_MEMBERS = 40;
const MAX_BODY_BYTES = 4096;
const DAY = 24 * 3600 * 1000;
const RADAR_WINDOW = 7 * DAY;
const FEED_WINDOW = 30 * DAY;
const EVENT_LIFETIME = 400 * DAY;
const MASK_AFTER_REPORTERS = 2;
const MASKED_NAME = 'Parent';

// Names are matched after lowercasing, removing accents and undoing common letter swaps.
const BLOCKED_ANYWHERE = [
  'fuck', 'shit', 'bitch', 'cunt', 'asshole', 'nigger', 'nigga', 'faggot', 'retard', 'whore', 'slut', 'rapist',
  'hitler', 'nazi', 'porn', 'pedo', 'salope', 'connard', 'connasse', 'encule', 'putain', 'tapette', 'negre',
];
const BLOCKED_WORDS = [
  'sex', 'sexy', 'rape', 'dick', 'cock', 'pussy', 'tits', 'anal', 'cum', 'kkk', 'fag', 'pute', 'bite', 'cul',
  'merde', 'chatte', 'couille', 'viol', 'nique', 'pd',
];

class ApiError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

function normalize(text) {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/0/g, 'o').replace(/[1!|]/g, 'i').replace(/3/g, 'e').replace(/[4@]/g, 'a')
    .replace(/[5$]/g, 's').replace(/7/g, 't');
}

// Returns the cleaned name, or null when it is not acceptable.
function cleanName(raw, maxLength, extraBlocked) {
  if (typeof raw !== 'string') return null;
  const name = raw.replace(/[\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim();
  if (name.length < 2 || name.length > maxLength) return null;
  if (/https?:|www\.|\.com|@/i.test(name)) return null;
  const flat = normalize(name);
  const squeezed = flat.replace(/[^a-z]/g, '');
  const words = flat.split(/[^a-z]+/).filter(Boolean);
  const anywhere = BLOCKED_ANYWHERE.concat(extraBlocked);
  if (anywhere.some((bad) => squeezed.includes(bad))) return null;
  if (words.some((word) => BLOCKED_WORDS.includes(word))) return null;
  return name;
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function seasonStart(now) {
  const date = new Date(now);
  const year = date.getUTCMonth() >= 8 ? date.getUTCFullYear() : date.getUTCFullYear() - 1;
  return Date.UTC(year, 8, 1);
}

function escapeHtml(text) {
  return text.replace(/[&<>"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[char]));
}

function createApp(options = {}) {
  const dataDir = options.dataDir || process.env.DATA_DIR || path.join(__dirname, 'data');
  const dataFile = path.join(dataDir, 'petri.json');
  const adminToken = options.adminToken || process.env.ADMIN_TOKEN || '';
  const supportEmail = options.supportEmail || process.env.SUPPORT_EMAIL || '';
  const extraBlocked = (options.blockedWords || process.env.BLOCKED_WORDS || '')
    .split(',').map((word) => normalize(word.trim())).filter(Boolean);
  const clock = options.now || (() => Date.now());
  const legal = JSON.parse(fs.readFileSync(path.join(__dirname, 'legal.json'), 'utf8'));

  let db = { crews: [], members: [], events: [], reports: [] };
  if (fs.existsSync(dataFile)) {
    db = JSON.parse(fs.readFileSync(dataFile, 'utf8'));
  }

  const hits = new Map();

  function save() {
    fs.mkdirSync(dataDir, { recursive: true });
    const temp = dataFile + '.tmp';
    fs.writeFileSync(temp, JSON.stringify(db));
    fs.renameSync(temp, dataFile);
  }

  function limit(ip, bucket, max) {
    const now = clock();
    const key = bucket + ':' + ip;
    const recent = (hits.get(key) || []).filter((time) => now - time < 60000);
    if (recent.length >= max) {
      hits.set(key, recent);
      throw new ApiError(429, 'rate_limited');
    }
    recent.push(now);
    hits.set(key, recent);
  }

  function purge() {
    const now = clock();
    db.events = db.events.filter((event) => now - event.at < EVENT_LIFETIME);
    const populated = new Set(db.members.map((member) => member.crewID));
    db.crews = db.crews.filter((crew) => populated.has(crew.id));
    const crewIDs = new Set(db.crews.map((crew) => crew.id));
    db.events = db.events.filter((event) => crewIDs.has(event.crewID));
    db.reports = db.reports.filter((report) => crewIDs.has(report.crewID));
  }

  function newCode() {
    for (;;) {
      let code = '';
      for (const byte of crypto.randomBytes(6)) code += CODE_ALPHABET[byte % CODE_ALPHABET.length];
      if (!db.crews.some((crew) => crew.code === code)) return code;
    }
  }

  function addMember(crew, name) {
    const token = crypto.randomBytes(32).toString('hex');
    const taken = db.members.filter((member) => member.crewID === crew.id).length;
    const member = {
      id: crypto.randomUUID(), crewID: crew.id, name, colorIndex: taken % 6,
      tokenHash: hashToken(token), joinedAt: clock(),
    };
    db.members.push(member);
    return { member, token };
  }

  function authenticate(req) {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) throw new ApiError(401, 'unauthorized');
    const tokenHash = hashToken(token);
    const member = db.members.find((candidate) => candidate.tokenHash === tokenHash);
    if (!member) throw new ApiError(401, 'unauthorized');
    return member;
  }

  function isMasked(memberID) {
    const reporters = new Set(db.reports.filter((report) => report.memberID === memberID && !report.resolved)
      .map((report) => report.reporterID));
    return reporters.size >= MASK_AFTER_REPORTERS;
  }

  function stateFor(me) {
    const now = clock();
    const crew = db.crews.find((candidate) => candidate.id === me.crewID);
    const members = db.members.filter((member) => member.crewID === crew.id);
    const events = db.events.filter((event) => event.crewID === crew.id);
    const since = seasonStart(now);
    const shown = (member) => ({
      id: member.id,
      name: isMasked(member.id) ? MASKED_NAME : member.name,
      germs: events.filter((event) => event.memberID === member.id && event.named && event.at >= since).length,
      colorIndex: member.colorIndex,
    });

    const families = new Map();
    for (const event of events) {
      if (now - event.at > RADAR_WINDOW) continue;
      if (!families.has(event.germID)) families.set(event.germID, new Set());
      families.get(event.germID).add(event.memberID);
    }
    const radar = [...families.entries()]
      .filter(([, who]) => who.size >= 2)
      .map(([germID, who]) => ({ germID, families: who.size }))
      .sort((a, b) => b.families - a.families || a.germID.localeCompare(b.germID));

    const byID = new Map(members.map((member) => [member.id, member]));
    const feed = events
      .filter((event) => event.named && now - event.at <= FEED_WINDOW && byID.has(event.memberID))
      .sort((a, b) => b.at - a.at)
      .slice(0, 50)
      .map((event) => {
        const author = shown(byID.get(event.memberID));
        const reactions = {};
        const mine = [];
        for (const [kind, who] of Object.entries(event.reactions)) {
          if (who.length > 0) reactions[kind] = who.length;
          if (who.includes(me.id)) mine.push(kind);
        }
        return {
          id: event.id, memberID: event.memberID, name: author.name, colorIndex: author.colorIndex,
          germID: event.germID, at: event.at, reactions, mine,
        };
      });

    return {
      crew: { id: crew.id, name: crew.name, emblem: crew.emblem, code: crew.code, families: members.length },
      me: shown(me),
      members: members.map(shown),
      radar,
      feed,
    };
  }

  function removeMember(memberID) {
    db.members = db.members.filter((member) => member.id !== memberID);
    db.events = db.events.filter((event) => event.memberID !== memberID);
    for (const event of db.events) {
      for (const kind of Object.keys(event.reactions)) {
        event.reactions[kind] = event.reactions[kind].filter((id) => id !== memberID);
      }
    }
    db.reports = db.reports.filter((report) => report.memberID !== memberID && report.reporterID !== memberID);
    purge();
  }

  function legalPage(kind, lang) {
    const french = lang === 'fr';
    const title = kind === 'privacy'
      ? (french ? 'Politique de confidentialité' : 'Privacy Policy')
      : (french ? "Conditions d'utilisation" : 'Terms of Use');
    const sections = legal[kind].map((section) => {
      const heading = french ? section.title.fr : section.title.en;
      const body = french ? section.body.fr : section.body.en;
      return `<h2>${escapeHtml(heading)}</h2><p>${escapeHtml(body)}</p>`;
    }).join('');
    const updated = (french ? 'Dernière mise à jour : ' : 'Last updated ') + escapeHtml(legal.updated);
    const eula = kind === 'terms'
      ? `<p><a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">${french ? "Contrat de licence standard d'Apple (CLUF)" : "Apple's standard license agreement (EULA)"}</a></p>`
      : '';
    return page(`Petri · ${title}`, lang, `<h1>${escapeHtml(title)}</h1><p class="meta">${updated}</p>${sections}${eula}${contactBlock(french)}`);
  }

  function contactBlock(french) {
    if (!supportEmail) return '';
    const separator = french ? ' : ' : ': ';
    return `<p>Contact${separator}<a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a></p>`;
  }

  function supportPage(lang) {
    const french = lang === 'fr';
    const body = french
      ? '<h1>Soutien</h1><p>Une question, un problème ou un signalement ? Écris-nous, on répond en général en moins de 48 heures.</p>'
        + '<p>Pour supprimer tes données : dans l\'app, Réglages, puis Tout supprimer. Quitter un groupe supprime tes données du serveur.</p>'
      : '<h1>Support</h1><p>A question, a problem or something to report? Write to us. We usually answer within 48 hours.</p>'
        + '<p>To delete your data: in the app, open Settings, then Delete Everything. Leaving a crew deletes your data from the server.</p>';
    const links = french
      ? '<p><a href="/privacy?lang=fr">Politique de confidentialité</a> · <a href="/terms?lang=fr">Conditions d\'utilisation</a></p>'
      : '<p><a href="/privacy">Privacy Policy</a> · <a href="/terms">Terms of Use</a></p>';
    return page('Petri · Support', lang, body + contactBlock(french) + links);
  }

  function page(title, lang, body) {
    return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8">`
      + '<meta name="viewport" content="width=device-width, initial-scale=1">'
      + `<title>${escapeHtml(title)}</title>`
      + '<style>body{font:17px/1.55 -apple-system,system-ui,sans-serif;color:#1E1A26;background:#F6F1E7;margin:0}'
      + 'main{max-width:680px;margin:0 auto;padding:32px 22px 64px}h1{font-size:32px;margin:0 0 4px}'
      + 'h2{font-size:19px;margin:28px 0 6px}.meta{color:#6b6675}a{color:#3D7BFA}</style></head>'
      + `<body><main>${body}</main></body></html>`;
  }

  function language(req, url) {
    const asked = url.searchParams.get('lang');
    if (asked === 'fr' || asked === 'en') return asked;
    return /^fr\b/i.test(req.headers['accept-language'] || '') ? 'fr' : 'en';
  }

  async function readBody(req) {
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) throw new ApiError(413, 'too_large');
      chunks.push(chunk);
    }
    if (size === 0) return {};
    try {
      const parsed = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch {
      throw new ApiError(400, 'invalid');
    }
  }

  async function route(req, res) {
    const url = new URL(req.url, 'http://localhost');
    const key = req.method + ' ' + url.pathname;
    const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || req.socket.remoteAddress || 'unknown';

    if (key === 'GET /health') return json(res, 200, { ok: true });
    if (key === 'GET /privacy') return html(res, legalPage('privacy', language(req, url)));
    if (key === 'GET /terms') return html(res, legalPage('terms', language(req, url)));
    if (key === 'GET /support' || key === 'GET /') return html(res, supportPage(language(req, url)));

    limit(ip, 'all', 120);

    if (url.pathname.startsWith('/admin/')) {
      const header = req.headers.authorization || '';
      if (!adminToken || header !== 'Bearer ' + adminToken) throw new ApiError(401, 'unauthorized');
      if (key === 'GET /admin/reports') {
        const open = db.reports.filter((report) => !report.resolved).map((report) => {
          const member = db.members.find((candidate) => candidate.id === report.memberID);
          const crew = db.crews.find((candidate) => candidate.id === report.crewID);
          return { ...report, memberName: member ? member.name : null, crewName: crew ? crew.name : null };
        });
        return json(res, 200, { reports: open });
      }
      const match = url.pathname.match(/^\/admin\/members\/([0-9a-f-]{36})\/(remove|clear)$/);
      if (req.method === 'POST' && match) {
        if (match[2] === 'remove') {
          removeMember(match[1]);
        } else {
          for (const report of db.reports) {
            if (report.memberID === match[1]) report.resolved = true;
          }
        }
        save();
        return json(res, 200, { ok: true });
      }
      throw new ApiError(404, 'not_found');
    }

    if (key === 'POST /v1/crews') {
      limit(ip, 'join', 10);
      const body = await readBody(req);
      const name = cleanName(body.name, 24, extraBlocked);
      const displayName = cleanName(body.displayName, 20, extraBlocked);
      if (!name || !displayName) throw new ApiError(400, 'name_rejected');
      const emblem = Number.isInteger(body.emblem) && body.emblem >= 0 && body.emblem < 6 ? body.emblem : 0;
      const crew = { id: crypto.randomUUID(), name, emblem, code: newCode(), createdAt: clock() };
      db.crews.push(crew);
      const { member, token } = addMember(crew, displayName);
      save();
      return json(res, 200, { token, state: stateFor(member) });
    }

    if (key === 'POST /v1/crews/join') {
      limit(ip, 'join', 10);
      const body = await readBody(req);
      const code = typeof body.code === 'string' ? body.code.trim().toUpperCase() : '';
      const crew = db.crews.find((candidate) => candidate.code === code);
      if (!crew) throw new ApiError(404, 'invalid_code');
      const displayName = cleanName(body.displayName, 20, extraBlocked);
      if (!displayName) throw new ApiError(400, 'name_rejected');
      if (db.members.filter((member) => member.crewID === crew.id).length >= MAX_MEMBERS) {
        throw new ApiError(409, 'crew_full');
      }
      const { member, token } = addMember(crew, displayName);
      save();
      return json(res, 200, { token, state: stateFor(member) });
    }

    const me = authenticate(req);

    if (key === 'GET /v1/crew') return json(res, 200, stateFor(me));

    if (key === 'POST /v1/crew/events') {
      limit(me.id, 'events', 12);
      const body = await readBody(req);
      if (!GERM_IDS.has(body.germID)) throw new ApiError(400, 'invalid');
      db.events.push({
        id: crypto.randomUUID(), crewID: me.crewID, memberID: me.id, germID: body.germID,
        at: clock(), named: body.named === true, reactions: {},
      });
      purge();
      save();
      return json(res, 200, stateFor(me));
    }

    const reaction = url.pathname.match(/^\/v1\/crew\/events\/([0-9a-f-]{36})\/reactions$/);
    if (req.method === 'POST' && reaction) {
      const body = await readBody(req);
      if (!REACTIONS.has(body.kind)) throw new ApiError(400, 'invalid');
      const event = db.events.find((candidate) => candidate.id === reaction[1] && candidate.crewID === me.crewID);
      if (!event) throw new ApiError(404, 'not_found');
      const who = event.reactions[body.kind] || [];
      event.reactions[body.kind] = who.includes(me.id) ? who.filter((id) => id !== me.id) : who.concat(me.id);
      save();
      return json(res, 200, stateFor(me));
    }

    if (key === 'POST /v1/crew/me') {
      const body = await readBody(req);
      const displayName = cleanName(body.displayName, 20, extraBlocked);
      if (!displayName) throw new ApiError(400, 'name_rejected');
      me.name = displayName;
      save();
      return json(res, 200, stateFor(me));
    }

    if (key === 'POST /v1/crew/reports') {
      limit(me.id, 'reports', 10);
      const body = await readBody(req);
      const target = db.members.find((member) => member.id === body.memberID && member.crewID === me.crewID);
      if (!target || target.id === me.id) throw new ApiError(400, 'invalid');
      const reason = REPORT_REASONS.has(body.reason) ? body.reason : 'other';
      const repeat = db.reports.some((report) => report.reporterID === me.id && report.memberID === target.id && !report.resolved);
      if (!repeat) {
        db.reports.push({
          id: crypto.randomUUID(), crewID: me.crewID, reporterID: me.id, memberID: target.id,
          reason, at: clock(), resolved: false,
        });
        console.log(`[report] crew=${me.crewID} member=${target.id} reason=${reason}`);
        save();
      }
      return json(res, 200, stateFor(me));
    }

    if (key === 'DELETE /v1/crew/me') {
      removeMember(me.id);
      save();
      res.writeHead(204);
      return res.end();
    }

    throw new ApiError(404, 'not_found');
  }

  function json(res, status, body) {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify(body));
  }

  function html(res, body) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(body);
  }

  return http.createServer((req, res) => {
    route(req, res).catch((error) => {
      if (error instanceof ApiError) return json(res, error.status, { error: error.code });
      console.error(error);
      return json(res, 500, { error: 'server_error' });
    });
  });
}

module.exports = { createApp, cleanName };

if (require.main === module) {
  const port = Number(process.env.PORT) || 8080;
  createApp().listen(port, () => {
    console.log(`Petri crew server listening on ${port}`);
  });
}
