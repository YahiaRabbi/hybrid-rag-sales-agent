# Ask the sales agent a question from PowerShell.
#
# Usage:
#   $env:WEBHOOK_SECRET = "your-secret"   # same value as the "Webhook Secret" credential in n8n
#   .\tests\ask.ps1 -Message "Any velvet dresses under 15000?" -Session "customer_a"
#
# Use a different -Session value to act as a different customer.
# Each session has its own memory, so customer_b never sees customer_a's chat.
param(
  [string]$Message = "Do you have silk party wear under 8000?",
  [string]$Session = "customer_a",
  [string]$BaseUrl = "http://localhost:5678",
  [string]$Secret  = $env:WEBHOOK_SECRET
)

if (-not $Secret) {
  Write-Host "Set the WEBHOOK_SECRET environment variable first (see the comment at the top)." -ForegroundColor Yellow
  exit 1
}

$uri     = "$BaseUrl/webhook/sales-agent"
$headers = @{ "X-Webhook-Key" = $Secret }
$body    = @{ session_id = $Session; message = $Message } | ConvertTo-Json

Write-Host "[$Session] Customer: $Message" -ForegroundColor Cyan
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
  $r = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json; charset=utf-8" `
       -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 120
  $sw.Stop()
  Write-Host "Agent ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s): $($r.output)" -ForegroundColor Green
} catch {
  Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "403 = wrong or missing secret. 404 = workflow not published." -ForegroundColor Yellow
}
