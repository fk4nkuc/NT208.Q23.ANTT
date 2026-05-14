# measure-overhead.ps1
# So sanh latency: OTel ON (port 8000) vs OTel OFF (port 8001)
# Chay: powershell -ExecutionPolicy Bypass -File .\test-scripts\measure-overhead.ps1
param([int]$Requests = 50)

$UrlOn  = "http://localhost:8000/api/data"
$UrlOff = "http://localhost:8001/api/data"

function Measure-Latency([string]$Label, [string]$Url, [int]$N) {
    Write-Host "`n=== $Label ===" -ForegroundColor Cyan
    $times  = [System.Collections.Generic.List[double]]::new()
    $errors = 0
    for ($i = 1; $i -le $N; $i++) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $r  = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $sw.Stop()
            if ($r.StatusCode -eq 200) { $times.Add($sw.Elapsed.TotalMilliseconds) }
            else { $errors++ }
        } catch { $errors++ }
        Write-Host -NoNewline "."
    }
    Write-Host ""
    if ($times.Count -eq 0) {
        Write-Host "  Tat ca request that bai! Kiem tra container dang chay." -ForegroundColor Red
        return $null
    }
    $s   = $times | Sort-Object
    $avg = ($times | Measure-Object -Average).Average
    $p50 = $s[[int]($s.Count * 0.50)]
    $p95 = $s[[int]([Math]::Min([int]($s.Count * 0.95), $s.Count - 1))]
    $p99 = $s[[int]([Math]::Min([int]($s.Count * 0.99), $s.Count - 1))]
    Write-Host ("  OK={0}  ERR={1}   avg={2:F1}ms  P50={3:F1}ms  P95={4:F1}ms  P99={5:F1}ms" -f $times.Count, $errors, $avg, $p50, $p95, $p99)
    return @{ avg=$avg; p50=$p50; p95=$p95; p99=$p99 }
}

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  Overhead Measurement: OTel ON vs OFF"          -ForegroundColor Yellow
Write-Host "  Requests per run: $Requests"                   -ForegroundColor Yellow
Write-Host "================================================"

# Kiem tra container chinh dang chay
try { $null = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop }
catch { Write-Host "fastapi-demo chua chay tai port 8000. Hay chay 'docker compose up -d' truoc." -ForegroundColor Red; exit 1 }

# --- RUN 1: OTel ON ---
$on = Measure-Latency -Label "OTel ON  (port 8000, container chinh)" -Url $UrlOn -N $Requests

# Lay ten image va network tu container dang chay
$image   = docker inspect fastapi-demo --format '{{.Config.Image}}'
$network = docker inspect fastapi-demo --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}'

if (-not $image) { Write-Host "Khong lay duoc image. Kiem tra fastapi-demo container." -ForegroundColor Red; exit 1 }
Write-Host ("`nKhoi dong container thu nghiem (OTel OFF)...") -ForegroundColor Magenta
Write-Host "  Image:   $image"
Write-Host "  Network: $network"

# Xoa container cu neu ton tai
docker rm -f fastapi-demo-notel 2>$null | Out-Null

# Chay container thu nghiem tren port 8001
docker run -d --rm --name fastapi-demo-notel --network $network -p 8001:8000 -e OTEL_ENABLED=false $image | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "docker run that bai." -ForegroundColor Red; exit 1 }

Write-Host "  Cho 5 giay container san sang..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# --- RUN 2: OTel OFF ---
$off = Measure-Latency -Label "OTel OFF (port 8001, container thu nghiem)" -Url $UrlOff -N $Requests

# Cleanup
docker stop fastapi-demo-notel 2>$null | Out-Null
Write-Host "Container thu nghiem da dung."

# --- In ket qua ---
Write-Host "`n================================================" -ForegroundColor Yellow
Write-Host "  KET QUA"                                        -ForegroundColor Yellow
Write-Host "================================================"

if ($on -and $off) {
    Write-Host ("  OTel ON   avg={0:F1}ms  P50={1:F1}ms  P95={2:F1}ms  P99={3:F1}ms" -f $on.avg,  $on.p50,  $on.p95,  $on.p99)
    Write-Host ("  OTel OFF  avg={0:F1}ms  P50={1:F1}ms  P95={2:F1}ms  P99={3:F1}ms" -f $off.avg, $off.p50, $off.p95, $off.p99)
    Write-Host "  ------------------------------------------------"
    $diff    = $on.avg - $off.avg
    $diffPct = if ($off.avg -gt 0) { $diff / $off.avg * 100 } else { 0 }
    $color   = if ($diffPct -lt 5) { "Green" } else { "Yellow" }
    Write-Host ("  Overhead: +{0:F1}ms  (+{1:F1}%)" -f $diff, $diffPct) -ForegroundColor $color
    if ($diffPct -lt 5) { Write-Host "  => Overhead < 5%: chap nhan duoc cho production." -ForegroundColor Green }
    else                { Write-Host "  => Overhead > 5%: nen dung sampling de giam tai." -ForegroundColor Yellow }
    Write-Host "================================================"

    if (-not (Test-Path "results")) { New-Item -ItemType Directory -Path "results" | Out-Null }
    @{ timestamp=(Get-Date -Format "yyyy-MM-ddTHH:mm:ss"); requests=$Requests; otel_on=$on; otel_off=$off; overhead_ms=$diff; overhead_pct=$diffPct } |
        ConvertTo-Json | Out-File -FilePath "results\overhead-result.json" -Encoding utf8
    Write-Host "Ket qua da luu: results\overhead-result.json"
} else {
    Write-Host "Thieu du lieu de so sanh." -ForegroundColor Red
}
