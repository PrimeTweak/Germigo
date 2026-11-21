'use strict';

// Daycare notices sent by email: reading the subject, and the confirmation sent back.

const WHOLE = ['whole daycare', 'all', 'everyone', 'everybody', 'tous', 'toutes', 'tout le monde',
  'toute la garderie', 'la garderie', 'garderie', 'cpe', 'tous les groupes'];

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

const FILLER = ['group', 'groupe', 'groups', 'groupes', 'the', 'le', 'la', 'les', 'in', 'dans', 'au', 'aux', 'a', 'de', 'du', 'des', 'at'];

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

const REPLIES = {
  sent: {
    en: (count, what) => [`Sent: ${what}`, `Your notice reached ${count} ${count === 1 ? 'family' : 'families'} on Germigo.`],
    fr: (count, what) => [`Envoyé : ${what}`, `Votre avis a été transmis à ${count} ${count === 1 ? 'famille' : 'familles'} sur Germigo.`],
  },
  illness: {
    en: () => ['Not sent: which illness?', 'Germigo could not find the illness in the subject. Write it first, then the group, for example "Stomach bug - Toddlers". Nothing was sent.'],
    fr: () => ['Non envoyé : quelle maladie?', 'Germigo n\'a pas trouvé la maladie dans l\'objet. Écrivez-la d\'abord, puis le groupe, par exemple « Gastro - Trottineurs ». Rien n\'a été envoyé.'],
  },
  group: {
    en: (names) => ['Not sent: which group?', `Germigo could not match the group. Use one of these names, or leave it out to reach the whole daycare: ${names}. Nothing was sent.`],
    fr: (names) => ['Non envoyé : quel groupe?', `Germigo n'a pas reconnu le groupe. Utilisez un de ces noms, ou ne mettez rien pour toute la garderie : ${names}. Rien n'a été envoyé.`],
  },
  limit: {
    en: () => ['Not sent: daily limit reached', 'This daycare has sent the most notices allowed today. Try again tomorrow.'],
    fr: () => ['Non envoyé : limite du jour atteinte', 'Cette garderie a envoyé le nombre maximal d\'avis aujourd\'hui. Réessayez demain.'],
  },
};

function reply(kind, language, ...values) {
  const set = REPLIES[kind];
  const [subject, body] = (set[language] || set.en)(...values);
  return { subject, body };
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

module.exports = { parseSubject, reply, createMailer, flatten };
