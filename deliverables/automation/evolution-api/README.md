# Evolution API — Guide de déploiement complet
# Jarvis WhatsApp Bot (QR Code Method)
# Sans Meta Cloud API — Sans carte de paiement

---

## Architecture

```
WhatsApp Mobile (toi)
      ↓ QR Code scan (une seule fois)
Evolution API (Cloud: Render OU Koyeb)
      ↓ Webhook HTTP (chaque message reçu)
n8n (https://n8n-ajs5.onrender.com)
      ↓ Workflow: jarvis-wa-evolution
OpenRouter AI (GPT/Claude)
      ↓ Réponse générée
Evolution API → WhatsApp (réponse envoyée)
```

**Tout tourne dans le Cloud. Machine éteinte = OK. 24h/7j.**

---

## Fichiers dans ce dossier

| Fichier | Usage |
|---|---|
| `Dockerfile` | Image Docker (wraps evoapicloud/evolution-api:v2.3.7) |
| `docker-compose.yml` | Test local uniquement (référence) |
| `render.yaml` | Config Render (déploiement automatique) |
| `n8n-workflow-jarvis-wa-evolution.json` | Workflow n8n à importer (réponses WA) |
| `n8n-workflow-keepalive.json` | Keep-alive + alerte si session coupée |
| `scripts/diagnose.ps1` | Diagnostique Evolution + n8n + webhook |
| `README.md` | Ce guide |

> **État (2026-11-23)**  
> - n8n : workflows `Jarvis WA — Evolution API` + Keep-Alive **importés et Active** ; webhook `/webhook/jarvis-wa-evolution` → **200 OK**  
> - Evolution API : `https://jarvis-evolution-api.onrender.com` encore **404** → à déployer (Render / Koyeb). Docker Desktop local non démarré.

---

## ÉTAPE 1 — Déployer sur Render

### 1.1 — Push sur GitHub

```bash
cd E:\Application\jarvis-starter-kit
git add deliverables/automation/evolution-api/
git commit -m "feat: add Evolution API deployment config"
git push origin main
```

### 1.2 — Créer le service sur Render

1. Va sur https://dashboard.render.com
2. Clique **"New +"** → **"Web Service"**
3. Connecte ton repo GitHub → sélectionne `jarvis-starter-kit`
4. **Root Directory** : `deliverables/automation/evolution-api`
5. **Runtime** : Docker
6. **Name** : `jarvis-evolution-api`
7. **Region** : Frankfurt
8. **Plan** : Free
9. Clique **"Create Web Service"**

### 1.3 — Variables d'environnement (vérifier dans Render)

| Variable | Valeur |
|---|---|
| `SERVER_URL` | `https://jarvis-evolution-api.onrender.com` |
| `AUTHENTICATION_API_KEY` | `jarvis-evolution-2026` |
| `WEBHOOK_GLOBAL_ENABLED` | `true` |
| `WEBHOOK_GLOBAL_URL` | `https://n8n-ajs5.onrender.com/webhook/jarvis-wa-evolution` |
| `DATABASE_ENABLED` | `false` |
| `DEL_INSTANCE` | `false` |

### 1.4 — Vérifier que l'API est vivante

```bash
curl https://jarvis-evolution-api.onrender.com/
```
Réponse attendue : `{"status":"Server is running","version":"..."}`

---

## ÉTAPE 2 — Créer l'instance WhatsApp et scanner le QR Code

### 2.1 — Créer l'instance

```bash
curl -X POST https://jarvis-evolution-api.onrender.com/instance/create \
  -H "apikey: jarvis-evolution-2026" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "jarvis-principal",
    "token": "jarvis-evolution-2026",
    "qrcode": true,
    "webhook": "https://n8n-ajs5.onrender.com/webhook/jarvis-wa-evolution",
    "webhook_by_events": false,
    "events": ["MESSAGES_UPSERT"]
  }'
```

### 2.2 — Obtenir le QR Code

```bash
curl https://jarvis-evolution-api.onrender.com/instance/connect/jarvis-principal \
  -H "apikey: jarvis-evolution-2026"
```

La réponse contient un `base64` ou une URL vers le QR Code à scanner.

### 2.3 — Scanner le QR Code

1. Ouvre WhatsApp sur ton téléphone (`+257 79 928 864`)
2. Menu (3 points) → **Appareils connectés**
3. **Connecter un appareil**
4. Scanner le QR Code

✅ **Connexion permanente** — Pas de re-scan nécessaire sauf si tu déconnectes manuellement.

---

## ÉTAPE 3 — Déployer sur Koyeb (backup, ne dort jamais)

### 3.1 — Créer l'app sur Koyeb

1. Va sur https://app.koyeb.com
2. **Create App** → **Docker**
3. **Docker image** : `evoapicloud/evolution-api:v2.3.7`
4. **Port** : `8080`
5. **App name** : `jarvis-evolution-api`
6. **Region** : Frankfurt

### 3.2 — Variables d'environnement sur Koyeb

| Variable | Valeur |
|---|---|
| `SERVER_URL` | `https://jarvis-evolution-api-XXXXX.koyeb.app` |
| `AUTHENTICATION_API_KEY` | `jarvis-evolution-2026` |
| `AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES` | `true` |
| `WEBHOOK_GLOBAL_ENABLED` | `true` |
| `WEBHOOK_GLOBAL_URL` | `https://n8n-ajs5.onrender.com/webhook/jarvis-wa-evolution` |
| `WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS` | `false` |
| `DATABASE_ENABLED` | `false` |
| `DEL_INSTANCE` | `false` |
| `CONFIG_SESSION_PHONE_VERSION` | `2.3000.1023204200` |

> ⚠️ Remplace `SERVER_URL` par l'URL réelle générée par Koyeb après déploiement.

---

## ÉTAPE 4 — Créer le workflow n8n `jarvis-wa-evolution`

### Webhook Trigger
- **HTTP Method** : GET + POST
- **Path** : `jarvis-wa-evolution`
- **URL complète** : `https://n8n-ajs5.onrender.com/webhook/jarvis-wa-evolution`

### Import du workflow (recommandé)
1. Ouvre n8n → **Workflows** → **Import from File**
2. Importe `n8n-workflow-jarvis-wa-evolution.json`
3. Active le workflow (**Active = ON**)
4. URL webhook : `https://n8n-ajs5.onrender.com/webhook/jarvis-wa-evolution`

Le Code Node gère **Evolution API v1 et v2** (`data` = message, ou `data.messages[0]`).

### IF Node
- Condition : `{{ $json.skip }}` **is not equal to** `true`

### HTTP Request — OpenRouter AI
- **Method** : POST
- **URL** : `https://openrouter.ai/api/v1/chat/completions`
- **Headers** :
  - `Authorization: Bearer {{$env.OPENROUTER_API_KEY}}`  (clé dans n8n / `.env`, jamais en clair dans Git)
  - `Content-Type: application/json`
- **Body** :
```json
{
  "model": "openai/gpt-4o-mini",
  "max_tokens": 300,
  "messages": [
    {"role": "system", "content": "Tu es Jarvis, l'assistant IA personnel de Donald. Réponds de manière concise et utile."},
    {"role": "user", "content": "{{ $json.text }}"}
  ]
}
```

### HTTP Request — Envoyer la réponse via Evolution API
- **Method** : POST
- **URL** : `https://jarvis-evolution-api.onrender.com/message/sendText/jarvis-principal`
- **Headers** :
  - `apikey: jarvis-evolution-2026`
  - `Content-Type: application/json`
- **Body** :
```json
{
  "number": "25779928864",
  "text": "{{ $json.choices[0].message.content }}"
}
```

---

## ÉTAPE 5 — Workflow auto-activation n8n (optionnel)

Créer un workflow **Schedule Trigger** dans n8n pour maintenir la connexion active :
- **Trigger** : Cron `0 6 * * *` (tous les jours à 6h)
- **HTTP Request** : GET `https://jarvis-evolution-api.onrender.com/instance/fetchInstances`
  - Header : `apikey: jarvis-evolution-2026`

---

## Crédentiels importants

| Clé | Valeur |
|---|---|
| Evolution API Key | `jarvis-evolution-2026` |
| Instance Name | `jarvis-principal` |
| n8n Webhook | `https://n8n-ajs5.onrender.com/webhook/jarvis-wa-evolution` |
| OpenRouter Key | Variable n8n `OPENROUTER_API_KEY` (ne pas committer) |
| WhatsApp Owner | `25779928864` |

---

## Checklist — pourquoi WhatsApp ne répond pas

1. **Evolution API live ?** `curl https://jarvis-evolution-api.onrender.com/` → doit renvoyer `Server is running` (pas 404)
2. **Instance open ?** `GET /instance/fetchInstances` avec header `apikey` → `jarvis-principal` = `open`
3. **n8n réveillé ?** Ouvre `https://n8n-ajs5.onrender.com` (Render Free dort)
4. **Workflow Active ?** `Jarvis WA — Evolution API` = ON, path `jarvis-wa-evolution`
5. **Webhook Evolution** pointe vers `https://n8n-ajs5.onrender.com/webhook/jarvis-wa-evolution`
6. Diagnostic local : `powershell -File scripts/diagnose.ps1`

## Troubleshooting

| Problème | Solution |
|---|---|
| Evolution API = **404** | Service pas créé sur Render → **ÉTAPE 1** (Root Directory = `deliverables/automation/evolution-api`) |
| QR Code expiré | Re-appeler `/instance/connect/jarvis-principal` |
| Instance déconnectée | Vérifier `/instance/fetchInstances` → rescanner QR |
| Render endormi | Upgrade Starter **ou** déployer Evolution sur **Koyeb** (ÉTAPE 3) |
| Webhook n8n ne reçoit pas | Workflow **Active** + n8n réveillé ; tester `diagnose.ps1` |
| Message reçu mais pas de réponse | Exécutions n8n : raison `unauthorized` / `empty_text` / erreur OpenRouter |
| OpenRouter 401 | Vérifier la clé Bearer dans le node HTTP Request |
