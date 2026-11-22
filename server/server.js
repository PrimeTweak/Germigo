'use strict';

// Germily server: private crews of families, an anonymous radar of germs going around,
// a feed of germs caught and beaten with preset reactions, daycare notices, and the app's legal pages.

const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { createPusher } = require('./push.js');
const { parseSubject, reply, createMailer, flatten, fill } = require('./mail.js');
const TEXT = require('./text.json');

const GERM_IDS = new Set([
  'rhino', 'mystery', 'lingerer', 'chesty', 'whisper', 'pressure', 'noro', 'pinky', 'rona', 'arsy', 'strep', 'flu',
  'addy', 'meta', 'para', 'rota', 'coxy', 'slappy', 'lousy', 'wiggles', 'crusty', 'ringo', 'whoopy', 'poxy',
]);
const REACTIONS = new Set(['soup', 'tissue', 'tea', 'heart']);
const EVENT_KINDS = new Set(['caught', 'beat']);
const REPORT_REASONS = new Set(['name', 'abuse', 'other']);
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const MAX_MEMBERS = 40;
const MAX_BODY_BYTES = 4096;
const MAX_EMAIL_BYTES = 512 * 1024;
const MAX_GROUPS = 12;
const MAX_SUBSCRIPTIONS = 600;
const NOTE_LIMIT = 280;
// A note is a sentence, so a link is a scheme, a www, a .com or an email address in it.
const NOTE_LINK_PATTERN = /https?:\/\/|www\.|\.com\b|\S@\S/i;
// Whether the illness is only seen or confirmed, and the ready-made lines a daycare can add, in display order.
const NOTICE_STATUSES = new Set(['symptoms', 'confirmed']);
const NOTICE_MESSAGES = ['watch', 'cleaning', 'stay_home', 'tell_us', 'public_health'];
const CREW_CODE_LENGTH = 8;
const DAYCARE_CODE_LENGTH = 8;
const NOTICE_WINDOW = 60 * 24 * 3600 * 1000;
const PUSH_TOKEN_PATTERN = /^[0-9a-f]{64,200}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MINUTE = 60 * 1000;
const DAY = 24 * 3600 * 1000;
const MAX_LIMIT_KEYS = 50000;
const WRITE_DELAY = 250;
const HEADERS_TIMEOUT = 10 * 1000;
const REQUEST_TIMEOUT = 30 * 1000;
const MAX_CONNECTIONS = 1000;
const MAX_LESSONS_BYTES = 1_000_000;
const PUBLIC_PAGES = new Set(['GET /', 'GET /get', 'GET /privacy', 'GET /terms', 'GET /health-data', 'GET /support', 'GET /lessons.json']);
const LIMITS = {
  all: [120, MINUTE],
  pages: [120, MINUTE],
  join: [10, MINUTE],
  crewsPerDay: [5, DAY],
  events: [12, MINUTE],
  eventsPerDay: [40, DAY],
  reactions: [60, MINUTE],
  rename: [10, MINUTE],
  reports: [10, MINUTE],
  admin: [20, MINUTE],
  daycaresPerDay: [3, DAY],
  noticesPerDay: [10, DAY],
  repliesPerDay: [20, DAY],
  subscriptionsPerDay: [40, DAY],
  daycareUpdates: [20, MINUTE],
  codeRenewals: [5, DAY],
  inbound: [60, MINUTE],
};
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const RADAR_WINDOW = 7 * DAY;
// Fewer families than this could point to who is sick in a small crew.
const RADAR_MIN_FAMILIES = 3;
const FEED_WINDOW = 30 * DAY;
const EVENT_LIFETIME = 400 * DAY;
const NOTICE_LIFETIME = 90 * DAY;
const SWEEP_INTERVAL = 60 * MINUTE;
const MEMBER_LIFETIME = 400 * DAY;
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
// Notes are matched word by word, plurals included, without letter swaps, on insults with no everyday meaning.
const NOTE_BLOCKED_WORDS = new Set([
  'fuck', 'fucking', 'fucked', 'fucker', 'motherfucker', 'shit', 'shitty', 'bullshit', 'bitch', 'bitches', 'cunt',
  'asshole', 'nigger', 'nigga', 'faggot', 'fag', 'whore', 'slut', 'retarded', 'dickhead', 'douchebag',
  'wanker', 'twat', 'merde', 'putain', 'pute', 'salope', 'salaud', 'connard', 'connarde', 'connasse', 'encule',
  'enculer', 'enfoire', 'negre', 'couille', 'nique', 'niquer', 'ntm', 'fdp', 'tabarnak', 'tabarnac',
  'calisse', 'caliss', 'osti', 'ostie', 'esti', 'estie', 'ciboire', 'criss',
]);

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

function hasBlockedWord(note) {
  const words = note.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').split(/[^a-z]+/);
  return words.some((word) => NOTE_BLOCKED_WORDS.has(word) || NOTE_BLOCKED_WORDS.has(word.replace(/s$/, '')));
}

// IPv6 addresses are counted by their /64 network, which one home or phone can rotate through.
function networkOf(address) {
  const value = String(address || 'unknown').toLowerCase().split('%')[0];
  const mapped = value.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return mapped[1];
  if (!value.includes(':')) return value;
  const [head, tail] = value.split('::');
  const left = head ? head.split(':') : [];
  const right = tail ? tail.split(':') : [];
  const groups = tail === undefined ? left : left.concat(Array(Math.max(8 - left.length - right.length, 0)).fill('0'), right);
  return groups.slice(0, 4).map((group) => (parseInt(group, 16) || 0).toString(16)).join(':') + '::/64';
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

// Compares two secrets without leaking where they differ.
function sameSecret(given, expected) {
  const left = crypto.createHash('sha256').update(given).digest();
  const right = crypto.createHash('sha256').update(expected).digest();
  return crypto.timingSafeEqual(left, right);
}

// The password of an HTTP Basic header, or '' without one. The user name is not checked.
function basicPassword(req) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Basic ')) return '';
  const pair = Buffer.from(header.slice(6), 'base64').toString('utf8');
  const colon = pair.indexOf(':');
  return colon < 0 ? '' : pair.slice(colon + 1);
}

function createApp(options = {}) {
  const dataDir = options.dataDir || process.env.DATA_DIR || path.join(__dirname, 'data');
  const dataFile = path.join(dataDir, 'germily.json');
  const adminToken = options.adminToken || process.env.ADMIN_TOKEN || '';
  const supportEmail = options.supportEmail || process.env.SUPPORT_EMAIL || '';
  const publisherName = options.publisherName || process.env.PUBLISHER_NAME || '';
  const appStoreURL = options.appStoreURL || process.env.APP_STORE_URL || '';
  const trustedHops = Number(options.trustProxyHops ?? process.env.TRUST_PROXY_HOPS ?? 0) || 0;
  const writeDelay = options.writeDelay ?? WRITE_DELAY;
  const maxSubscriptions = options.maxSubscriptions ?? MAX_SUBSCRIPTIONS;
  const extraBlocked = (options.blockedWords || process.env.BLOCKED_WORDS || '')
    .split(',').map((word) => normalize(word.trim())).filter(Boolean);
  const clock = options.now || (() => Date.now());
  const legal = JSON.parse(fs.readFileSync(path.join(__dirname, 'legal.json'), 'utf8'));
  const illnesses = JSON.parse(fs.readFileSync(path.join(__dirname, 'illnesses.json'), 'utf8'));
  const lessons = loadLessons(options.lessonsFile || path.join(__dirname, 'lessons.json'));
  const pusher = options.pusher || createPusher();
  const mailer = options.mailer || createMailer();
  const inboundToken = options.inboundToken ?? process.env.INBOUND_EMAIL_TOKEN ?? '';
  const inboundDomain = (options.inboundDomain ?? process.env.INBOUND_EMAIL_DOMAIN ?? '').toLowerCase();

  let db = { crews: [], members: [], events: [], reports: [] };
  if (fs.existsSync(dataFile)) {
    db = JSON.parse(fs.readFileSync(dataFile, 'utf8'));
  }
  for (const key of ['daycares', 'subscriptions', 'notices']) {
    if (!Array.isArray(db[key])) db[key] = [];
  }

  const counters = new Map();
  let lastSweep = 0;
  let writeTimer = null;

  function flush() {
    if (writeTimer) clearTimeout(writeTimer);
    writeTimer = null;
    fs.mkdirSync(dataDir, { recursive: true });
    const temp = dataFile + '.tmp';
    fs.writeFileSync(temp, JSON.stringify(db), { mode: 0o600 });
    fs.renameSync(temp, dataFile);
  }

  // Membership changes are written at once; frequent small changes are grouped.
  function save(urgent) {
    if (urgent || writeDelay <= 0) return flush();
    if (!writeTimer) writeTimer = setTimeout(flush, writeDelay);
    return undefined;
  }

  // The address the request really came from. A forwarded header is only read
  // when a known number of proxies stand in front, and then from the trusted end.
  function clientAddress(req) {
    const direct = req.socket.remoteAddress || 'unknown';
    if (trustedHops <= 0) return direct;
    const chain = String(req.headers['x-forwarded-for'] || '').split(',').map((part) => part.trim()).filter(Boolean);
    return chain.length >= trustedHops ? chain[chain.length - trustedHops] : direct;
  }

  // Fixed-window counter per key; expired windows are swept so the map stays bounded.
  function limit(who, bucket) {
    const [max, windowLength] = LIMITS[bucket];
    const now = clock();
    if (now - lastSweep > MINUTE || now < lastSweep) {
      lastSweep = now;
      for (const [key, entry] of counters) {
        if (now >= entry.resetAt || entry.resetAt - now > DAY) counters.delete(key);
      }
    }
    const key = bucket + ':' + who;
    let entry = counters.get(key);
    if (!entry || now >= entry.resetAt) {
      if (counters.size >= MAX_LIMIT_KEYS) throw new ApiError(429, 'rate_limited');
      entry = { count: 0, resetAt: now + windowLength };
      counters.set(key, entry);
    }
    if (entry.count >= max) throw new ApiError(429, 'rate_limited');
    entry.count += 1;
  }

  // The same counter, as a yes or a no.
  function allowed(who, bucket) {
    try {
      limit(who, bucket);
      return true;
    } catch (error) {
      if (error instanceof ApiError) return false;
      throw error;
    }
  }

  function dropMembers(ids) {
    db.members = db.members.filter((member) => !ids.has(member.id));
    db.events = db.events.filter((event) => !ids.has(event.memberID));
    for (const event of db.events) {
      for (const kind of Object.keys(event.reactions)) {
        event.reactions[kind] = event.reactions[kind].filter((id) => !ids.has(id));
      }
    }
    db.reports = db.reports.filter((report) => !ids.has(report.memberID) && !ids.has(report.reporterID));
  }

  // Removes old events and notices, members and daycares nobody opened for a long time, and emptied crews.
  function purge() {
    const now = clock();
    const idle = db.members.filter((member) => now - (member.seenAt || member.joinedAt) > MEMBER_LIFETIME);
    if (idle.length > 0) dropMembers(new Set(idle.map((member) => member.id)));
    db.events = db.events.filter((event) => now - event.at < EVENT_LIFETIME);
    const populated = new Set(db.members.map((member) => member.crewID));
    db.crews = db.crews.filter((crew) => populated.has(crew.id));
    const crewIDs = new Set(db.crews.map((crew) => crew.id));
    db.events = db.events.filter((event) => crewIDs.has(event.crewID));
    db.reports = db.reports.filter((report) => crewIDs.has(report.crewID));
    db.daycares = db.daycares.filter((daycare) => now - (daycare.seenAt || daycare.createdAt) <= MEMBER_LIFETIME);
    const daycareIDs = new Set(db.daycares.map((daycare) => daycare.id));
    db.subscriptions = db.subscriptions.filter((subscription) => daycareIDs.has(subscription.daycareID)
      && now - (subscription.seenAt || subscription.createdAt) <= MEMBER_LIFETIME);
    db.notices = db.notices.filter((notice) => daycareIDs.has(notice.daycareID) && now - notice.at < NOTICE_LIFETIME);
  }

  function newCode() {
    for (;;) {
      let code = '';
      for (const byte of crypto.randomBytes(CREW_CODE_LENGTH)) code += CODE_ALPHABET[byte % CODE_ALPHABET.length];
      if (!db.crews.some((crew) => crew.code === code)) return code;
    }
  }

  function newDaycareCode() {
    for (;;) {
      let code = '';
      for (const byte of crypto.randomBytes(DAYCARE_CODE_LENGTH)) code += CODE_ALPHABET[byte % CODE_ALPHABET.length];
      if (!db.daycares.some((daycare) => daycare.code === code)) return code;
    }
  }

  // The private part of the daycare's email address: its name, then a random suffix.
  function newInbox(name) {
    const slug = flatten(name).replace(/[^a-z0-9]/g, '').slice(0, 14) || 'daycare';
    for (;;) {
      let suffix = '';
      for (const byte of crypto.randomBytes(5)) suffix += CODE_ALPHABET[byte % CODE_ALPHABET.length].toLowerCase();
      const inbox = slug + '-' + suffix;
      if (!db.daycares.some((daycare) => daycare.inbox === inbox)) return inbox;
    }
  }

  function daycareByCode(raw) {
    const code = String(raw || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
    return code.length === DAYCARE_CODE_LENGTH ? db.daycares.find((daycare) => daycare.code === code) : undefined;
  }

  // Up to twelve groups, cleaned and without duplicates; a group keeps its ID when it is renamed.
  function cleanGroups(raw, existing) {
    if (!Array.isArray(raw) || raw.length > MAX_GROUPS) throw new ApiError(400, 'invalid');
    const groups = [];
    const seen = new Set();
    for (const item of raw) {
      const name = cleanName(typeof item === 'string' ? item : item && item.name, 24, extraBlocked);
      if (!name) throw new ApiError(400, 'name_rejected');
      const flat = flatten(name);
      if (seen.has(flat)) continue;
      seen.add(flat);
      const kept = item && typeof item === 'object' && existing.find((group) => group.id === item.id);
      groups.push({ id: kept ? kept.id : crypto.randomUUID(), name });
    }
    return groups;
  }

  function cleanEmail(raw) {
    if (raw === undefined || raw === null || raw === '') return '';
    const email = String(raw).trim().toLowerCase();
    if (email.length > 120 || !EMAIL_PATTERN.test(email)) throw new ApiError(400, 'email_rejected');
    return email;
  }

  function cleanNote(raw) {
    if (raw === undefined || raw === null) return '';
    const note = String(raw).replace(/[\u0000-\u0009\u000b-\u001f\u007f]/g, '').replace(/\n{3,}/g, '\n\n').trim();
    if (note.length > NOTE_LIMIT) throw new ApiError(400, 'note_too_long');
    if (NOTE_LINK_PATTERN.test(note)) throw new ApiError(400, 'note_rejected');
    if (hasBlockedWord(note)) throw new ApiError(400, 'note_rejected');
    return note;
  }

  function cleanMessages(raw) {
    if (raw === undefined || raw === null) return [];
    if (!Array.isArray(raw) || raw.some((id) => !NOTICE_MESSAGES.includes(id))) throw new ApiError(400, 'invalid');
    return NOTICE_MESSAGES.filter((id) => raw.includes(id));
  }

  function cleanPushToken(raw) {
    const token = typeof raw === 'string' ? raw.toLowerCase() : '';
    return PUSH_TOKEN_PATTERN.test(token) ? token : null;
  }

  function cleanLanguage(raw) {
    return raw === 'fr' ? 'fr' : 'en';
  }

  function groupIDsFor(raw, daycare) {
    if (!Array.isArray(raw)) return [];
    const known = new Set(daycare.groups.map((group) => group.id));
    return [...new Set(raw.filter((id) => known.has(id)))];
  }

  function bearer(req) {
    const header = req.headers.authorization || '';
    return header.startsWith('Bearer ') ? header.slice(7) : '';
  }

  // The director's daycare or the parent's subscription the bearer token belongs to.
  function holderOf(list, req) {
    const token = bearer(req);
    const holder = token ? list.find((candidate) => candidate.tokenHash === hashToken(token)) : undefined;
    if (!holder) throw new ApiError(401, 'unauthorized');
    const now = clock();
    if (now - (holder.seenAt || 0) > DAY) {
      holder.seenAt = now;
      save();
    }
    return holder;
  }

  function reaches(subscription, notice) {
    return notice.groupID === null || subscription.groupIDs.includes(notice.groupID);
  }

  function noticeView(notice) {
    return {
      id: notice.id, groupID: notice.groupID, germID: notice.germID, status: notice.status || null,
      messages: notice.messages || [], note: notice.note, at: notice.at, source: notice.source,
    };
  }

  function publicDaycare(daycare) {
    const families = db.subscriptions.filter((subscription) => subscription.daycareID === daycare.id).length;
    return { id: daycare.id, name: daycare.name, groups: daycare.groups, families };
  }

  function parentState(subscription) {
    const now = clock();
    const daycare = db.daycares.find((candidate) => candidate.id === subscription.daycareID);
    const notices = db.notices
      .filter((notice) => notice.daycareID === daycare.id && now - notice.at <= NOTICE_WINDOW
        && reaches(subscription, notice) && !notice.reports.includes(subscription.id))
      .sort((a, b) => b.at - a.at)
      .slice(0, 30)
      .map(noticeView);
    return { daycare: publicDaycare(daycare), groupIDs: subscription.groupIDs, notices };
  }

  function directorState(daycare) {
    const subscriptions = db.subscriptions.filter((subscription) => subscription.daycareID === daycare.id);
    const notices = db.notices
      .filter((notice) => notice.daycareID === daycare.id)
      .sort((a, b) => b.at - a.at)
      .slice(0, 50)
      .map((notice) => ({ ...noticeView(notice), recipients: notice.recipients, reports: notice.reports.length }));
    return {
      daycare: {
        id: daycare.id, name: daycare.name, code: daycare.code, email: daycare.email || null,
        inbox: inboundDomain ? daycare.inbox + '@' + inboundDomain : null,
        families: subscriptions.length,
        groups: daycare.groups.map((group) => ({
          id: group.id, name: group.name,
          families: subscriptions.filter((subscription) => subscription.groupIDs.includes(group.id)).length,
        })),
      },
      notices,
    };
  }

  function alertFor(daycare, notice, lang) {
    const illness = illnesses[notice.germID] ? illnesses[notice.germID][lang] : notice.germID;
    const group = notice.groupID && daycare.groups.find((candidate) => candidate.id === notice.groupID);
    const words = TEXT.notice;
    const where = group ? fill(words.inGroup[lang], { illness, group: group.name }) : fill(words.atDaycare[lang], { illness });
    const body = notice.status ? fill(words.withStatus[lang], { where, status: words[notice.status][lang] }) : where;
    return { title: daycare.name, body };
  }

  // Stores a notice, then alerts every family it reaches; tokens Apple refuses are forgotten.
  // The alert carries the illness, the group and the status, never the note.
  async function publish(daycare, { germID, groupID, status, messages, note }, source) {
    limit(daycare.id, 'noticesPerDay');
    purge();
    const recipients = db.subscriptions.filter((subscription) => subscription.daycareID === daycare.id
      && (groupID === null || subscription.groupIDs.includes(groupID)));
    const notice = {
      id: crypto.randomUUID(), daycareID: daycare.id, groupID, germID, status, messages, note, at: clock(), source,
      recipients: recipients.length, reports: [],
    };
    db.notices.push(notice);
    save(true);
    const alerts = recipients.filter((subscription) => subscription.pushToken).map((subscription) => ({
      token: subscription.pushToken,
      alert: alertFor(daycare, notice, subscription.language),
      thread: daycare.id,
      data: { noticeID: notice.id, daycareID: daycare.id },
    }));
    let result = { sent: 0, gone: [] };
    try {
      result = await pusher.send(alerts);
    } catch (error) {
      console.error('[push]', error.message);
    }
    if (result.gone.length > 0) {
      const gone = new Set(result.gone);
      for (const subscription of db.subscriptions) {
        if (gone.has(subscription.pushToken)) subscription.pushToken = null;
      }
      save();
    }
    return notice;
  }

  function removeDaycare(daycareID) {
    db.daycares = db.daycares.filter((daycare) => daycare.id !== daycareID);
    purge();
  }

  function emailAddress(raw) {
    const match = String(raw || '').match(/[^\s<>"]+@[^\s<>"]+/);
    return match ? match[0].toLowerCase() : '';
  }

  // A notice by email: the private address picks the daycare, only its director's address may send,
  // and the subject gives the illness and the group, without a status. The text of the message is never read or kept.
  async function receiveEmail(body) {
    const recipients = [body.OriginalRecipient, body.To, ...(Array.isArray(body.ToFull) ? body.ToFull.map((to) => to.Email) : [])]
      .flatMap((value) => String(value || '').split(','))
      .map(emailAddress)
      .filter((address) => inboundDomain && address.endsWith('@' + inboundDomain));
    const inboxes = new Set(recipients.map((address) => address.split('@')[0]));
    const daycare = db.daycares.find((candidate) => inboxes.has(candidate.inbox));
    const from = emailAddress(body.FromFull && body.FromFull.Email ? body.FromFull.Email : body.From);
    if (!daycare || !daycare.email || from !== daycare.email) return { status: 'ignored' };
    const lang = daycare.language || 'en';
    const parsed = parseSubject(body.Subject, daycare.groups, illnesses);
    let answer;
    if (parsed.error === 'illness') {
      answer = reply('illness', lang);
    } else if (parsed.error === 'group') {
      answer = reply('group', lang, { names: daycare.groups.map((group) => group.name).join(', ') });
    } else {
      try {
        const notice = await publish(daycare, { germID: parsed.germID, groupID: parsed.groupID, status: null, messages: [], note: '' }, 'email');
        const illness = illnesses[notice.germID][lang];
        const group = notice.groupID && daycare.groups.find((candidate) => candidate.id === notice.groupID);
        answer = reply('sent', lang, { count: notice.recipients, what: group ? `${illness} · ${group.name}` : illness });
      } catch (error) {
        if (!(error instanceof ApiError) || error.code !== 'rate_limited') throw error;
        answer = reply('limit', lang);
      }
    }
    // Replies are capped per daycare, so a forged sender cannot use the server to flood an address.
    if (allowed(daycare.id, 'repliesPerDay')) await mailer.send(daycare.email, answer.subject, answer.body);
    return { status: parsed.error ? 'unclear' : 'sent' };
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
    const now = clock();
    if (now - (member.seenAt || 0) > DAY) {
      member.seenAt = now;
      save();
    }
    return member;
  }

  // Events stored before wins existed have no kind: they are germs caught.
  function kindOf(event) {
    return event.kind || 'caught';
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
    const caught = events.filter((event) => kindOf(event) === 'caught');
    const shown = (member) => ({
      id: member.id,
      name: isMasked(member.id) ? MASKED_NAME : member.name,
      germs: caught.filter((event) => event.memberID === member.id && event.named && event.at >= since).length,
      colorIndex: member.colorIndex,
    });

    const families = new Map();
    for (const event of caught) {
      if (now - event.at > RADAR_WINDOW) continue;
      if (!families.has(event.germID)) families.set(event.germID, new Set());
      families.get(event.germID).add(event.memberID);
    }
    const radar = [...families.entries()]
      .filter(([, who]) => who.size >= RADAR_MIN_FAMILIES)
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
          germID: event.germID, kind: kindOf(event), at: event.at, reactions, mine,
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
    dropMembers(new Set([memberID]));
    purge();
  }

  // A member removed by the moderator must not walk back in: the crew gets a new invite code.
  function expelMember(memberID) {
    const member = db.members.find((candidate) => candidate.id === memberID);
    removeMember(memberID);
    const crew = member && db.crews.find((candidate) => candidate.id === member.crewID);
    if (crew) crew.code = newCode();
  }

  function legalPage(kind, lang) {
    const web = legal.web;
    const title = { privacy: web.privacyTitle, terms: web.termsTitle, health: web.healthTitle }[kind][lang];
    const sections = legal[kind]
      .map((section) => `<h2>${escapeHtml(section.title[lang])}</h2><p>${escapeHtml(section.body[lang])}</p>`)
      .join('');
    const updated = `${escapeHtml(web.updatedLabel[lang])} ${escapeHtml(legal.updated)}`;
    const publisher = publisherName
      ? `<p>${escapeHtml(web.publisherLabel[lang])} ${escapeHtml(publisherName)}.</p>`
      : '';
    const eula = kind === 'terms'
      ? `<p><a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">${escapeHtml(web.eulaLabel[lang])}</a></p>`
      : '';
    const body = `<h1>${escapeHtml(title)}</h1><p class="meta">${updated}</p>${publisher}${sections}${eula}${contactBlock(lang)}`;
    return page(`Germily · ${title}`, lang, body);
  }

  function contactBlock(lang) {
    if (!supportEmail) return '';
    const address = escapeHtml(supportEmail);
    return `<p>${escapeHtml(legal.web.contactLabel[lang])} <a href="mailto:${address}">${address}</a></p>`;
  }

  function supportPage(lang) {
    const web = legal.web;
    const suffix = lang === 'fr' ? '?lang=fr' : '';
    const body = `<h1>${escapeHtml(web.supportTitle[lang])}</h1><p>${escapeHtml(web.supportIntro[lang])}</p>`
      + `<p>${escapeHtml(web.supportDelete[lang])}</p>`;
    const links = `<p><a href="/privacy${suffix}">${escapeHtml(web.privacyTitle[lang])}</a> · `
      + `<a href="/terms${suffix}">${escapeHtml(web.termsTitle[lang])}</a> · `
      + `<a href="/health-data${suffix}">${escapeHtml(web.healthTitle[lang])}</a></p>`;
    return page(`Germily · ${web.supportTitle[lang]}`, lang, body + contactBlock(lang) + links);
  }

  // The page a share card's QR code opens.
  function landingPage(lang) {
    const web = legal.web;
    const points = web.landingPoints.map((point) => `<li>${escapeHtml(point[lang])}</li>`).join('');
    const store = /^https:\/\/apps\.apple\.com\//.test(appStoreURL)
      ? `<a class="store" href="${escapeHtml(appStoreURL)}">${escapeHtml(web.landingStore[lang])}</a>`
      : `<p class="soon">${escapeHtml(web.landingSoon[lang])}</p>`;
    const suffix = lang === 'fr' ? '?lang=fr' : '';
    const body = '<p class="mark">germily</p>'
      + `<h1>${escapeHtml(web.landingTagline[lang])}</h1><p class="lede">${escapeHtml(web.landingIntro[lang])}</p>`
      + `<ul>${points}</ul>${store}`
      + `<p class="links"><a href="/support${suffix}">${escapeHtml(web.supportTitle[lang])}</a> · `
      + `<a href="/privacy${suffix}">${escapeHtml(web.privacyTitle[lang])}</a> · `
      + `<a href="/health-data${suffix}">${escapeHtml(web.healthTitle[lang])}</a></p>`;
    const style = '.mark{font-size:44px;font-weight:900;letter-spacing:-2px;margin:8px 0 18px}'
      + '.lede{font-size:19px}ul{padding:0;list-style:none}li{background:#fff;border-radius:16px;padding:14px 16px;margin:8px 0}'
      + '.store{display:inline-block;margin:18px 0;padding:14px 22px;border-radius:99px;background:#1E1A26;color:#F6F1E7;'
      + 'text-decoration:none;font-weight:700}.soon{margin:18px 0;font-weight:700}.links{color:#6b6675;font-size:15px}';
    return page('Germily', lang, body, style);
  }

  // Where a daycare's QR code leads: its name, its code, and how to join from the app.
  function daycarePage(daycare, lang) {
    const web = legal.web;
    const code = daycare.code.slice(0, 4) + '-' + daycare.code.slice(4);
    const store = /^https:\/\/apps\.apple\.com\//.test(appStoreURL)
      ? `<a class="store" href="${escapeHtml(appStoreURL)}">${escapeHtml(web.landingStore[lang])}</a>`
      : `<p class="soon">${escapeHtml(web.landingSoon[lang])}</p>`;
    const body = '<p class="mark">germily</p>'
      + `<h1>${escapeHtml(web.daycareHeading[lang].replace('{name}', daycare.name))}</h1>`
      + `<p class="lede">${escapeHtml(web.daycareSteps[lang])}</p><p class="code">${code}</p>${store}`;
    const style = '.mark{font-size:44px;font-weight:900;letter-spacing:-2px;margin:8px 0 18px}.lede{font-size:19px}'
      + '.code{font:800 34px/1.2 ui-monospace,Menlo,monospace;letter-spacing:4px;background:#fff;border-radius:18px;'
      + 'padding:18px;text-align:center}.store{display:inline-block;margin:18px 0;padding:14px 22px;border-radius:99px;'
      + 'background:#1E1A26;color:#F6F1E7;text-decoration:none;font-weight:700}.soon{margin:18px 0;font-weight:700}';
    return page(daycare.name, lang, body, style);
  }

  // The moderation page. It holds no data: the reports load after the token is typed.
  function adminPage(nonce) {
    const script = `
const state = { token: '' };
const list = document.getElementById('list');
const status = document.getElementById('status');
function node(tag, text) { const el = document.createElement(tag); if (text) el.textContent = text; return el; }
async function api(method, path) {
  const response = await fetch(path, { method, headers: { Authorization: 'Bearer ' + state.token } });
  if (!response.ok) throw new Error(response.status === 401 ? 'Wrong token.' : 'Request failed (' + response.status + ').');
  return response.json();
}
async function act(path, label) {
  if (!confirm(label + '?')) return;
  try { await api('POST', path); await load(); } catch (error) { status.textContent = error.message; }
}
function button(label, path, question) {
  const el = node('button', label);
  el.addEventListener('click', () => act(path, question));
  return el;
}
async function load() {
  status.textContent = 'Loading...';
  list.replaceChildren();
  try {
    const data = await api('GET', '/admin/reports');
    const count = data.reports.length + data.notices.length;
    status.textContent = count ? count + ' open report(s).' : 'No open reports.';
    const check = node('section');
    check.append(node('h2', 'Connection seen by the server'));
    const seen = data.connection;
    for (const [label, value] of [['Socket', seen.socket], ['X-Forwarded-For', seen.forwardedFor], ['X-Real-IP', seen.realIP],
      ['Forwarded', seen.forwarded], ['X-Envoy-External-Address', seen.envoy], ['TRUST_PROXY_HOPS', String(seen.hops)],
      ['Address kept for limits', seen.kept], ['Network counted', seen.network]]) {
      check.append(node('p', label + ': ' + (value === null ? '(none)' : value)));
    }
    list.append(check);
    for (const report of data.reports) {
      const card = node('section');
      card.append(node('h2', (report.memberName || 'Removed member') + ' · ' + (report.crewName || 'Removed crew')));
      card.append(node('p', 'Reason: ' + report.reason + ' · ' + new Date(report.at).toLocaleString()));
      card.append(button('Remove member', '/admin/members/' + report.memberID + '/remove', 'Remove this member and everything they shared'),
        button('Dismiss reports', '/admin/members/' + report.memberID + '/clear', 'Dismiss every report about this member'));
      list.append(card);
    }
    for (const notice of data.notices) {
      const card = node('section');
      card.append(node('h2', notice.daycareName + ' · ' + notice.illness));
      card.append(node('p', (notice.note || 'No note') + ' · ' + notice.reports + ' report(s) · ' + new Date(notice.at).toLocaleString()));
      card.append(button('Remove notice', '/admin/notices/' + notice.id + '/remove', 'Remove this notice'),
        button('Remove daycare', '/admin/daycares/' + notice.daycareID + '/remove', 'Remove this daycare, its notices and its families'),
        button('Dismiss reports', '/admin/notices/' + notice.id + '/clear', 'Dismiss the reports about this notice'));
      list.append(card);
    }
  } catch (error) { status.textContent = error.message; }
}
document.getElementById('form').addEventListener('submit', (event) => {
  event.preventDefault();
  state.token = document.getElementById('token').value;
  load();
});`;
    return '<!doctype html><html lang="en"><head><meta charset="utf-8">'
      + '<meta name="viewport" content="width=device-width, initial-scale=1"><title>Germily · Moderation</title>'
      + '<style>body{font:17px/1.5 -apple-system,system-ui,sans-serif;color:#1E1A26;background:#F6F1E7;margin:0}'
      + 'main{max-width:680px;margin:0 auto;padding:32px 22px 64px}h1{font-size:30px;margin:0 0 12px}'
      + 'h2{font-size:18px;margin:0 0 4px}section{background:#fff;border-radius:18px;padding:16px;margin:12px 0}'
      + 'input,button{font:inherit;padding:10px 14px;border-radius:12px;border:1px solid #c9c2b4;margin:4px 6px 4px 0}'
      + 'button{background:#1E1A26;color:#F6F1E7;border:0}p{margin:4px 0 10px}</style></head><body><main>'
      + '<h1>Moderation</h1><form id="form"><input id="token" type="password" placeholder="Admin token" '
      + 'autocomplete="off" required><button type="submit">Load reports</button></form>'
      + `<p id="status"></p><div id="list"></div></main><script nonce="${nonce}">${script}</script></body></html>`;
  }

  function page(title, lang, body, extraStyle = '') {
    return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8">`
      + '<meta name="viewport" content="width=device-width, initial-scale=1">'
      + `<title>${escapeHtml(title)}</title>`
      + '<style>body{font:17px/1.55 -apple-system,system-ui,sans-serif;color:#1E1A26;background:#F6F1E7;margin:0}'
      + 'main{max-width:680px;margin:0 auto;padding:32px 22px 64px}h1{font-size:32px;margin:0 0 4px}'
      + `h2{font-size:19px;margin:28px 0 6px}.meta{color:#6b6675}a{color:#3D7BFA}${extraStyle}</style></head>`
      + `<body><main>${body}</main></body></html>`;
  }

  function language(req, url) {
    const asked = url.searchParams.get('lang');
    if (asked === 'fr' || asked === 'en') return asked;
    return /^fr\b/i.test(req.headers['accept-language'] || '') ? 'fr' : 'en';
  }

  async function readBody(req, maxBytes = MAX_BODY_BYTES) {
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > maxBytes) throw new ApiError(413, 'too_large');
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
    const ip = networkOf(clientAddress(req));

    if (key === 'GET /health') return json(res, 200, { ok: true });
    // The public pages have their own counter, so page loads cannot use up the app's.
    if (PUBLIC_PAGES.has(key)) limit(ip, 'pages');
    if (key === 'GET /privacy') return html(res, legalPage('privacy', language(req, url)));
    if (key === 'GET /terms') return html(res, legalPage('terms', language(req, url)));
    if (key === 'GET /health-data') return html(res, legalPage('health', language(req, url)));
    if (key === 'GET /support') return html(res, supportPage(language(req, url)));
    if (key === 'GET /lessons.json') return lessonFile(req, res);
    if (key === 'GET /' || key === 'GET /get') return html(res, landingPage(language(req, url)));
    if (req.method === 'GET' && url.pathname.startsWith('/d/')) {
      limit(ip, 'join');
      const daycare = daycareByCode(url.pathname.slice(3));
      const lang = language(req, url);
      return html(res, daycare ? daycarePage(daycare, lang) : landingPage(lang));
    }

    limit(ip, 'all');

    if (key === 'GET /admin') {
      limit(ip, 'admin');
      const nonce = crypto.randomBytes(16).toString('base64');
      return html(res, adminPage(nonce), nonce);
    }

    if (url.pathname.startsWith('/admin/')) {
      limit(ip, 'admin');
      const header = req.headers.authorization || '';
      const given = header.startsWith('Bearer ') ? header.slice(7) : '';
      if (!adminToken || !sameSecret(given, adminToken)) throw new ApiError(401, 'unauthorized');
      if (key === 'GET /admin/reports') {
        const open = db.reports.filter((report) => !report.resolved).map((report) => {
          const member = db.members.find((candidate) => candidate.id === report.memberID);
          const crew = db.crews.find((candidate) => candidate.id === report.crewID);
          return {
            memberID: report.memberID, reason: report.reason, at: report.at,
            memberName: member ? member.name : null, crewName: crew ? crew.name : null,
          };
        });
        const notices = db.notices.filter((notice) => notice.reports.length > 0 && !notice.reviewed).map((notice) => {
          const daycare = db.daycares.find((candidate) => candidate.id === notice.daycareID);
          return {
            id: notice.id, daycareID: notice.daycareID, daycareName: daycare.name, note: notice.note, at: notice.at,
            illness: illnesses[notice.germID].en, reports: notice.reports.length,
          };
        });
        const header = (name) => (req.headers[name] === undefined ? null : String(req.headers[name]));
        const connection = {
          socket: req.socket.remoteAddress || null, forwardedFor: header('x-forwarded-for'), realIP: header('x-real-ip'),
          forwarded: header('forwarded'), envoy: header('x-envoy-external-address'), hops: trustedHops,
          kept: clientAddress(req), network: ip,
        };
        return json(res, 200, { reports: open, notices, connection });
      }
      const notice = url.pathname.match(/^\/admin\/notices\/([0-9a-f-]{36})\/(remove|clear)$/);
      if (req.method === 'POST' && notice) {
        if (notice[2] === 'remove') {
          db.notices = db.notices.filter((candidate) => candidate.id !== notice[1]);
        } else {
          const found = db.notices.find((candidate) => candidate.id === notice[1]);
          if (found) found.reviewed = true;
        }
        save(true);
        return json(res, 200, { ok: true });
      }
      const daycare = url.pathname.match(/^\/admin\/daycares\/([0-9a-f-]{36})\/remove$/);
      if (req.method === 'POST' && daycare) {
        removeDaycare(daycare[1]);
        save(true);
        return json(res, 200, { ok: true });
      }
      const match = url.pathname.match(/^\/admin\/members\/([0-9a-f-]{36})\/(remove|clear)$/);
      if (req.method === 'POST' && match) {
        if (match[2] === 'remove') {
          expelMember(match[1]);
        } else {
          for (const report of db.reports) {
            if (report.memberID === match[1]) report.resolved = true;
          }
        }
        save(true);
        return json(res, 200, { ok: true });
      }
      throw new ApiError(404, 'not_found');
    }

    if (key === 'POST /v1/crews') {
      limit(ip, 'join');
      limit(ip, 'crewsPerDay');
      const body = await readBody(req);
      const name = cleanName(body.name, 24, extraBlocked);
      const displayName = cleanName(body.displayName, 20, extraBlocked);
      if (!name || !displayName) throw new ApiError(400, 'name_rejected');
      const emblem = Number.isInteger(body.emblem) && body.emblem >= 0 && body.emblem < 6 ? body.emblem : 0;
      const crew = { id: crypto.randomUUID(), name, emblem, code: newCode(), createdAt: clock() };
      db.crews.push(crew);
      const { member, token } = addMember(crew, displayName);
      save(true);
      return json(res, 200, { token, state: stateFor(member) });
    }

    if (key === 'POST /v1/crews/join') {
      limit(ip, 'join');
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
      save(true);
      return json(res, 200, { token, state: stateFor(member) });
    }

    if (req.method === 'GET' && url.pathname.startsWith('/v1/daycares/')) {
      limit(ip, 'join');
      const daycare = daycareByCode(url.pathname.slice('/v1/daycares/'.length));
      if (!daycare) throw new ApiError(404, 'invalid_code');
      return json(res, 200, { daycare: publicDaycare(daycare) });
    }

    if (key === 'POST /v1/daycares') {
      limit(ip, 'join');
      limit(ip, 'daycaresPerDay');
      const body = await readBody(req);
      const name = cleanName(body.name, 40, extraBlocked);
      if (!name) throw new ApiError(400, 'name_rejected');
      const token = crypto.randomBytes(32).toString('hex');
      const daycare = {
        id: crypto.randomUUID(), name, code: newDaycareCode(), inbox: newInbox(name), email: cleanEmail(body.email),
        language: cleanLanguage(body.language), groups: cleanGroups(body.groups || [], []),
        tokenHash: hashToken(token), createdAt: clock(), seenAt: clock(),
      };
      db.daycares.push(daycare);
      save(true);
      return json(res, 200, { token, state: directorState(daycare) });
    }

    if (key === 'POST /v1/daycare-subscriptions') {
      limit(ip, 'join');
      const body = await readBody(req);
      const daycare = daycareByCode(body.code);
      if (!daycare) throw new ApiError(404, 'invalid_code');
      if (db.subscriptions.filter((candidate) => candidate.daycareID === daycare.id).length >= maxSubscriptions) {
        throw new ApiError(409, 'daycare_full');
      }
      limit(ip, 'subscriptionsPerDay');
      const token = crypto.randomBytes(32).toString('hex');
      const subscription = {
        id: crypto.randomUUID(), daycareID: daycare.id, groupIDs: groupIDsFor(body.groupIDs, daycare),
        pushToken: cleanPushToken(body.pushToken), language: cleanLanguage(body.language),
        tokenHash: hashToken(token), createdAt: clock(), seenAt: clock(),
      };
      db.subscriptions.push(subscription);
      save(true);
      return json(res, 200, { token, state: parentState(subscription) });
    }

    if (key === 'POST /v1/inbound-email') {
      limit(ip, 'inbound');
      if (!inboundToken || !sameSecret(basicPassword(req), inboundToken)) {
        res.setHeader('WWW-Authenticate', 'Basic realm="Germily"');
        throw new ApiError(401, 'unauthorized');
      }
      return json(res, 200, await receiveEmail(await readBody(req, MAX_EMAIL_BYTES)));
    }

    if (url.pathname === '/v1/daycare' || url.pathname.startsWith('/v1/daycare/')) {
      const daycare = holderOf(db.daycares, req);
      if (key === 'GET /v1/daycare') return json(res, 200, directorState(daycare));
      if (key === 'POST /v1/daycare') {
        limit(daycare.id, 'daycareUpdates');
        const body = await readBody(req);
        if (body.name !== undefined) {
          const name = cleanName(body.name, 40, extraBlocked);
          if (!name) throw new ApiError(400, 'name_rejected');
          daycare.name = name;
        }
        if (body.groups !== undefined) {
          daycare.groups = cleanGroups(body.groups, daycare.groups);
          const kept = new Set(daycare.groups.map((group) => group.id));
          for (const subscription of db.subscriptions) {
            if (subscription.daycareID === daycare.id) subscription.groupIDs = subscription.groupIDs.filter((id) => kept.has(id));
          }
        }
        if (body.email !== undefined) daycare.email = cleanEmail(body.email);
        if (body.language !== undefined) daycare.language = cleanLanguage(body.language);
        save(true);
        return json(res, 200, directorState(daycare));
      }
      if (key === 'POST /v1/daycare/code') {
        limit(daycare.id, 'codeRenewals');
        daycare.code = newDaycareCode();
        save(true);
        return json(res, 200, directorState(daycare));
      }
      if (key === 'POST /v1/daycare/notices') {
        const body = await readBody(req);
        if (!GERM_IDS.has(body.germID) || body.germID === 'mystery') throw new ApiError(400, 'invalid');
        const groupID = body.groupID === null || body.groupID === undefined ? null : String(body.groupID);
        if (groupID !== null && !daycare.groups.some((group) => group.id === groupID)) throw new ApiError(400, 'invalid');
        if (!NOTICE_STATUSES.has(body.status)) throw new ApiError(400, 'invalid');
        await publish(daycare, {
          germID: body.germID, groupID, status: body.status, messages: cleanMessages(body.messages), note: cleanNote(body.note),
        }, 'app');
        return json(res, 200, directorState(daycare));
      }
      if (key === 'DELETE /v1/daycare') {
        removeDaycare(daycare.id);
        save(true);
        res.writeHead(204);
        return res.end();
      }
      throw new ApiError(404, 'not_found');
    }

    if (url.pathname === '/v1/daycare-subscription' || url.pathname.startsWith('/v1/daycare-subscription/')) {
      const subscription = holderOf(db.subscriptions, req);
      const daycare = db.daycares.find((candidate) => candidate.id === subscription.daycareID);
      if (key === 'GET /v1/daycare-subscription') return json(res, 200, parentState(subscription));
      if (key === 'POST /v1/daycare-subscription') {
        limit(subscription.id, 'daycareUpdates');
        const body = await readBody(req);
        if (body.groupIDs !== undefined) subscription.groupIDs = groupIDsFor(body.groupIDs, daycare);
        if (body.pushToken !== undefined) subscription.pushToken = cleanPushToken(body.pushToken);
        if (body.language !== undefined) subscription.language = cleanLanguage(body.language);
        save();
        return json(res, 200, parentState(subscription));
      }
      if (key === 'POST /v1/daycare-subscription/reports') {
        limit(subscription.id, 'reports');
        const body = await readBody(req);
        const notice = db.notices.find((candidate) => candidate.id === body.noticeID && candidate.daycareID === daycare.id);
        if (!notice) throw new ApiError(404, 'not_found');
        if (!notice.reports.includes(subscription.id)) {
          notice.reports.push(subscription.id);
          save();
        }
        return json(res, 200, parentState(subscription));
      }
      if (key === 'DELETE /v1/daycare-subscription') {
        db.subscriptions = db.subscriptions.filter((candidate) => candidate.id !== subscription.id);
        save(true);
        res.writeHead(204);
        return res.end();
      }
      throw new ApiError(404, 'not_found');
    }

    const me = authenticate(req);

    if (key === 'GET /v1/crew') return json(res, 200, stateFor(me));

    if (key === 'POST /v1/crew/events') {
      limit(me.id, 'events');
      const body = await readBody(req);
      if (!GERM_IDS.has(body.germID)) throw new ApiError(400, 'invalid');
      const kind = body.kind === undefined ? 'caught' : body.kind;
      // A win only makes sense in the feed, under the member's name.
      if (!EVENT_KINDS.has(kind) || (kind === 'beat' && body.named !== true)) throw new ApiError(400, 'invalid');
      // A retried share carries the same client ID and is stored once.
      const clientID = typeof body.clientID === 'string' && UUID_PATTERN.test(body.clientID) ? body.clientID : null;
      const repeated = clientID
        && db.events.some((event) => event.memberID === me.id && event.clientID === clientID);
      if (!repeated) {
        limit(me.id, 'eventsPerDay');
        db.events.push({
          id: crypto.randomUUID(), crewID: me.crewID, memberID: me.id, germID: body.germID, kind,
          at: clock(), named: body.named === true, reactions: {}, clientID,
        });
        purge();
        save();
      }
      return json(res, 200, stateFor(me));
    }

    const reaction = url.pathname.match(/^\/v1\/crew\/events\/([0-9a-f-]{36})\/reactions$/);
    if (req.method === 'POST' && reaction) {
      limit(me.id, 'reactions');
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
      limit(me.id, 'rename');
      const body = await readBody(req);
      const displayName = cleanName(body.displayName, 20, extraBlocked);
      if (!displayName) throw new ApiError(400, 'name_rejected');
      me.name = displayName;
      save();
      return json(res, 200, stateFor(me));
    }

    if (key === 'POST /v1/crew/reports') {
      limit(me.id, 'reports');
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
        save();
      }
      return json(res, 200, stateFor(me));
    }

    if (key === 'DELETE /v1/crew/me') {
      removeMember(me.id);
      save(true);
      res.writeHead(204);
      return res.end();
    }

    throw new ApiError(404, 'not_found');
  }

  const baseHeaders = {
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'X-Frame-Options': 'DENY',
    'Strict-Transport-Security': 'max-age=31536000',
  };

  // The online lesson file, read once at start; a changed file arrives with the next deploy.
  function loadLessons(file) {
    try {
      const body = fs.readFileSync(file);
      if (body.length > MAX_LESSONS_BYTES || !Array.isArray(JSON.parse(body.toString('utf8')).lessons)) {
        console.error(`lessons: ${file} is over 1 MB or has no lessons list; not served`);
        return null;
      }
      return { body, etag: '"' + crypto.createHash('sha256').update(body).digest('hex').slice(0, 32) + '"' };
    } catch (error) {
      if (error.code !== 'ENOENT') console.error(`lessons: ${file} does not read; not served`);
      return null;
    }
  }

  function lessonFile(req, res) {
    if (!lessons) throw new ApiError(404, 'not_found');
    const headers = { ...baseHeaders, ETag: lessons.etag, 'Cache-Control': 'no-cache' };
    if (req.headers['if-none-match'] === lessons.etag) {
      res.writeHead(304, headers);
      return res.end();
    }
    res.writeHead(200, { ...headers, 'Content-Type': 'application/json; charset=utf-8' });
    return res.end(lessons.body);
  }

  function json(res, status, body) {
    res.writeHead(status, {
      ...baseHeaders, 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store',
    });
    res.end(JSON.stringify(body));
  }

  // Pages carry inline styles only; the moderation page also runs one script, allowed by its nonce.
  function html(res, body, nonce) {
    const scripts = nonce ? ` script-src 'nonce-${nonce}'; connect-src 'self';` : '';
    res.writeHead(200, {
      ...baseHeaders,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': nonce ? 'no-store' : 'public, max-age=300',
      'Content-Security-Policy':
        `default-src 'none'; style-src 'unsafe-inline';${scripts} base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
    });
    res.end(body);
  }

  const server = http.createServer((req, res) => {
    route(req, res).catch((error) => {
      if (error instanceof ApiError) return json(res, error.status, { error: error.code });
      console.error(error);
      return json(res, 500, { error: 'server_error' });
    });
  });
  // Slow clients are dropped early and connections are capped, so they cannot hold the memory.
  server.headersTimeout = HEADERS_TIMEOUT;
  server.requestTimeout = REQUEST_TIMEOUT;
  server.maxConnections = MAX_CONNECTIONS;
  server.flush = flush;
  // Expired data also leaves while nobody uses the server.
  purge();
  const sweeper = setInterval(() => {
    purge();
    save();
  }, SWEEP_INTERVAL);
  sweeper.unref();
  server.on('close', () => {
    clearInterval(sweeper);
    if (writeTimer) flush();
  });
  return server;
}

module.exports = { createApp, cleanName, hasBlockedWord, networkOf };

if (require.main === module) {
  if (process.env.NODE_ENV === 'production' && !process.env.DATA_DIR) {
    console.error('DATA_DIR must point to a persistent disk in production. The server did not start.');
    process.exit(1);
  }
  if (!process.env.ADMIN_TOKEN) {
    console.warn('ADMIN_TOKEN is not set: the moderation page cannot load reports.');
  }
  const port = Number(process.env.PORT) || 8080;
  const server = createApp();
  server.listen(port, () => {
    console.log(`Germily crew server listening on ${port}`);
  });
  for (const signal of ['SIGTERM', 'SIGINT']) {
    process.on(signal, () => {
      server.flush();
      process.exit(0);
    });
  }
}
