# Nội dung trình bày Demo - Observability Dashboard

---

## Giới thiệu hệ thống (nói trước khi vào demo)
"Em xây dựng một hệ thống Observability hoàn chỉnh, tức là khả năng quan sát và hiểu được trạng thái bên trong của hệ thống chỉ dựa vào output của nó — mà không cần phải SSH vào server hay đọc log thủ công.

Hệ thống gồm 3 thành phần cốt lõi được gọi là 3 pillars of observability:
- Metrics  — Prometheus thu thập số liệu CPU, RAM, request rate, error rate.
- Logs     — Loki tổng hợp log từ tất cả service, có thể tìm kiếm và lọc.
- Traces   — Tempo lưu distributed traces, cho thấy 1 request đi qua những đâu.

Và Grafana là nơi hiển thị tất cả 3 thứ đó trên cùng 1 dashboard.

Toàn bộ chạy bằng Docker Compose, bao gồm 2 demo app: FastAPI viết bằng Python và
Spring Boot viết bằng Java — đại diện cho môi trường đa ngôn ngữ thực tế."

---

## Demo 1 — Luồng dữ liệu bình thường

### Khi mở Prometheus → Status → Targets

"Đây là trang Targets của Prometheus. Em thấy 5 service đang được scrape và tất cả đều
UP — màu xanh lá. Prometheus cứ 15 giây lại kéo metrics từ các endpoint này 1 lần. Nếu
có service nào DOWN thì sẽ đổi màu đỏ ngay."

### Khi mở Grafana → Observability Overview

"Đây là dashboard tổng hợp. Hàng đầu tiên là 4 panel Service Health — 4 service đều UP,
nên xanh. Đây là cái nhìn nhanh nhất: chỉ cần nhìn vào đây là biết ngay toàn bộ hệ thống
đang ổn hay không.

Xuống hàng 2 là 2 đồng hồ gauge — CPU đang dùng bao nhiêu phần trăm, Memory đang dùng
bao nhiêu. Hiện tại hệ thống nhàn nên kim ở vùng xanh.

Hàng 3 là Request Rate — số request mỗi giây đang đến hệ thống. Vừa rồi em gửi 20 request
nên đường biểu đồ có nhích lên.

Hàng cuối là Logs — ở đây Grafana kết nối thẳng tới Loki và hiển thị log từ tất cả service
ngay trên dashboard, không cần mở tab khác."

### Khi mở Explore → Tempo

"Trong Explore, em chọn datasource Tempo và tìm theo service name 'fastapi-demo'. Thấy
danh sách trace — mỗi trace tương ứng với 1 request. Ở đây quan trọng là cột Spans = 6
— tức là 1 request tạo ra 6 span, bao gồm cả span HTTP và span Redis mà em sẽ nói rõ hơn
ở Demo 4."

---

## Demo 2 — Giả lập lỗi & Root Cause Analysis

### Khi bắt đầu gửi lỗi

"Em đang giả lập 1 tình huống thực tế: có code mới deploy bị lỗi, liên tục trả về HTTP 500.
Em gửi 1 request lỗi mỗi giây trong 2.5 phút. Điều quan trọng là phải gửi liên tục — vì
Prometheus tính rate() theo tốc độ tăng của counter, nếu dừng thì rate về 0 ngay và alert
sẽ không bao giờ fire."

### Khi nhìn vào Grafana Error Rate panel

"Nhìn vào panel Error Rate — đường biểu đồ vừa nhảy từ 10% lên gần 50%. Trong thực tế
con số này bình thường phải gần 0%, khi nó tăng đột biến như vậy là dấu hiệu rõ ràng có
sự cố."

### Khi mở Prometheus → Alerts sau 30 giây

"Bây giờ mở Prometheus trang Alerts. Thấy HighErrorRate đang pending — màu vàng. Pending
có nghĩa là điều kiện đã thỏa mãn nhưng chưa đủ thời gian — alert rule em cấu hình là
'for: 2m', tức là phải duy trì lỗi 2 phút liên tục mới fire, để tránh false alarm."

### Khi alert chuyển firing

"Sau đúng 2 phút từ lúc bắt đầu — alert chuyển sang firing, màu đỏ. Đây chính là MTTD —
Mean Time To Detect — khoảng 2 phút. Nếu không có monitoring thì phải chờ user báo, có
thể mất 30 phút hoặc hơn."

### Khi mở Alertmanager

"Mở Alertmanager — đây là nơi nhận alert từ Prometheus và định tuyến đi. Trong production
thực tế, từ đây có thể gửi email, Slack, PagerDuty... Hiện tại em thấy HighErrorRate đang
active với timestamp rõ ràng."

### Khi mở Explore → Loki

"Bây giờ em debug. Mở Explore Loki, query các log có chứa 'error'. Em thấy các dòng log
màu đỏ: ERROR fastapi-demo trace_id=5f3290ab... forced error endpoint called. Chú ý trường
trace_id — đây là mấu chốt để kết nối log với trace."

### Khi click View Trace

"Em click vào log entry, expand ra, thấy trường trace_id, và click nút Tempo bên cạnh.
Tempo tự động mở đúng trace của request đó — thấy span 'GET /api/error' với HTTP 500.
Toàn bộ luồng debug: alert → log → trace chỉ mất khoảng 30 giây."

---

## Demo 3 — Stress Test & Bottleneck

### Khi bắt đầu chạy k6

"Em dùng k6 — công cụ load testing — để tạo tải tăng dần: từ 10 user lên 50 rồi 100 user
đồng thời, trong 2.5 phút. Trong khi k6 đang chạy, em mở Grafana để quan sát real-time."

### Khi nhìn Request Rate tăng

"Nhìn panel Request Rate — đường biểu đồ đang leo dần từ 1 lên khoảng 8–10 req/s theo
đúng giai đoạn ramp-up của k6. Hệ thống đang nhận tải tăng dần."

### Khi nhìn Response Time

"Panel Response Time quan trọng nhất. Ba đường P50, P95, P99 — P99 đang leo khá cao, vượt
1000ms. Đây là dấu hiệu bottleneck. Câu hỏi là: endpoint nào đang chậm?"

### Khi mở Prometheus → Graph

"Vào Prometheus, dán query PromQL này vào: histogram_quantile(0.99,...). Kết quả hiện ngay:
/api/slow có P99 khoảng 1500–2000ms — đây là bottleneck rõ ràng, trong khi /api/data chỉ
100–200ms và /health gần như 0. Prometheus cho phép em định lượng được bottleneck chứ
không phải đoán mò."

### Khi k6 kết thúc

"k6 in ra bảng kết quả. Nhìn vào 2 chỉ số quan trọng: p(99) của http_req_duration và
http_req_failed rate. Nếu p(99) vượt 500ms hoặc failed rate vượt 5% thì threshold fail —
đánh dấu màu đỏ. Đây là bằng chứng khách quan hệ thống có chịu được tải hay không."

---

## Demo 4 — Distributed Trace: Nginx → FastAPI → Redis

### Khi giới thiệu

"Demo này em muốn chứng minh rằng trace không chỉ dừng ở tầng HTTP — nó đi xuyên qua toàn
bộ đường đi của request, kể cả xuống database."

### Khi mở trình duyệt F12

"Gọi request qua Nginx proxy — port 8080. Mở F12, tab Network, nhìn vào Response Headers
— thấy X-Request-ID. Header này được Nginx tự động sinh ra và gán vào mỗi request. Bây
giờ gọi thẳng FastAPI port 8000 — không có X-Request-ID. Điều này chứng minh Nginx đang
đứng ở giữa làm nhiệm vụ proxy."

### Khi mở Tempo trace view

"Vào Grafana Explore, chọn Tempo, search service 'fastapi-demo', endpoint 'GET /api/data'.
Click vào 1 trace — thấy waterfall chart. Nhìn vào cấu trúc:

  - Span ngoài cùng: GET /api/data — đây là HTTP span, FastAPI xử lý request
  - Bên trong có 2 span con: INCRBY và GET — đây là Redis spans

Hover vào span Redis — thấy attribute db.system = redis, db.statement = INCRBY ? ?. Đây
là bằng chứng trace đi xuyên từ App xuống DB."

### Khi mở Explore Loki và click View Trace

"Bây giờ em demo log-to-trace correlation. Trong Explore Loki, query log của fastapi-demo.
Mỗi dòng log đều có trace_id. Em click expand dòng log — thấy trường trace_id — click nút
Tempo bên cạnh — Tempo tự nhảy sang đúng trace đó. Đây là tính năng correlation: từ log
tìm được trace tương ứng trong chưa đến 2 giây."

---

## Demo 5 — 5 Alert Rules tự động

### Khi mở Prometheus → Alerts

"Hệ thống em có 5 alert rules. Nhìn vào trang này — bình thường tất cả đều inactive, màu
xám. 5 alert bao phủ các sự cố thường gặp nhất: CPU quá cao, Memory quá cao, Latency tăng
bất thường, Error rate tăng, và Service down."

### Khi demo ServiceDown

"Em tắt fastapi-demo: docker compose stop fastapi-demo. Bây giờ refresh Prometheus sau 15
giây — thấy ServiceDown chuyển pending, màu vàng. Sau 1 phút — chuyển firing, màu đỏ,
kèm thông báo 'Service fastapi-demo is down'. Alertmanager nhận được ngay lập tức.

Thời gian phát hiện: dưới 75 giây — nhanh hơn rất nhiều so với chờ user báo."

### Khi khôi phục

"Chạy lại: docker compose start fastapi-demo. Sau 1–2 phút alert tự giải quyết — biến mất
khỏi Alertmanager. Hệ thống tự healing không cần can thiệp thủ công."

### Khi demo HighRequestLatency

"Alert thứ 3 là Latency cao. Em gửi nhiều request đến /api/slow đồng thời — endpoint này
random từ 0.5–2 giây. P99 vượt 1 giây → alert firing. Điều này có nghĩa là: nếu trong
production có code chậm đột ngột, hệ thống sẽ tự phát hiện và báo động mà không cần ai
ngồi canh."

---

## Demo 6 — Đo overhead của OpenTelemetry

### Khi giới thiệu

"Một câu hỏi thực tế khi triển khai observability là: nó có làm chậm hệ thống không? Tracing
middleware phải tạo span, đóng gói dữ liệu, gửi qua mạng đến Tempo — tất cả đều tốn thời
gian. Demo này đo xem overhead đó là bao nhiêu."

### Khi chạy script

"Em chạy script đo overhead. Script này spin up 1 container thứ 2 với OTEL_ENABLED=false
— tức là cùng code, cùng image, nhưng không có bất kỳ OpenTelemetry nào. Sau đó đo 50
request với OTel ON và 50 request với OTel OFF rồi so sánh."

### Khi đọc kết quả

"Kết quả: OTel ON avg khoảng 95ms, OTel OFF avg khoảng 91ms — overhead khoảng 4ms hay ~4%.
Con số này chấp nhận được hoàn toàn, đặc biệt khi endpoint có business logic 50–200ms thì
4ms overhead chỉ chiếm chưa đến 5%.

Cũng xác nhận qua Prometheus: endpoint /health — không có business logic — có P50 chỉ 2ms.
Đó là overhead thuần của OTel. So với /api/data P50 là 90ms thì overhead là 2.2% — không
đáng kể."

### Kết luận overhead

"Kết luận: OpenTelemetry thêm ~2–5ms mỗi request. Với hệ thống có latency tự nhiên từ 50ms
trở lên, overhead dưới 5% là hoàn toàn chấp nhận được và không ảnh hưởng đến trải nghiệm
người dùng."

---

## Kết luận chung (nói cuối cùng)

"Tổng kết lại, em đã xây dựng và chứng minh hoạt động của hệ thống observability với đầy
đủ 3 pillar:

  - Metrics : CPU, RAM, request rate, error rate — thu thập tự động qua Prometheus
  - Logs    : từ FastAPI và Spring Boot — tổng hợp qua Alloy vào Loki, có trace_id để
              correlation
  - Traces  : end-to-end từ Nginx → FastAPI → Redis — thấy được đường đi request xuyên
              qua từng tầng

Khi có sự cố: alert tự firing trong 1–2 phút, từ alert tìm log, từ log nhảy sang trace —
debug chỉ mất 30 giây thay vì phải grep log thủ công.

Overhead của tracing là ~4% — chấp nhận được cho production.

Đây là nền tảng để trong production thực tế, team có thể giảm MTTD từ hàng chục phút xuống
còn dưới 2 phút."
