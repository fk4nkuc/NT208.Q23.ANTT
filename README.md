# Observability Dashboard - Hướng dẫn Demo

Hệ thống observability đầy đủ với **Metrics + Logs + Traces** sử dụng Prometheus, Loki, Tempo và Grafana.

---

## Kiến trúc hệ thống

```
                        ┌─────────────────────────────────────────────────────┐
                        │                  OBSERVABILITY STACK                │
                        │                                                     │
  ┌──────────┐          │  ┌─────────────┐   ┌──────────┐   ┌─────────────┐   │
  │  Client  │          │  │ Prometheus  │   │   Loki   │   │    Tempo    │   │
  │(Browser/ │          │  │   :9090     │   │  :3100   │   │   :3200     │   │
  │  k6/     │          │  │ (Metrics)   │   │  (Logs)  │   │  (Traces)   │   │
  │ locust)  │          │  └──────┬──────┘   └────┬─────┘   └──────┬──────┘   │
  └────┬─────┘          │         │               │                │          │
       │                │         └───────────────┴────────────────┘          │
       ▼                │                         │                           │
  ┌─────────┐           │                   ┌─────▼──────┐                    │
  │  Nginx  │           │                   │  Grafana   │                    │
  │  Proxy  │           │                   │   :3001    │                    │
  │  :8080  │           │                   │(Dashboard) │                    │
  └────┬────┘           │                   └────────────┘                    │
       │ W3C            │                                                     │
       │ Trace          │  ┌──────────────────┐   ┌──────────────────────┐    │
       │ Context        │  │   fastapi-demo   │   │   springboot-demo    │    │
       │                │  │     :8000        │   │       :8083          │    │
       ├──────────────► │  │  (Python/OTEL)   │   │   (Java/Micrometer)  │    │
       │                │  │  /metrics        │   │  /actuator/prometheus│    │
       │                │  └────────┬─────────┘   └──────────┬───────────┘    │
       │                │           │ OTLP gRPC               │ OTLP gRPC     │
       │                │           └─────────────────────────┘               │
       │                │                         ▼                           │
       │                │                   ┌─────────┐                       │
       │                │                   │  Tempo  │                       │
       │                │                   │  :4317  │                       │
       │                │                   └─────────┘                       │
       │                │                                                     │
       │                │  ┌───────────────┐  ┌─────────────────────────────┐ │
       │                │  │ node-exporter │  │  Alloy (Log Collector)      │ │
       │                │  │    :9100      │  │  Docker → Loki              │ │
       │                │  │(CPU/Mem/Disk) │  │                             │ │
       │                │  └───────────────┘  └─────────────────────────────┘ │
       │                └─────────────────────────────────────────────────────┘
       │
       └── Alertmanager :9093
```

> **Lưu ý:** `localhost:8080` là Nginx proxy (dùng cho mọi demo). `localhost:8000` là FastAPI trực tiếp (chỉ dùng để lấy `/metrics` hoặc debug riêng).

---

## Stack công nghệ

| Component | Image | Chức năng |
|---|---|---|
| **Prometheus** | prom/prometheus | Thu thập & lưu trữ metrics |
| **Node Exporter** | prom/node-exporter | Metrics hệ thống: CPU, RAM, Disk, Network |
| **Loki** | grafana/loki | Tổng hợp & truy vấn logs |
| **Alloy** | grafana/alloy | Thu thập logs từ Docker containers → Loki |
| **Tempo** | grafana/tempo:2.6.0 | Distributed tracing backend (OTLP) |
| **Alertmanager** | prom/alertmanager | Quản lý & định tuyến cảnh báo |
| **Grafana** | grafana/grafana | Dashboard tổng hợp (Metrics + Logs + Traces) |
| **Nginx** | nginx | Reverse proxy + W3C Trace Context propagation |
| **FastAPI** | custom | Demo app Python với OpenTelemetry |
| **Spring Boot** | custom | Demo app Java với Micrometer |
| **Redis** | redis:7-alpine | In-memory DB — tạo DB span trong trace chain |

---

## Yêu cầu hệ thống

- Docker Desktop (Linux containers mode)
- RAM tối thiểu: **4 GB** dành cho Docker
- Ports cần mở: `3001, 8080, 8000, 8083, 9090, 9093, 3100, 3200, 6379`

---

## Khởi động hệ thống

### Bước 1: Build và chạy toàn bộ stack

```bash
docker compose up --build -d
```

Lần đầu build Spring Boot mất khoảng 2–3 phút.

### Bước 2: Xác nhận hệ thống sẵn sàng

Chạy lệnh sau — tất cả phải trả về `up`:

```bash
# Kiểm tra 5 Prometheus targets
curl -s http://localhost:9090/api/v1/targets \
  | python -c "import sys,json; [print(t['labels']['job'], t['health']) for t in json.load(sys.stdin)['data']['activeTargets']]"
```

**Kết quả mong đợi:**
```
alertmanager    up
fastapi-demo    up
node_exporter   up
prometheus      up
springboot-demo up
```

Nếu có target `unknown` thì chờ thêm 30 giây rồi chạy lại.

---

## URL truy cập

| Service | URL | Thông tin đăng nhập |
|---|---|---|
| **Grafana** | http://localhost:3001 | `admin` / `admin` |
| **Prometheus** | http://localhost:9090 | - |
| **Alertmanager** | http://localhost:9093 | - |
| **FastAPI (trực tiếp)** | http://localhost:8000 | - |
| **Spring Boot (trực tiếp)** | http://localhost:8083 | - |
| **Nginx Proxy (dùng cho demo)** | http://localhost:8080 | - |

---

## Dashboard Grafana

Mở Grafana tại http://localhost:3001 → **Dashboards** (menu trái):

| Dashboard | Mô tả |
|---|---|
| **Observability Overview** | Dashboard tổng hợp: service health, CPU/RAM, request rate, error rate, logs |
| **Application Metrics** | Chi tiết request rate, error rate, latency P50/P95/P99, logs |
| **System Overview** | CPU, Memory, Network I/O theo thời gian |

---

## Kịch bản Demo

> **Cách dùng tài liệu này:** Mỗi demo có 2 phần — **Chuẩn bị** (lệnh terminal tạo data) và **Kiểm tra trên Web UI** (điều hướng trực quan). Phần web UI là phần chính để trình bày.

---

### Demo 1: Kiểm tra luồng dữ liệu bình thường

**Mục tiêu:** Xác nhận metrics, logs và traces đều hoạt động sau khi khởi động — 3 pillar của observability đều có dữ liệu.

#### Chuẩn bị — Tạo traffic

```bash
# WSL / Linux / Mac
for i in $(seq 1 20); do
  curl -s http://localhost:8080/api/data > /dev/null
  curl -s http://localhost:8080/api/java/data > /dev/null
done
```

```powershell
# Windows PowerShell
for ($i = 1; $i -le 20; $i++) {
    Invoke-WebRequest -Uri http://localhost:8080/api/data -UseBasicParsing | Out-Null
    Invoke-WebRequest -Uri http://localhost:8080/api/java/data -UseBasicParsing | Out-Null
}
```

---

#### Kiểm tra 1 — Prometheus: Tất cả target UP

Mở **http://localhost:9090** → menu trên **Status** → **Targets**

Bạn thấy bảng danh sách scrape targets. Tất cả phải ở cột **State = UP** (màu xanh lá):

```
Endpoint                              State    Labels
http://alertmanager:9093/metrics      UP       job="alertmanager"
http://fastapi-demo:8000/metrics      UP       job="fastapi-demo"
http://localhost:9090/metrics         UP       job="prometheus"
http://node-exporter:9100/metrics     UP       job="node_exporter"
http://springboot-demo:8081/...       UP       job="springboot-demo"
```

Nếu có target **UNKNOWN**: chờ thêm 30 giây và refresh trang.

---

#### Kiểm tra 2 — Grafana: Dashboard tổng hợp

Mở **http://localhost:3001** (admin / admin) → menu trái **Dashboards** → chọn **Observability Overview**

**Hàng 1 — Service Health (4 panel stat):**

Mỗi panel hiển thị **UP** nền xanh lá hoặc **DOWN** nền đỏ:
```
┌─────────────┐ ┌──────────────┐ ┌───────────────┐ ┌───────────────┐
│ fastapi-demo│ │springboot-demo│ │ node-exporter │ │ alertmanager  │
│     UP      │ │      UP       │ │      UP       │ │      UP       │
└─────────────┘ └──────────────┘ └───────────────┘ └───────────────┘
```

**Hàng 2 — CPU & Memory (2 gauge + 1 timeseries):**
- Gauge **CPU Usage**: kim đồng hồ trỏ vào vùng xanh (< 60%)
- Gauge **Memory Usage**: kim đồng hồ trỏ vào vùng xanh (< 70%)
- Timeseries **CPU & Memory Over Time**: thấy 2 đường biểu đồ (không phải "No data")

**Hàng 3 — Application Metrics:**
- Panel **Request Rate (req/s)**: thấy đường tăng lên (≥ 0.1 req/s sau khi chạy lệnh tạo traffic)
- Panel **Error Rate (%)**: thấy đường dao động nhẹ (~10%)

**Hàng 4 — Response Time:**
- Panel **Response Time Percentiles**: thấy 3 đường P50 / P95 / P99 cùng màu khác nhau

**Hàng 5 — Logs:**
- Panel **Error & Warning Logs**: thấy các dòng log màu cam/đỏ
- Panel **All Logs**: thấy dòng log liên tục từ fastapi-demo và springboot-demo

---

#### Kiểm tra 3 — Grafana Explore: Traces trong Tempo

Grafana → menu trái **Explore** (biểu tượng la bàn) → chọn datasource **Tempo** (góc trên)

Chọn tab **Search** → trường **Service Name** chọn `fastapi-demo` → bấm **Run query**

Bạn thấy danh sách trace với cột:
```
Trace ID          | Root span name   | Duration | Spans
91e4712dfbea3afe  | GET /api/data    | 67ms     | 6
bbb7be5e01f9a5d7  | GET /api/data    | 21ms     | 6
...
```

Click vào 1 trace bất kỳ → bên phải hiện **Trace view** dạng waterfall chart. Điều cần thấy:
- Span gốc: `GET /api/data` (màu xanh, dài nhất)
- 2 span con màu khác: `INCRBY` và `GET` — đây là Redis DB spans

---

### Demo 2: Giả lập lỗi và xác định nguyên nhân (Root Cause Analysis)

**Mục tiêu:** Chứng minh từ alert → log → trace, tìm được nguyên nhân lỗi trong < 2 phút.

> **Quan trọng:** Phải gửi lỗi **liên tục** vì Prometheus dùng `rate()` — nếu counter tăng rồi dừng, rate về 0 ngay và alert không fire.

#### Chuẩn bị — Ghi T0 và bắt đầu tạo lỗi liên tục

Ghi lại giờ hiện tại là **T0**, rồi chạy lệnh sau trong **terminal riêng** (để nó chạy nền):

```bash
# WSL / Linux / Mac — gửi 1 lỗi/giây trong 150 giây
echo "T0 = $(date '+%H:%M:%S')"
for i in $(seq 1 150); do
  curl -s http://localhost:8080/api/error > /dev/null
  curl -s http://localhost:8080/api/data  > /dev/null
  sleep 1
done
```

```powershell
# Windows PowerShell
Write-Host "T0 = $(Get-Date -Format 'HH:mm:ss')"
for ($i = 1; $i -le 150; $i++) {
    Invoke-WebRequest -Uri http://localhost:8080/api/error -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null
    Invoke-WebRequest -Uri http://localhost:8080/api/data  -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 1
}
```

---

#### Kiểm tra 1 — Grafana: Error Rate tăng vọt (ngay lập tức, T0 + 15s)

Mở **Observability Overview** → panel **Error Rate (%)**

Bạn thấy đường biểu đồ nhảy từ ~10% lên ~**50%** (vì cứ 1 request lỗi thì kèm 1 request thường):

```
Error Rate (%)
50% ─────────────────────────╮
                              │ ← Error rate đang cao
10% ──────╮                   │
 0% ──────╯___________________│___→ time
        bình thường          T0
```

---

#### Kiểm tra 2 — Prometheus: Alert chuyển từ inactive → pending → firing

Mở **http://localhost:9090** → menu **Alerts**

Sau ~30 giây từ T0, bạn thấy `HighErrorRate` chuyển sang **pending** (nền vàng):
```
HighErrorRate   [pending]   Error rate > 5%
```

Sau ~2 phút từ T0, chuyển sang **firing** (nền đỏ):
```
HighErrorRate   [firing]    Error rate > 5%
                            Firing since: 14:32:15
                            error rate is X% (threshold: 5%)
```

---

#### Kiểm tra 3 — Alertmanager: Alert đang active

Mở **http://localhost:9093**

Bạn thấy bảng **Alerts** với 1 dòng màu đỏ:
```
alertname       severity    summary
HighErrorRate   critical    Error rate > 5%
```

Click vào alert đó để xem chi tiết: `description: HTTP 5xx error rate is X% (threshold: 5%)`

---

#### Kiểm tra 4 — Grafana Explore: Tìm log lỗi và nhảy sang Trace

Grafana → **Explore** → datasource **Loki**

Nhập query vào ô LogQL:
```
{container_name="fastapi-demo"} |~ "(?i)error"
```

Bấm **Run query** (Shift+Enter). Bạn thấy danh sách log entries màu đỏ/cam:
```
TIME                  | CONTAINER     | LOG
2026-05-14 14:32:10   | fastapi-demo  | ERROR fastapi-demo trace_id=5f3290ab... forced error endpoint called
2026-05-14 14:32:09   | fastapi-demo  | ERROR fastapi-demo trace_id=8a1b2c3d... forced error endpoint called
```

**Bước nhảy sang Trace:**
1. Click vào 1 dòng log để **expand** nó
2. Bạn thấy trường `trace_id = 5f3290ab37fa80c8...`
3. Bên cạnh trace_id có nút **Tempo** hoặc **View Trace** → click vào

Tempo mở ra ở bên phải, hiện **Trace view** với span:
```
GET /api/error   [500]   2ms
└── (no child spans — lỗi xảy ra trực tiếp tại endpoint)
```

Đây là luồng debug đầy đủ: **Alert firing → tìm log → lấy trace_id → xem trace trong Tempo**.

**MTTD ≈ 2 phút** (từ T0 đến khi alert firing)

---

### Demo 3: Stress Test và quan sát Bottleneck

**Mục tiêu:** Tạo tải cao, quan sát bottleneck bằng mắt trên Grafana dashboard.

**Yêu cầu:** k6 đã cài (WSL: `sudo apt install k6` hoặc https://k6.io/docs/get-started/installation/)

#### Chuẩn bị — Chạy load test

```bash
# WSL terminal — test chạy ~2.5 phút
cd /mnt/d/UIT/HK4/LTW/project-observability
k6 run test-scripts/k6-load-test.js
```

**Giữ terminal này mở** và **mở Grafana song song** để quan sát real-time.

---

#### Kiểm tra 1 — Grafana: Quan sát tải tăng theo thời gian

Mở **Observability Overview** → đặt thời gian ở góc trên phải là **Last 5 minutes**, auto-refresh **10s**

**Panel Request Rate (req/s)** — theo giai đoạn k6:

```
req/s
 8 ─────────────╮ peak (100 users)
 4 ────╮        │
 1 ─╮  │        │
 0 ─╯  ╰────────╯─────→ time
   ramp  load   peak  cooldown
```

Số req/s mong đợi:
- Ramp-up (0–30s): tăng từ 0 → ~3 req/s
- Load test (30s–90s): ổn định ~5 req/s
- Peak (90s–120s): tăng ~8–10 req/s

**Panel Response Time Percentiles:**

```
time (ms)
2000 ──────────────────────────── P99 ← /api/slow bottleneck
1000 ────────────────────────── P95
 500
 200 ──────────────────────────── P50
   0─────────────────────────────→ time
```

P99 vượt ngưỡng 1000ms → alert `HighRequestLatency` có thể firing.

---

#### Kiểm tra 2 — Prometheus: Query bottleneck theo endpoint

Mở **http://localhost:9090** → tab **Graph**

Dán query vào ô Expression:
```
histogram_quantile(0.99, sum by(endpoint, le) (rate(http_request_duration_seconds_bucket[1m])))
```

Bấm **Execute** → chọn tab **Graph**

Bạn thấy nhiều đường theo endpoint:
- `/api/slow` → đường cao nhất (~1500–2000ms) ← **đây là bottleneck**
- `/api/data` → đường giữa (~100–200ms)
- `/health` → đường gần 0 (~2–5ms)

---

#### Kiểm tra 3 — k6 terminal output (sau khi test xong)

k6 in ra bảng kết quả:
```
✓ data endpoint status 200
✓ slow endpoint handles load

http_req_duration............: avg=XXXms min=XXms med=XXXms p(95)=XXXXms p(99)=XXXXms
http_req_failed..............: X.XX%
requests_total...............: XXXX
```

Nhìn vào:
- `p(99)` của `http_req_duration` — nếu > 1000ms → alert đã fire
- `http_req_failed rate` — nếu > 5% → hệ thống đang quá tải
- `requests_total` — tổng số request đã xử lý

---

### Demo 4: Trace request xuyên suốt Nginx → FastAPI → Redis (DB)

**Mục tiêu:** Mở 1 trace trong Grafana/Tempo, chứng minh thấy được đường đi request qua các lớp: proxy → app → database.

#### Chuẩn bị — Tạo 1 request

```bash
curl -s http://localhost:8080/api/data
```

Bạn thấy response kèm `request_count` — đây là giá trị đọc từ Redis:
```json
{"data": "success", "delay_ms": 87.3, "request_count": 15}
```

Chờ 3 giây để Tempo index xong trace.

---

#### Kiểm tra 1 — Grafana Explore: Tìm trace và xem span tree

Grafana → **Explore** → datasource **Tempo** (góc trên)

Chọn tab **Search**:
- **Service Name**: `fastapi-demo`
- **Span Name**: `GET /api/data`
- Bấm **Run query**

Bạn thấy danh sách trace:
```
Trace ID         | Root span        | Duration | Spans
91e4712dfbea3afe | GET /api/data    | 67ms     | 6
bbb7be5e01f9a5d7 | GET /api/data    | 21ms     | 6
```

Click vào 1 trace → bên phải hiện **Trace view (waterfall)**:

```
fastapi-demo: GET /api/data ──────────────────── 67ms
  fastapi-demo: INCRBY ──  1ms      ← Redis DB span
  fastapi-demo: GET    ──  1ms      ← Redis DB span
  (http send spans)   ──── 0ms
```

Hover vào span `INCRBY` hoặc `GET` → bảng attributes hiện:
```
db.system    = redis
db.statement = INCRBY ? ?    (hoặc GET ?)
net.peer.name = redis
net.peer.port = 6379
```

Đây là bằng chứng trace đi **xuyên App → DB** (Redis), không chỉ dừng ở HTTP layer.

---

#### Kiểm tra 2 — Grafana Explore: Log → Trace correlation

Grafana → **Explore** → datasource **Loki**

Query:
```
{container_name="fastapi-demo"} |~ "trace_id=[1-9a-f]"
```

Bạn thấy log entries:
```
2026-05-14 14:45:22 | fastapi-demo | INFO fastapi-demo trace_id=91e4712dfbea3afe... handled request
```

1. Click vào log entry → expand
2. Thấy trường `trace_id = 91e4712dfbea3afe05150135e76551eb`
3. Click nút **Tempo** bên cạnh giá trị trace_id
4. Tempo mở ngay trace đó — thấy span tree bao gồm cả Redis spans

Đây là **log → trace correlation** hoạt động end-to-end.

---

#### Kiểm tra 3 — Nginx proxy header

Mở **http://localhost:8080/api/data** trong trình duyệt → F12 → tab **Network** → click request → tab **Headers**

Trong Response Headers, thấy:
```
X-Request-ID: 7f4a1b9c2d3e...
```

Gọi thẳng FastAPI **http://localhost:8000/api/data** → F12 → Network → **không có** X-Request-ID trong response. Điều này chứng minh request qua Nginx mới có header này.

---

### Demo 5: Kiểm tra 5 Alert Rules tự động

**Mục tiêu:** Chứng minh hệ thống có cảnh báo tự động, firing đúng khi có sự cố.

#### Kiểm tra 1 — Prometheus: Xem toàn bộ alert rules

Mở **http://localhost:9090** → menu **Alerts**

Bạn thấy danh sách 5 rules (khi bình thường tất cả **inactive** — nền xám):

```
system_alerts
  HighCPUUsage       [inactive]   CPU usage > 80% on ...
  HighMemoryUsage    [inactive]   Memory usage > 90% on ...
  HighRequestLatency [inactive]   P99 latency > 1s
  HighErrorRate      [inactive]   Error rate > 5%
  ServiceDown        [inactive]   Service ... is down
```

Click vào tên rule bất kỳ để xem expression PromQL và threshold.

---

#### Kiểm tra 2 — Demo ServiceDown alert

**Bước 1:** Dừng fastapi-demo:
```bash
docker compose stop fastapi-demo
```

**Bước 2:** Mở **http://localhost:9090/alerts** và **refresh mỗi 15 giây**

Sau ~15s: `ServiceDown` chuyển sang **pending** (nền vàng)
Sau ~75s: `ServiceDown` chuyển sang **firing** (nền đỏ):

```
ServiceDown   [firing]
  Labels: job="fastapi-demo", severity="critical"
  Annotations: Service fastapi-demo is down
               Target fastapi-demo:8000 unreachable for > 1 minute
```

**Bước 3:** Mở **http://localhost:9093** — thấy alert trong danh sách Active Alerts:
```
alertname=ServiceDown | severity=critical
Summary: Service fastapi-demo is down
Active since: 14:52:33
```

**Bước 4:** Khôi phục service:
```bash
docker compose start fastapi-demo
```

Sau 1–2 phút, alert biến mất khỏi Alertmanager và Prometheus trở về **inactive**.

---

#### Kiểm tra 3 — Demo HighRequestLatency alert

**Bước 1:** Tạo traffic chậm liên tục (chạy trong terminal riêng):

```bash
# WSL / Linux
for i in $(seq 1 60); do
  curl -s http://localhost:8080/api/slow > /dev/null &
  sleep 1
done
```

```powershell
# PowerShell
for ($i = 1; $i -le 60; $i++) {
    Start-Job { Invoke-WebRequest http://localhost:8080/api/slow -UseBasicParsing | Out-Null }
    Start-Sleep -Seconds 1
}
```

**Bước 2:** Mở **Prometheus → Alerts** → theo dõi `HighRequestLatency`

Sau ~2 phút, chuyển **firing** (nền đỏ):
```
HighRequestLatency   [firing]
  P99 request latency is 1.87s (threshold: 1s)
```

---

### Demo 6: Đo overhead của Tracing (OTel ON vs OFF)

**Mục tiêu:** So sánh latency có và không có OpenTelemetry, chứng minh overhead < 5%.

#### Chuẩn bị — Chạy script đo overhead

```powershell
# Windows PowerShell — tu thu muc goc project
powershell -ExecutionPolicy Bypass -File .\test-scripts\measure-overhead.ps1 -Requests 50
```

```bash
# WSL — đo OTel ON (port 8000)
echo "=== OTel ON ==="
for i in $(seq 1 30); do
  curl -s -w "%{time_total}\n" -o /dev/null http://localhost:8000/api/data
done | python -c "import sys; t=[float(l)*1000 for l in sys.stdin if float(l)<2]; s=sorted(t); print(f'avg={sum(t)/len(t):.1f}ms  P50={s[len(s)//2]:.1f}ms  P95={s[int(len(s)*0.95)]:.1f}ms')"

# Spin up container không OTel ở port 8001
docker run -d --rm --name fastapi-notel \
  --network project-observability_observability \
  -p 8001:8000 -e OTEL_ENABLED=false \
  $(docker inspect fastapi-demo --format "{{.Config.Image}}") && sleep 3

echo "=== OTel OFF ==="
for i in $(seq 1 30); do
  curl -s -w "%{time_total}\n" -o /dev/null http://localhost:8001/api/data
done | python -c "import sys; t=[float(l)*1000 for l in sys.stdin if float(l)<2]; s=sorted(t); print(f'avg={sum(t)/len(t):.1f}ms  P50={s[len(s)//2]:.1f}ms  P95={s[int(len(s)*0.95)]:.1f}ms')"

docker stop fastapi-notel
```

---

#### Kiểm tra — Prometheus: So sánh latency theo endpoint

Mở **http://localhost:9090** → tab **Graph**

Dán query:
```
histogram_quantile(0.50, sum by(endpoint, le) (rate(http_request_duration_seconds_bucket[5m])))
```

Bấm **Execute** → tab **Table**. Bạn thấy bảng so sánh P50 theo endpoint:

```
Metric                          Value
{endpoint="/health"}            0.002   →  2ms   ← overhead thuần OTel
{endpoint="/metrics"}           0.003   →  3ms
{endpoint="/api/data"}          0.090   →  90ms  ← business logic + OTel
{endpoint="/api/slow"}          1.200   →  1200ms ← sleep dominates
```

**Đọc kết quả:**
- `/health` chỉ return `{"status":"ok"}` không có business logic → **latency ~2ms = overhead thuần của OTel**
- `/api/data` có random sleep 10–200ms + Redis call → **OTel overhead chiếm ~2ms / 90ms = ~2.2%**

---

#### Kết luận overhead

| | OTel ON | OTel OFF | Overhead |
|---|---|---|---|
| avg latency | ~95ms | ~91ms | **+4ms (+4.4%)** |
| P95 latency | ~180ms | ~174ms | **+6ms (+3.4%)** |
| CPU overhead | baseline | baseline −1% | **không đáng kể** |

**Kết luận:** OpenTelemetry thêm ~2–5ms mỗi request. Với endpoint có business logic ≥ 50ms, overhead < 5% — chấp nhận được cho production.

---

## Phân tích MTTD (Mean Time To Detect)

| Kịch bản | T0 | T1 (phát hiện) | MTTD | Cách phát hiện |
|---|---|---|---|---|
| Error rate cao | Bắt đầu gọi `/api/error` | ~2 phút sau | **~2 phút** | Alert `HighErrorRate` firing |
| Service down | Stop container | ~1 phút sau | **~1 phút** | Alert `ServiceDown` firing |
| Latency cao | Gọi nhiều `/api/slow` | ~2 phút sau | **~2 phút** | Alert `HighRequestLatency` |
| Không có observability | User báo lỗi | Phụ thuộc SLA | **>30 phút** | SSH + grep log thủ công |

**Kết luận:** Observability giảm MTTD từ >30 phút xuống còn **1–2 phút**.

---

## Correlation: Log ↔ Metric ↔ Trace

```
Error Rate tăng (Grafana panel)
    │
    └─► Query Loki: {container_name="fastapi-demo"} |~ "ERROR"
            │
            └─► Log: ERROR trace_id=abc123... forced error
                    │
                    └─► Click "View Trace" → Tempo
                            │
                            └─► Span: GET /api/error HTTP 500
```

**Kiểm tra nhanh correlation hoạt động:**

```bash
# 1. Lấy trace_id từ log lỗi gần nhất
curl -s "http://localhost:3100/loki/api/v1/query_range?query=%7Bcontainer_name%3D%22fastapi-demo%22%7D%20%7C~%20%22ERROR%22%20%7C~%20%22trace_id%3D%5B1-9a-f%5D%22&limit=1&start=$(python -c "import time; print(int((time.time()-600)*1e9))")&end=$(python -c "import time; print(int(time.time()*1e9))")" \
  | python -c "import sys,json,re; lines=[v[1] for s in json.load(sys.stdin)['data']['result'] for v in s['values']]; m=[re.search(r'trace_id=([a-f0-9]{32})',l) for l in lines]; ids=[x.group(1) for x in m if x]; print('trace_id:', ids[0]) if ids else print('No error logs found - run Demo 2 first')"

# 2. Xác nhận trace_id đó có trong Tempo (thay TRACE_ID bên dưới)
# curl -s http://localhost:3200/api/traces/TRACE_ID | python -c "import sys,json; r=json.load(sys.stdin); print('Found!' if r.get('batches') else 'Not found')"
```

---

## Checklist hoàn thành

### Yêu cầu hệ thống

- [x] Thu thập CPU (node-exporter → Prometheus)
- [x] Thu thập Memory (node-exporter → Prometheus)
- [x] Request rate (`http_requests_total` counter)
- [x] Response time (`http_request_duration_seconds` histogram — P50/P95/P99)
- [x] Error rate (HTTP 5xx / total)
- [x] Thu thập logs từ nhiều service (FastAPI + Spring Boot → Alloy → Loki)
- [x] Trace request: Nginx → FastAPI → Redis (DB span) (W3C Trace Context + OpenTelemetry → Tempo)
- [x] Ít nhất 2 cảnh báo tự động (có 5: CPU, Memory, Latency, ErrorRate, ServiceDown)
- [x] Dashboard tổng hợp (Observability Overview: Metrics + Logs trong 1 dashboard, liên kết tới Traces)

### Triển khai

- [x] Prometheus + Grafana
- [x] Log aggregation: Loki + Alloy
- [x] Tracing middleware + Request ID propagation (Nginx)
- [x] Alert rules: CPU cao, latency tăng, service down
- [x] Dashboard tổng hợp toàn hệ thống

### Đánh giá

- [x] Giả lập lỗi và debug qua dashboard (Demo 2)
- [x] Stress test quan sát bottleneck (Demo 3 — k6)
- [x] Đo overhead logging/tracing (Demo 6 — OTel ON vs OFF, overhead ~2–4ms / <5%)
- [x] Phân tích MTTD (1–2 phút vs >30 phút không có monitoring)
- [x] Chứng minh observability hỗ trợ debug tốt hơn (correlation Log ↔ Metric ↔ Trace)

---

## Troubleshooting

### Target Prometheus `unknown` sau khi khởi động

Chờ 30 giây rồi chạy lại lệnh kiểm tra. Spring Boot cần 30–60s để start.

```bash
curl http://localhost:8083/actuator/health
# Phải trả về {"status":"UP"}
```

### Grafana không hiện dashboard

```bash
docker compose restart grafana
```

### Loki không có logs

```bash
docker compose logs alloy
# Kiểm tra có lỗi kết nối Docker socket không
```

### Alert không firing dù đủ điều kiện

Kiểm tra Prometheus có load đúng rule file không:
```bash
curl -s http://localhost:9090/api/v1/rules | python -c "import sys,json; print(len([r for g in json.load(sys.stdin)['data']['groups'] for r in g['rules']]), 'rules loaded')"
# Phải ra: 5 rules loaded
```

### Reset toàn bộ data

```bash
docker compose down -v
docker compose up --build -d
```
