# Create / connect WhatsApp instance on Evolution API
# Usage:
#   $env:EVOLUTION_URL = 'https://YOUR-URL'
#   powershell -File .\scripts\create-instance.ps1

$ErrorActionPreference = 'Stop'
$Base = $env:EVOLUTION_URL
if (-not $Base) { $Base = 'https://jarvis-evolution-api.onrender.com' }
$Base = $Base.TrimEnd('/')
$ApiKey = $env:EVOLUTION_API_KEY
if (-not $ApiKey) { $ApiKey = 'jarvis-evolution-2026' }
$Webhook = $env:N8N_WEBHOOK
if (-not $Webhook) { $Webhook = 'https://n8n-ajs5.onrender.com/webhook/jarvis-wa-evolution' }
$Instance = 'jarvis-principal'
$Headers = @{ apikey = $ApiKey; 'Content-Type' = 'application/json' }

Write-Host "Evolution: $Base"
Write-Host "Webhook:   $Webhook"

Write-Host "`n=== Health ===" -ForegroundColor Cyan
try {
  $h = Invoke-RestMethod -Uri "$Base/" -TimeoutSec 60
  Write-Host ($h | ConvertTo-Json -Compress)
} catch {
  Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Deploie Evolution d'abord (Render/Koyeb/Docker)." -ForegroundColor Yellow
  exit 1
}

Write-Host "`n=== Fetch instances ===" -ForegroundColor Cyan
try {
  $inst = Invoke-RestMethod -Uri "$Base/instance/fetchInstances" -Headers @{ apikey = $ApiKey } -TimeoutSec 60
  Write-Host ($inst | ConvertTo-Json -Depth 6 -Compress)
} catch {
  Write-Host "fetchInstances: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Create instance $Instance ===" -ForegroundColor Cyan
$body = @{
  instanceName = $Instance
  token = $ApiKey
  qrcode = $true
  integration = 'WHATSAPP-BAILEYS'
  webhook = $Webhook
  webhook_by_events = $false
  events = @('MESSAGES_UPSERT')
} | ConvertTo-Json

try {
  $created = Invoke-RestMethod -Uri "$Base/instance/create" -Method POST -Headers $Headers -Body $body -TimeoutSec 90
  Write-Host ($created | ConvertTo-Json -Depth 6 -Compress)
} catch {
  Write-Host "create (peut deja exister): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Set webhook ===" -ForegroundColor Cyan
$whBody = @{
  url = $Webhook
  webhook_by_events = $false
  webhook_base64 = $false
  events = @('MESSAGES_UPSERT')
} | ConvertTo-Json
try {
  $wh = Invoke-RestMethod -Uri "$Base/webhook/set/$Instance" -Method POST -Headers $Headers -Body $whBody -TimeoutSec 60
  Write-Host ($wh | ConvertTo-Json -Depth 6 -Compress)
} catch {
  Write-Host "webhook/set: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Connect / QR ===" -ForegroundColor Cyan
try {
  $qr = Invoke-RestMethod -Uri "$Base/instance/connect/$Instance" -Headers @{ apikey = $ApiKey } -TimeoutSec 90
  Write-Host ($qr | ConvertTo-Json -Depth 6)
  Write-Host "`nOuvre WhatsApp > Appareils connectes > Connecter un appareil et scanne le QR." -ForegroundColor Green
  Write-Host "Ou ouvre: $Base/instance/connect/$Instance" -ForegroundColor Green
} catch {
  Write-Host "connect: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
