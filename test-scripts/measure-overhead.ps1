# measure-overhead.ps1
# Do overhead cua OpenTelemetry bang cach chay k6 voi OTel ON vs OFF
# Chay tu PowerShell: .\test-scripts\measure-overhead.ps1
# Yeu cau: k6 da cai trong WSL, docker-compose dang chay

param(
    [int]$Requests = 50,
    [string]$Endpoint = "http://localhost:8000/api/data"
)

function Measure-Latency {
    param([string]$Label, [int]$N, [string]$Url)
    Write-Host "`n=== $Label ===" -ForegroundColor Cyan
    $times = @()
    $errors = 0
    for ($i = 1; $i -le $N; $i++) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $sw.Stop()
            if ($resp.StatusCode -eq 200) {
                $times += $sw.Elapsed.TotalMilliseconds
            } else {
                $errors++
            }
        } catch {
            $errors++
        }
    }
    if ($times.Count -gt 0) {
        $sorted = $times | Sort-Object
        $avg    = ($times | Measure-Object -Average).Average
        $p50    = $sorted[[int]($sorted.Count * 0.5)]
        $p95    = $sorted[[int]($sorted.Count * 0.95)]
        $p99    = $sorted[[int]([Math]::Min($sorted.Count * 0.99, $sorted.Count - 1))]
        Write-Host ("  Requests: {0} ok, {1} errors" -f $times.Count, $errors)
        Write-Host ("  avg={0:F1}ms  P50={1:F1}ms  P95={2:F1}ms  P99={3:F1}ms" -f $avg, $p50, $p95, $p99)
        return @{ avg=$avg; p50=$p50; p95=$p95; p99=$p99 }
    } else {
        Write-Host "  All requests failed!" -ForegroundColor Red
        return $null
    }
}

Write-Host "================================================" -ForegroundColor Yellow
Write-Host " Overhead Measurement: OTel ON vs OFF" -ForegroundColor Yellow
Write-Host " Endpoint: $Endpoint" -ForegroundColor Yellow
Write-Host " Requests per run: $Requests" -ForegroundColor Yellow
Write-Host "================================================"

# --- RUN 1: OTel ON (trang thai hien tai) ---
$on = Measure-Latency -Label "OTel ENABLED (current)" -N $Requests -Url $Endpoint

# --- Switch OTel OFF ---
Write-Host "`nSwitching OTEL_ENABLED=false, rebuilding fastapi-demo..." -ForegroundColor Magenta
# Update env inline via docker
docker exec fastapi-demo sh -c "exit" 2>$null
docker compose stop fastapi-demo | Out-Null

# Override OTEL_ENABLED=false bang bien moi truong
$env:OTEL_ENABLED_OVERRIDE = "false"
docker compose run --rm -e OTEL_ENABLED=false -p 8000:8000 -d --name fastapi-demo-notel fastapi-demo 2>$null

# Gian don hon: dung docker compose scale voi override
# Thay vao do, restart container voi env override
docker run -d --rm `
    --name fastapi-demo-notel `
    --network project-observability_observability `
    -p 8001:8000 `
    -e OTEL_ENABLED=false `
    -e OTEL_SERVICE_NAME=fastapi-demo-notel `
    (docker inspect fastapi-demo --format "{{.Config.Image}}" 2>$null) 2>$null | Out-Null

$notelUrl = $Endpoint -replace ":8000", ":8001"
Write-Host "Waiting 3s for no-OTel instance to start..." -ForegroundColor Gray
Start-Sleep -Seconds 3

# --- RUN 2: OTel OFF ---
$off = Measure-Latency -Label "OTel DISABLED (port 8001)" -N $Requests -Url $notelUrl

# Cleanup
docker stop fastapi-demo-notel 2>$null | Out-Null
docker compose start fastapi-demo | Out-Null

# --- Summary ---
if ($on -and $off) {
    Write-Host "`n================================================" -ForegroundColor Yellow
    Write-Host " OVERHEAD SUMMARY" -ForegroundColor Yellow
    Write-Host "================================================"
    Write-Host ("  OTel ON  avg={0:F1}ms  P95={1:F1}ms  P99={2:F1}ms" -f $on.avg, $on.p95, $on.p99)
    Write-Host ("  OTel OFF avg={0:F1}ms  P95={1:F1}ms  P99={2:F1}ms" -f $off.avg, $off.p95, $off.p99)
    $overheadAvg = $on.avg - $off.avg
    $overheadPct = if ($off.avg -gt 0) { $overheadAvg / $off.avg * 100 } else { 0 }
    Write-Host ("  Overhead: +{0:F1}ms avg  (+{1:F1}%)" -f $overheadAvg, $overheadPct) -ForegroundColor Green
    Write-Host "================================================"

    # Save to file
    $result = @{
        timestamp    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        endpoint     = $Endpoint
        otel_on      = $on
        otel_off     = $off
        overhead_ms  = $overheadAvg
        overhead_pct = $overheadPct
    }
    $result | ConvertTo-Json | Out-File -FilePath "results\overhead-result.json" -Encoding utf8
    Write-Host "Results saved to results\overhead-result.json"
}
