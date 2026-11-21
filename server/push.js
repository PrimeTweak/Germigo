'use strict';

// Alerts through the Apple Push Notification service, signed with a token-based (.p8) key.

const http2 = require('node:http2');
const crypto = require('node:crypto');

const TOKEN_LIFETIME = 50 * 60;
const PARALLEL = 20;
const TIMEOUT = 10000;
const GONE_REASONS = new Set(['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic']);

function base64url(input) {
  return Buffer.from(input).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function createPusher(options = {}) {
  const key = (options.key ?? process.env.APNS_KEY ?? '').replace(/\\n/g, '\n');
  const keyID = options.keyID ?? process.env.APNS_KEY_ID ?? '';
  const teamID = options.teamID ?? process.env.APNS_TEAM_ID ?? '';
  const topic = options.topic ?? process.env.APNS_TOPIC ?? 'ca.germigo.app';
  const sandbox = options.sandbox ?? process.env.APNS_ENV === 'sandbox';
  const host = sandbox ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
  const enabled = Boolean(key && keyID && teamID);
  let signed = null;

  function bearer() {
    const now = Math.floor(Date.now() / 1000);
    if (signed && now - signed.at < TOKEN_LIFETIME) return signed.value;
    const head = base64url(JSON.stringify({ alg: 'ES256', kid: keyID }));
    const claims = base64url(JSON.stringify({ iss: teamID, iat: now }));
    const signature = crypto.sign('sha256', Buffer.from(head + '.' + claims), { key, dsaEncoding: 'ieee-p1363' });
    signed = { value: `${head}.${claims}.${base64url(signature)}`, at: now };
    return signed.value;
  }

  function deliver(session, authorization, message) {
    return new Promise((resolve) => {
      const payload = JSON.stringify({
        aps: { alert: message.alert, sound: 'default', 'thread-id': message.thread },
        ...message.data,
      });
      const request = session.request({
        ':method': 'POST',
        ':path': '/3/device/' + message.token,
        authorization,
        'apns-topic': topic,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'content-type': 'application/json',
      });
      let status = 0;
      let body = '';
      request.setEncoding('utf8');
      request.on('response', (headers) => {
        status = headers[':status'];
      });
      request.on('data', (chunk) => {
        body += chunk;
      });
      request.setTimeout(TIMEOUT, () => request.close(http2.constants.NGHTTP2_CANCEL));
      request.on('error', () => {});
      request.on('close', () => {
        let reason = '';
        try {
          reason = body ? JSON.parse(body).reason : '';
        } catch {
          reason = '';
        }
        resolve({ token: message.token, ok: status === 200, gone: status === 410 || GONE_REASONS.has(reason) });
      });
      request.end(payload);
    });
  }

  // Sends each message once; resolves with the count sent and the tokens Apple no longer accepts.
  async function send(messages) {
    if (!enabled || messages.length === 0) return { sent: 0, gone: [] };
    const authorization = 'bearer ' + bearer();
    const session = http2.connect(host);
    session.on('error', () => {});
    const results = [];
    try {
      for (let start = 0; start < messages.length; start += PARALLEL) {
        const batch = messages.slice(start, start + PARALLEL);
        results.push(...(await Promise.all(batch.map((message) => deliver(session, authorization, message)))));
      }
    } finally {
      session.close();
    }
    return {
      sent: results.filter((result) => result.ok).length,
      gone: results.filter((result) => result.gone).map((result) => result.token),
    };
  }

  return { enabled, send };
}

module.exports = { createPusher };
