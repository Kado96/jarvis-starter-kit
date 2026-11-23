# Diagnose WhatsApp <-> Evolution API <-> n8n
# Usage: powershell -File .\scripts\diagnose.ps1

$ErrorActionPreference = 'Continue'
$EvoBase = $env:EVOLUTION_URL
if (-not $EvoBase) { $EvoBase = 'https://jarvis-evolution-api.onrender.com' }
$N8nBase = $env:N8N_URL
if (-not $N8nBase) { $N8nBase = 'https://n8n-ajs5.onrender.com' }
$ApiKey = $env:EVOLUTION_API_KEY
if (-not $ApiKey) { $ApiKey = 'jarvis-evolution-2026' }
$Webhook = "$N8nBase/webhook/jarvis-wa-evolution"

function Probe($name, $url, $headers = $null) {
  Write-Host ""
  Write-Host "=== $name ===" -ForegroundColor Cyan
  Write-Host "GET $url"
  try {
    $r = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 90
    Write-Host "OK $($r.StatusCode)" -ForegroundColor Green
    $preview = $r.Content
    if ($preview.Length -gt 400) { $preview = $preview.Substring(0, 400) + '...' }
    Write-Host $preview
    return $true
  } catch {
    $status = $null
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    Write-Host "FAIL status=$status :: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

Write-Host "Jarvis Evolution diagnose"
Write-Host "Evolution: $EvoBase"
Write-Host "n8n:       $N8nBase"

$evoOk = Probe 'Evolution API root' "$EvoBase/"
$instOk = Probe 'Evolution instances' "$EvoBase/instance/fetchInstances" @{ apikey = $ApiKey }
$n8nOk = Probe 'n8n home' "$N8nBase/"

Write-Host ""
Write-Host "=== Webhook POST test ===" -ForegroundColor Cyan
Write-Host "POST $Webhook"
try {
  $body = @{
    event = 'messages.upsert'
    instance = 'jarvis-principal'
    data = @{
      key = @{ remoteJid = '25779928864@s.whatsapp.net'; fromMe = $false; id = 'diag-test' }
      message = @{ conversation = 'ping diagnose' }
    }
  } | ConvertTo-Json -Depth 6
  $r = Invoke-WebRequest -Uri $Webhook -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 90
  Write-Host "OK $($r.StatusCode) body=$($r.Content)" -ForegroundColor Green
} catch {
  $status = $null
  if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
  Write-Host "FAIL status=$status :: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Si 404: workflow non importe ou non Active dans n8n." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Verdict ===" -ForegroundColor Cyan
if (-not $evoOk) {
  Write-Host "BLOQUANT: Evolution API injoignable (404/timeout). Deployer sur Render ou Koyeb d'abord." -ForegroundColor Red
} elseif (-not $instOk) {
  Write-Host "Evolution vit mais /instance/fetchInstances echoue. Verifier AUTHENTICATION_API_KEY." -ForegroundColor Yellow
} else {
  Write-Host "Evolution joignable. Verifier state=open pour jarvis-principal, sinon rescanner QR." -ForegroundColor Green
}
if (-not $n8nOk) {
  Write-Host "n8n endormi ou down (Render Free). Ouvre $N8nBase pour le reveiller, puis reteste." -ForegroundColor Yellow
}
Write-Host "Webhook attendu: $Webhook"
Write-Host "Import workflow: n8n-workflow-jarvis-wa-evolution.json puis Active = ON"
