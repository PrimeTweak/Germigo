'use strict';

// Daycare notices sent by email: reading the subject, and the reply sent back.
// The words read in subjects and the replies, in English and French, live in text.json.

const TEXT = require('./text.json');
const WHOLE = TEXT.subjectWords.whole;
const FILLER = TEXT.subjectWords.filler;

function flatten(text) {
  return String(text || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

// Finds a phrase as whole words; returns the text with it removed, or null.
function take(text, phrase) {
  const target = flatten(phrase);
  if (!target) return null;
  const padded = ` ${text} `;
  const index = padded.indexOf(` ${target} `);
  if (index < 0) return null;
  return (padded.slice(0, index) + ' ' + padded.slice(index + target.length + 2)).replace(/\s+/g, ' ').trim();
}

function withoutFiller(text) {
  return text.split(' ').filter((word) => word && !FILLER.includes(word)).join(' ');
}

function strip(subject) {
  return String(subject || '').replace(/^\s*((re|fwd?|tr)\s*:\s*)+/i, '');
}

// Reads "Illness - Group" from a subject. The group may be left out, or named "all", for the whole daycare.
function parseSubject(subject, groups, illnesses) {
  let text = flatten(strip(subject));
  let germID = null;
  const names = [];
  for (const [id, illness] of Object.entries(illnesses)) {
    for (const name of [illness.en, illness.fr, ...illness.aliases]) names.push({ id, name: flatten(name) });
  }
  names.sort((a, b) => b.name.length - a.name.length);
  for (const candidate of names) {
    const rest = take(text, candidate.name);
    if (rest !== null) {
      germID = candidate.id;
      text = rest;
      break;
    }
  }
  if (!germID) return { error: 'illness' };
  const spellings = groups.flatMap((group) => [flatten(group.name), withoutFiller(flatten(group.name))]
    .filter(Boolean).map((name) => ({ id: group.id, name })));
  spellings.sort((a, b) => b.name.length - a.name.length);
  for (const spelling of spellings) {
    const rest = take(text, spelling.name);
    if (rest !== null) return withoutFiller(rest) === '' ? { germID, groupID: spelling.id } : { error: 'group' };
  }
  const core = withoutFiller(text);
  if (core === '' || WHOLE.some((phrase) => withoutFiller(flatten(phrase)) === core)) return { germID, groupID: null };
  return { error: 'group' };
}

// Puts values into a text's {placeholders}.
function fill(template, values = {}) {
  return template.replace(/\{(\w+)\}/g, (match, key) => (key in values ? String(values[key]) : match));
}

// The reply for one outcome, in the daycare's language: sent, illness, group or limit.
function reply(kind, language, values = {}) {
  const set = TEXT.replies[kind];
  const words = set[language] || set.en;
  const body = values.count === 1 && words.bodyOne ? words.bodyOne : words.body;
  return { subject: fill(words.subject, values), body: fill(body, values) };
}

// Sends one plain-text email through Postmark; without a token, nothing is sent.
function createMailer(options = {}) {
  const token = options.token ?? process.env.POSTMARK_TOKEN ?? '';
  const from = options.from ?? process.env.MAIL_FROM ?? '';
  const enabled = Boolean(token && from);
  async function send(to, subject, body) {
    if (!enabled) return false;
    try {
      const response = await fetch('https://api.postmarkapp.com/email', {
        method: 'POST',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json', 'X-Postmark-Server-Token': token },
        body: JSON.stringify({ From: from, To: to, Subject: subject, TextBody: body, MessageStream: 'outbound' }),
      });
      return response.ok;
    } catch {
      return false;
    }
  }
  return { enabled, send };
}

module.exports = { parseSubject, reply, createMailer, flatten, fill };
