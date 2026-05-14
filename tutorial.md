# Noi dung trinh bay Demo - Observability Dashboard

---

## Gioi thieu he thong (noi truoc khi vao demo)

"Em xay dung mot he thong Observability hoan chinh, tuc la kha nang quan sat va hieu duoc
trang thai ben trong cua he thong chi dua vao output cua no — ma khong can phai SSH vao
server hay doc log thu cong.

He thong gom 3 thanh phan cot loi duoc goi la 3 pillars of observability:
- Metrics  — Prometheus thu thap so lieu CPU, RAM, request rate, error rate
- Logs     — Loki tong hop log tu tat ca service, co the tim kiem va loc
- Traces   — Tempo luu distributed traces, cho thay 1 request di qua nhung dau

Va Grafana la noi hien thi tat ca 3 thu do tren cung 1 dashboard.

Toan bo chay bang Docker Compose, bao gom 2 demo app: FastAPI viet bang Python va
Spring Boot viet bang Java — dai dien cho moi truong da ngon ngu thuc te."

---

## Demo 1 — Luong du lieu binh thuong

### Khi mo Prometheus → Status → Targets

"Day la trang Targets cua Prometheus. Em thay 5 service dang duoc scrape va tat ca deu
UP — mau xanh la. Prometheus cu 15 giay lai keo metrics tu cac endpoint nay 1 lan. Neu
co service nao DOWN thi se doi mau do ngay."

### Khi mo Grafana → Observability Overview

"Day la dashboard tong hop. Hang dau tien la 4 panel Service Health — 4 service deu UP,
nen xanh. Day la cai nhin nhanh nhat: chi can nhin vao day la biet ngay toan bo he thong
dang on hay khong.

Xuong hang 2 la 2 dong ho gauge — CPU dang dung bao nhieu phan tram, Memory dang dung
bao nhieu. Hien tai he thong nhan nen kim o vung xanh.

Hang 3 la Request Rate — so request moi giay dang den he thong. Vua roi em gui 20 request
nen duong bieu do co nhich len.

Hang cuoi la Logs — o day Grafana ket noi thang toi Loki va hien thi log tu tat ca service
ngay tren dashboard, khong can mo tab khac."

### Khi mo Explore → Tempo

"Trong Explore, em chon datasource Tempo va tim theo service name 'fastapi-demo'. Thay
danh sach trace — moi trace tuong ung voi 1 request. O day quan trong la cot Spans = 6
— tuc la 1 request tao ra 6 span, bao gom ca span HTTP va span Redis ma em se noi ro hon
o Demo 4."

---

## Demo 2 — Gia lap loi & Root Cause Analysis

### Khi bat dau gui loi

"Em dang gia lap 1 tinh huong thuc te: co code moi deploy bi loi, lien tuc tra ve HTTP 500.
Em gui 1 request loi moi giay trong 2.5 phut. Dieu quan trong la phai gui lien tuc — vi
Prometheus tinh rate() theo toc do tang cua counter, neu dung thi rate ve 0 ngay va alert
se khong bao gio fire."

### Khi nhin vao Grafana Error Rate panel

"Nhin vao panel Error Rate — duong bieu do vua nhay tu 10% len gan 50%. Trong thuc te
con so nay binh thuong phai gan 0%, khi no tang dot bien nhu vay la dau hieu ro rang co
su co."

### Khi mo Prometheus → Alerts sau 30 giay

"Bay gio mo Prometheus trang Alerts. Thay HighErrorRate dang pending — mau vang. Pending
co nghia la dieu kien da thoa man nhung chua du thoi gian — alert rule em cau hinh la
'for: 2m', tuc la phai duy tri loi 2 phut lien tuc moi fire, de tranh false alarm."

### Khi alert chuyen firing

"Sau dung 2 phut tu luc bat dau — alert chuyen sang firing, mau do. Day chinh la MTTD —
Mean Time To Detect — khoang 2 phut. Neu khong co monitoring thi phai cho user bao, co
the mat 30 phut hoac hon."

### Khi mo Alertmanager

"Mo Alertmanager — day la noi nhan alert tu Prometheus va dinh tuyen di. Trong production
thuc te, tu day co the gui email, Slack, PagerDuty... Hien tai em thay HighErrorRate dang
active voi timestamp ro rang."

### Khi mo Explore → Loki

"Bay gio em debug. Mo Explore Loki, query cac log co chua 'error'. Em thay cac dong log
mau do: ERROR fastapi-demo trace_id=5f3290ab... forced error endpoint called. Chu y truong
trace_id — day la mau chot de ket noi log voi trace."

### Khi click View Trace

"Em click vao log entry, expand ra, thay truong trace_id, va click nut Tempo ben canh.
Tempo tu dong mo dung trace cua request do — thay span 'GET /api/error' voi HTTP 500.
Toan bo luong debug: alert → log → trace chi mat khoang 30 giay."

---

## Demo 3 — Stress Test & Bottleneck

### Khi bat dau chay k6

"Em dung k6 — cong cu load testing — de tao tai tang dan: tu 10 user len 50 roi 100 user
dong thoi, trong 2.5 phut. Trong khi k6 dang chay, em mo Grafana de quan sat real-time."

### Khi nhin Request Rate tang

"Nhin panel Request Rate — duong bieu do dang leo dan tu 1 len khoang 8–10 req/s theo
dung giai doan ramp-up cua k6. He thong dang nhan tai tang dan."

### Khi nhin Response Time

"Panel Response Time quan trong nhat. Ba duong P50, P95, P99 — P99 dang leo kha cao, vuot
1000ms. Day la dau hieu bottleneck. Cau hoi la: endpoint nao dang cham?"

### Khi mo Prometheus → Graph

"Vao Prometheus, dan query PromQL nay vao: histogram_quantile(0.99,...). Ket qua hien ngay:
/api/slow co P99 khoang 1500–2000ms — day la bottleneck ro rang, trong khi /api/data chi
100–200ms va /health gan nhu 0. Prometheus cho phep em dinh luong duoc bottleneck chu
khong phai doan mo."

### Khi k6 ket thuc

"k6 in ra bang ket qua. Nhin vao 2 chi so quan trong: p(99) cua http_req_duration va
http_req_failed rate. Neu p(99) vuot 500ms hoac failed rate vuot 5% thi threshold fail —
dau x mau do. Day la bang chung khach quan he thong co chiu duoc tai hay khong."

---

## Demo 4 — Distributed Trace: Nginx → FastAPI → Redis

### Khi gioi thieu

"Demo nay em muon chung minh rang trace khong chi dung o tang HTTP — no di xuyen qua toan
bo duong di cua request, ke ca xuong database."

### Khi mo trinh duyet F12

"Goi request qua Nginx proxy — port 8080. Mo F12, tab Network, nhin vao Response Headers
— thay X-Request-ID. Header nay duoc Nginx tu dong sinh ra va gan vao moi request. Bay
gio goi thang FastAPI port 8000 — khong co X-Request-ID. Dieu nay chung minh Nginx dang
dung o giua lam nhiem vu proxy."

### Khi mo Tempo trace view

"Vao Grafana Explore, chon Tempo, search service 'fastapi-demo', endpoint 'GET /api/data'.
Click vao 1 trace — thay waterfall chart. Nhin vao cau truc:

  - Span ngoai cung: GET /api/data — day la HTTP span, FastAPI xu ly request
  - Ben trong co 2 span con: INCRBY va GET — day la Redis spans

Hover vao span Redis — thay attribute db.system = redis, db.statement = INCRBY ? ?. Day
la bang chung trace di xuyen tu App xuong DB."

### Khi mo Explore Loki va click View Trace

"Bay gio em demo log-to-trace correlation. Trong Explore Loki, query log cua fastapi-demo.
Moi dong log deu co trace_id. Em click expand dong log — thay truong trace_id — click nut
Tempo ben canh — Tempo tu nhay sang dung trace do. Day la tinh nang correlation: tu log
tim duoc trace tuong ung trong chua den 2 giay."

---

## Demo 5 — 5 Alert Rules tu dong

### Khi mo Prometheus → Alerts

"He thong em co 5 alert rules. Nhin vao trang nay — binh thuong tat ca deu inactive, mau
xam. 5 alert bao phu cac su co thuong gap nhat: CPU qua cao, Memory qua cao, Latency tang
bat thuong, Error rate tang, va Service down."

### Khi demo ServiceDown

"Em tat fastapi-demo: docker compose stop fastapi-demo. Bay gio refresh Prometheus sau 15
giay — thay ServiceDown chuyen pending, mau vang. Sau 1 phut — chuyen firing, mau do,
kem thong bao 'Service fastapi-demo is down'. Alertmanager nhan duoc ngay lap tuc.

Thoi gian phat hien: duoi 75 giay — nhanh hon rat nhieu so voi cho user bao."

### Khi khoi phuc

"Chay lai: docker compose start fastapi-demo. Sau 1–2 phut alert tu giai quyet — bien mat
khoi Alertmanager. He thong tu healing khong can can thiep thu cong."

### Khi demo HighRequestLatency

"Alert thu 3 la Latency cao. Em gui nhieu request den /api/slow dong thoi — endpoint nay
random tu 0.5–2 giay. P99 vuot 1 giay → alert firing. Dieu nay co nghia la: neu trong
production co code cham dot ngot, he thong se tu phat hien va bao dong ma khong can ai
ngoi canh."

---

## Demo 6 — Do overhead cua OpenTelemetry

### Khi gioi thieu

"Mot cau hoi thuc te khi trien khai observability la: no co lam cham he thong khong? Tracing
middleware phai tao span, dong goi du lieu, gui qua mang den Tempo — tat ca deu ton thoi
gian. Demo nay do xem overhead do la bao nhieu."

### Khi chay script

"Em chay script do overhead. Script nay spin up 1 container thu 2 voi OTEL_ENABLED=false
— tuc la cung code, cung image, nhung khong co bat ky OpenTelemetry nao. Sau do do 50
request voi OTel ON va 50 request voi OTel OFF roi so sanh."

### Khi doc ket qua

"Ket qua: OTel ON avg khoang 95ms, OTel OFF avg khoang 91ms — overhead khoang 4ms hay ~4%.
Con so nay chap nhan duoc hoan toan, dac biet khi endpoint co business logic 50–200ms thi
4ms overhead chi chiem chua den 5%.

Cung xac nhan qua Prometheus: endpoint /health — khong co business logic — co P50 chi 2ms.
Do la overhead thuan cua OTel. So voi /api/data P50 la 90ms thi overhead la 2.2% — khong
dang ke."

### Ket luan overhead

"Ket luan: OpenTelemetry them ~2–5ms moi request. Voi he thong co latency tu nhien tu 50ms
tro len, overhead duoi 5% la hoan toan chap nhan duoc va khong anh huong den trai nghiem
nguoi dung."

---

## Ket luan chung (noi cuoi cung)

"Tong ket lai, em da xay dung va chung minh hoat dong cua he thong observability voi day
du 3 pillar:

  - Metrics : CPU, RAM, request rate, error rate — thu thap tu dong qua Prometheus
  - Logs    : tu FastAPI va Spring Boot — tong hop qua Alloy vao Loki, co trace_id de
              correlation
  - Traces  : end-to-end tu Nginx → FastAPI → Redis — thay duoc duong di request xuyen
              qua tung tang

Khi co su co: alert tu firing trong 1–2 phut, tu alert tim log, tu log nhay sang trace —
debug chi mat 30 giay thay vi phai grep log thu cong.

Overhead cua tracing la ~4% — chap nhan duoc cho production.

Day la nen tang de trong production thuc te, team co the giam MTTD tu hang chuc phut xuong
con duoi 2 phut."
