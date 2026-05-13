# Observability Demo Stack (FastAPI + Spring Boot)

Dự án này là demo hệ thống observability đầy đủ gồm metrics, logs, traces cho 2 service mẫu (FastAPI và Spring Boot). Stack chính: Prometheus, Grafana, Loki, Tempo, Alertmanager, Nginx, Alloy.

## Mục tiêu
- Thu thập metrics từ 2 app demo.
- Thu thập logs từ container qua Docker socket.
- Thu thập traces qua OpenTelemetry (OTLP).
- Hiển thị tập trung trên Grafana.
- Tạo alert từ Prometheus và gửi qua Alertmanager.
- Có sẵn script load test.

## Thành phần và cổng
- Nginx proxy: 8080
- FastAPI app: 8000
- Spring Boot app: 8083 (app), 8081 (metrics internal)
- Grafana: 3001 (user/pass: admin/admin)
- Prometheus: 9090
- Alertmanager: 9093
- Loki: 3100
- Tempo: 3200
- Node Exporter: 9100
- Alloy: 12345

## Hướng dẫn chạy
Từ thư mục gốc:
```bash
docker compose up -d --build
```

Kiểm tra:
```bash
docker compose ps
```

Dừng:
```bash
docker compose down
```

## Endpoint demo
Qua Nginx (để test trace propagation):
- FastAPI
  - http://localhost:8080/health
  - http://localhost:8080/api/data
  - http://localhost:8080/api/slow
- Spring Boot (prefix /api/java/)
  - http://localhost:8080/api/java/data
  - http://localhost:8080/api/java/slow

Truy cập trực tiếp (nếu cần):
- FastAPI: http://localhost:8000
- Spring Boot: http://localhost:8083

## Observability
- Grafana: http://localhost:3001
  - Datasource đã được provision sẵn (Prometheus, Loki, Tempo)
  - Dashboard load từ thư mục provision
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093
- Loki: http://localhost:3100
- Tempo: http://localhost:3200

## Đối chiếu yêu cầu
- Metrics CPU/memory: đạt (node-exporter + dashboard hệ thống).
- Request rate/response time/error rate: đạt cho FastAPI; Spring Boot dùng metrics khác, cần map thêm nếu muốn gộp chung.
- Log đa service: đạt (Alloy đọc log container, đẩy Loki).
- Trace xuyên reverse proxy → app → DB/API: chưa (chưa có downstream DB/API).
- Cảnh báo tự động ≥2: đạt (CPU, memory, latency, error rate, service down).
- Dashboard tổng hợp: tạm có 2 dashboard riêng (system/app), chưa có 1 dashboard gộp.

## Hạn chế kỹ thuật
- Correlation giữa log và metric còn hạn chế.
- Timestamp giữa các nguồn dữ liệu có thể lệch nhau.
- Volume log lớn gây tốn tài nguyên lưu trữ.
- Tracing làm tăng overhead xử lý.
- Thiếu dữ liệu downstream khiến khó debug end-to-end.

## Đánh giá/kiểm thử
- Tạo lỗi giả lập (endpoint `/api/error`) và quan sát dashboard + log để xác định nguyên nhân.
- Stress test bằng k6/Locust để quan sát bottleneck (CPU, latency, error rate).
- Đo overhead bằng cách chạy test ở 2 chế độ: bật/tắt tracing/logging, so sánh latency và CPU.
- MTTD giả lập: ghi thời điểm tạo lỗi và thời điểm alert xuất hiện.
- Chứng minh hỗ trợ debug: truy vết từ log → trace → metric.

## Cấu hình liên quan
- Docker Compose: [docker-compose.yml](docker-compose.yml)
- Prometheus scrape + rules: [prometheus/prometheus.yml](prometheus/prometheus.yml), [prometheus/alerts.yml](prometheus/alerts.yml)
- Grafana provisioning: [grafana/datasources/datasources.yml](grafana/datasources/datasources.yml), [grafana/dashboards/dashboards.yml](grafana/dashboards/dashboards.yml)
- Loki: [loki/loki-config.yml](loki/loki-config.yml)
- Tempo: [tempo/tempo-config.yml](tempo/tempo-config.yml)
- Alertmanager: [alertmanager/alertmanager.yml](alertmanager/alertmanager.yml)
- Nginx: [nginx/nginx.conf](nginx/nginx.conf)
- Alloy (logs): [alloy/config.alloy](alloy/config.alloy)

## Load test
### k6
Mặc định script dùng BASE_URL = http://localhost:80, nên cần set về 8080.

PowerShell:
```powershell
$env:BASE_URL="http://localhost:8080"
k6 run .\test-scripts\k6-load-test.js
k6 run .\test-scripts\k6-stress-test.js
```

Kết quả summary sẽ ghi vào [results/load-test-summary.json](results/load-test-summary.json).

### Locust
```powershell
locust -f .\test-scripts\locustfile.py --host http://localhost:8080
```
Mở UI: http://localhost:8089

## Lưu ý
- Windows + Docker Desktop: Alloy cần đọc Docker socket để lấy log container.
- Spring Boot metrics mở ở port 8081 (internal trong Docker). Prometheus scrape trên service name.
- Alertmanager mặc định chưa có thông tin email/slack thật. Cần thay đổi [alertmanager/alertmanager.yml](alertmanager/alertmanager.yml) nếu muốn gửi thật.

## Troubleshooting nhanh
- Nếu không vào được Grafana: kiểm tra port 3001 bị chiếm không
- Nếu metrics không có: kiểm tra endpoint /metrics (FastAPI) và /actuator/prometheus (Spring Boot)
- Nếu log không lên Loki: kiểm tra Docker socket và Alloy
- Nếu trace không lên Tempo: kiểm tra OTEL_* env trong [docker-compose.yml](docker-compose.yml)
