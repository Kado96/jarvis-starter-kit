// Deploy + activate Jarvis Evolution workflows on n8n
const fs = require('fs');
const path = require('path');

const BASE = process.env.N8N_URL || 'https://n8n-ajs5.onrender.com';
const KEY = process.env.N8N_API_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0YzE4MzIzNS01ZDQxLTRjNWEtOGYzOS1lOTc4MDI0NGY4OWUiLCJpc3MiOiJuOG4iLCJqdGkiOiJlMTIzZmM3Ni1kOTBlLTQ1MTAtYmQyYi00OTgzMzgyM2VjZDciLCJpYXQiOjE3OTM0MzgxMzQsImF1ZCI6InB1YmxpYy1hcGkifQ._O6rHVG7t6KQVpxNXrEpfa8Xx6wx2jsdPynl2NsjaBs';

const ROOT = path.join(__dirname, '..');
const WORKFLOWS = [
  path.join(ROOT, 'n8n-workflow-jarvis-wa-evolution.json'),
  path.join(ROOT, 'n8n-workflow-keepalive.json'),
];

const READONLY = [
  'active', 'tags', 'pinData', 'staticData', 'versionId', 'shared',
  'createdAt', 'updatedAt', 'id', 'meta', 'triggerCount',
];

async function fetchWithRetry(url, options, maxRetries = 4) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const res = await fetch(url, { ...options, signal: AbortSignal.timeout(60000) });
      return res;
    } catch (err) {
      console.log(`[retry ${attempt}/${maxRetries}] ${err.message}`);
      if (attempt === maxRetries) throw err;
      await new Promise((r) => setTimeout(r, 5000 * attempt));
    }
  }
}

async function activate(id) {
  // n8n public API variants
  const attempts = [
    { method: 'POST', url: `${BASE}/api/v1/workflows/${id}/activate` },
    { method: 'PATCH', url: `${BASE}/api/v1/workflows/${id}`, body: { active: true } },
  ];
  for (const a of attempts) {
    const res = await fetchWithRetry(a.url, {
      method: a.method,
      headers: { 'X-N8N-API-KEY': KEY, 'Content-Type': 'application/json' },
      body: a.body ? JSON.stringify(a.body) : undefined,
    });
    const data = await res.json().catch(() => ({}));
    if (res.ok) {
      console.log(`  Activated via ${a.method} ${a.url.split('/api/v1')[1]}`);
      return true;
    }
    console.log(`  Activate attempt failed ${res.status}: ${JSON.stringify(data).slice(0, 200)}`);
  }
  return false;
}

async function main() {
  console.log(`n8n: ${BASE}`);
  const listRes = await fetchWithRetry(`${BASE}/api/v1/workflows`, {
    headers: { 'X-N8N-API-KEY': KEY },
  });
  if (!listRes.ok) {
    console.error('List workflows failed:', listRes.status, await listRes.text());
    process.exit(1);
  }
  const listData = await listRes.json();
  const existing = listData.data || listData || [];
  console.log(`Existing workflows: ${Array.isArray(existing) ? existing.length : '?'}`);

  for (const file of WORKFLOWS) {
    console.log(`\n=== ${path.basename(file)} ===`);
    if (!fs.existsSync(file)) {
      console.log('File missing, skip');
      continue;
    }
    const payload = JSON.parse(fs.readFileSync(file, 'utf8'));
    const name = payload.name;
    READONLY.forEach((k) => delete payload[k]);

    const found = (Array.isArray(existing) ? existing : []).find((w) => w.name === name);
    let id = found?.id || null;

    if (id) {
      console.log(`Update existing id=${id}`);
      const res = await fetchWithRetry(`${BASE}/api/v1/workflows/${id}`, {
        method: 'PUT',
        headers: { 'X-N8N-API-KEY': KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) {
        console.error('Update failed:', res.status, JSON.stringify(data).slice(0, 400));
        continue;
      }
      id = data.id || id;
      console.log('Update OK');
    } else {
      console.log('Create new');
      const res = await fetchWithRetry(`${BASE}/api/v1/workflows`, {
        method: 'POST',
        headers: { 'X-N8N-API-KEY': KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!data.id) {
        console.error('Create failed:', res.status, JSON.stringify(data).slice(0, 400));
        continue;
      }
      id = data.id;
      console.log(`Create OK id=${id}`);
    }

    const ok = await activate(id);
    if (!ok) console.log('WARNING: could not activate — do it manually in n8n UI');
  }

  // Webhook probe
  console.log('\n=== Webhook probe ===');
  const webhook = `${BASE}/webhook/jarvis-wa-evolution`;
  const body = {
    event: 'messages.upsert',
    instance: 'jarvis-principal',
    data: {
      key: { remoteJid: '25779928864@s.whatsapp.net', fromMe: false, id: 'deploy-probe' },
      message: { conversation: 'ping deploy' },
    },
  };
  try {
    const res = await fetchWithRetry(webhook, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const text = await res.text();
    console.log(`POST ${webhook} -> ${res.status} ${text.slice(0, 200)}`);
  } catch (e) {
    console.log('Webhook probe error:', e.message);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
