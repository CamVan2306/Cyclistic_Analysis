# SV3 – UI Mockup & State Machine & Business Rules
**Đề tài 26: Dàn phun sương làm mát sân vườn | Nhóm 05 | Tuần 3**
**Phụ trách:** SV3 – UI/Dashboard & Flow Designer

---

## 1. State Machine Sơ Bộ

### 1.1 Tổng quan – 3 chiều trạng thái song song

Hệ thống GardenMist có **3 nhóm trạng thái hoạt động độc lập** (orthogonal state machines):

| Chiều | Trạng thái | Chuyển đổi |
|---|---|---|
| **MODE** | `AUTO` ↔ `MANUAL` | CMD qua MQTT |
| **CONNECTION** | `ONLINE` ↔ `OFFLINE` | WiFi/MQTT kết nối/mất |
| **PUMP/RELAY** | `PUMP ON` ↔ `PUMP OFF` | Logic tự động + CMD |

### 1.2 Sơ đồ – Chiều 1: MODE

```
        ┌─────────────────────────────────────────────────────────┐
        │                    MODE STATE                            │
        │                                                         │
        │   ┌─────────────┐   CMD: {action:'on'}/{action:'off'}  │
        │   │             │ ────────────────────────────────────► │
        │   │    AUTO     │                        ┌──────────────┤
        │   │  (mặc định) │ ◄──────────────────── │    MANUAL    │
        │   │             │   CMD: {action:'auto'} │              │
        │   └─────────────┘                        └──────────────┘
        │                                                         │
        └─────────────────────────────────────────────────────────┘
```

**Điều kiện:**
- Khởi động → `AUTO` (mặc định trong firmware)
- `AUTO` → `MANUAL`: nhận CMD `{"action":"on"}` hoặc `{"action":"off"}`
- `MANUAL` → `AUTO`: nhận CMD `{"action":"auto"}`

### 1.3 Sơ đồ – Chiều 2: CONNECTION

```
        ┌─────────────────────────────────────────────────────────┐
        │                 CONNECTION STATE                         │
        │                                                         │
        │            BootUp                                       │
        │   [●]───────────►  ┌───────────┐                       │
        │                    │  OFFLINE  │ ◄─── WiFi/MQTT lost   │
        │                    └─────┬─────┘      LWT published     │
        │                          │                              │
        │          WiFi+MQTT reconnect OK                         │
        │          → publish {status:'online'} retained           │
        │                          │                              │
        │                    ┌─────▼─────┐                       │
        │                    │  ONLINE   │ ────► WiFi/MQTT lost   │
        │                    └───────────┘                        │
        └─────────────────────────────────────────────────────────┘
```

**Cơ chế:**

| Sự kiện | Hành động firmware | Hành động broker |
|---|---|---|
| WiFi mất | `wifiWasConnected=false`, gọi `WiFi.begin()` mỗi 10s | – |
| MQTT mất | Gọi `reconnectMQTT()` mỗi 5s | Publish LWT: `{status:"offline"}` retained |
| MQTT kết nối lại | Subscribe `cmd`, publish `{status:"online"}` retained | Ghi đè LWT → Dashboard hiện ONLINE |

### 1.4 Sơ đồ – Chiều 3: PUMP/RELAY

```
  ┌───────────────────────────────────────────────────────────────────┐
  │                        PUMP STATE                                  │
  │                                                                    │
  │   ┌─────────────┐                           ┌─────────────┐       │
  │   │  PUMP OFF   │ ──── AUTO: T>32 & !rain ► │   PUMP ON   │       │
  │   │             │ ◄─── AUTO: T<=30 or rain ─ │             │       │
  │   │             │ ──── MANUAL: CMD on      ► │             │       │
  │   │             │ ◄─── MANUAL: CMD off ────  │             │       │
  │   └─────────────┘                           └─────────────┘       │
  │                                                                    │
  │  Hysteresis zone (30 < T <= 32): GIỮ NGUYÊN trạng thái hiện tại  │
  │  Rain = ưu tiên cao nhất, tắt bơm ngay dù mode nào                │
  └───────────────────────────────────────────────────────────────────┘
```

### 1.5 Bảng tổng hợp điều kiện chuyển trạng thái

| Từ | Sang | Trigger | Guard / Điều kiện | Action |
|---|---|---|---|---|
| AUTO | MANUAL | MQTT CMD | `action == "on"` hoặc `"off"` | Set `currentMode=MANUAL` |
| MANUAL | AUTO | MQTT CMD | `action == "auto"` | Set `currentMode=AUTO` |
| ONLINE | OFFLINE | Keep-alive timeout | WiFi mất hoặc MQTT ngắt >30s | Broker publish LWT retained |
| OFFLINE | ONLINE | WiFi reconnect | `WiFi.status()==WL_CONNECTED` AND MQTT connect OK | Publish `{status:"online"}` retained |
| PUMP OFF | PUMP ON | Sensor cycle (1s) | `mode==AUTO` AND `temp>32` AND `!raining` | `digitalWrite(RELAY_PIN, HIGH)` |
| PUMP ON | PUMP OFF | Sensor cycle (1s) | `mode==AUTO` AND `(temp<=30 OR raining)` | `digitalWrite(RELAY_PIN, LOW)` |
| PUMP OFF | PUMP ON | MQTT CMD | `mode==MANUAL` AND `action=="on"` | `relayState=true`, `digitalWrite HIGH` |
| PUMP ON | PUMP OFF | MQTT CMD | `mode==MANUAL` AND `action=="off"` | `relayState=false`, `digitalWrite LOW` |

---

## 2. Rà Soát UI Mockup – Cập Nhật Theo Payload Thật

### 2.1 Payload thực tế từ firmware (Tuần 3)

```json
{
  "device":     "GardenMist-ABCD1234",
  "status":     "online",
  "temp":       34.00,
  "humidity":   65.50,
  "isRaining":  false,
  "relayState": "BAT",
  "mode":       "AUTO",
  "sensorOk":   true,
  "uptime":     12345
}
```

### 2.2 Bảng mapping: Payload field → UI widget

| Field payload | Kiểu | Widget UI | Ghi chú hiển thị |
|---|---|---|---|
| `status` | `"online"/"offline"` | **Badge màu** trên header | 🟢 ONLINE / 🔴 OFFLINE |
| `device` | string | Sub-title nhỏ dưới tên app | `GardenMist-ABCD1234` |
| `temp` | float °C | Số lớn màu cam | `34.0°C` |
| `humidity` | float % | Số lớn màu xanh | `65.5%` |
| `isRaining` | bool | Pill badge | 🌧️ CÓ MƯA (đỏ) / KHÔNG MƯA (xanh) |
| `relayState` | `"BAT"/"TAT"` | Pill badge lớn | ● BẬT (xanh) / ● TẮT (xám) |
| `mode` | `"AUTO"/"MANUAL"` | Toggle button 2 vị trí | Tab sáng = đang active |
| `sensorOk` | bool | Nhãn nhỏ dưới nhiệt độ | ✅ Cảm biến OK / ⚠️ Dùng giá trị cũ |
| `uptime` | int ms | Đổi sang h:m:s | `3h 25m 45s` |

### 2.3 Các thay đổi so với mockup Tuần 2

| Thay đổi | Lý do |
|---|---|
| ✅ Thêm badge **ONLINE/OFFLINE** trên header | Payload có `status` field + LWT |
| ✅ Thêm widget **MODE (AUTO/MANUAL)** | Firmware có `currentMode`, payload có `mode` |
| ✅ Thêm **Device ID** trên UI | `device` field trong payload – nhận dạng board |
| ✅ Thêm nhãn **sensorOk** cạnh nhiệt độ | Cảnh báo khi DHT22 lỗi, dùng giá trị cũ |
| ✅ **Uptime** hiển thị dạng h:m:s | Dễ đọc hơn raw ms |
| ✅ 3 nút điều khiển **BẬT / TẮT / AUTO** | Tương ứng 3 CMD publish lên `garden/mist/cmd` |

### 2.4 Luồng dữ liệu UI

```
ESP32 Firmware
    │
    ▼ publish mỗi 1s
MQTT Broker (broker.emqx.io)
    │
    ├── garden/mist/status ──────────────────► Dashboard Widget Update
    │     {temp, humidity, mode,               (real-time live data)
    │      relayState, status, ...}
    │
    └── [LWT] garden/mist/status ────────────► Badge OFFLINE (tự động)
          {status:"offline"}                   khi ESP mất kết nối

Dashboard Buttons
    │
    ▼ publish khi nhấn
    garden/mist/cmd
    {action:"on"|"off"|"auto"} ─────────────► ESP32 mqttCallback()
                                               → updateRelayState()
```

---

## 3. Business Rules Tuần 5 – Dạng Node-RED

> Format: **TRIGGER → CONDITION → ACTION**
> Sẵn sàng đưa vào flow Node-RED tuần 5

### Rule R1 – Tự động bật bơm khi nóng

| Mục | Nội dung |
|---|---|
| **ID** | R1 |
| **Tên** | Auto pump ON - Hot weather |
| **Trigger** | MQTT In node nhận message từ `garden/mist/status` |
| **Condition** | `mode == "AUTO"` AND `temp > 32` AND `isRaining == false` |
| **Action** | Publish `{"action":"on"}` → `garden/mist/cmd` |
| **Node-RED nodes** | `mqtt in` → `function` → `mqtt out` |

```javascript
// Node-RED Function node – R1
if (msg.payload.mode === "AUTO" &&
    msg.payload.temp > 32 &&
    msg.payload.isRaining === false) {
    return { payload: JSON.stringify({ action: "on" }) };
}
return null;
```

### Rule R2 – Tự động tắt bơm khi đủ mát

| Mục | Nội dung |
|---|---|
| **ID** | R2 |
| **Tên** | Auto pump OFF - Cool enough |
| **Trigger** | MQTT In nhận `garden/mist/status` |
| **Condition** | `mode == "AUTO"` AND `temp <= 30` |
| **Action** | Publish `{"action":"auto"}` → `garden/mist/cmd` |

```javascript
// Node-RED Function node – R2
if (msg.payload.mode === "AUTO" &&
    msg.payload.temp <= 30) {
    return { payload: JSON.stringify({ action: "auto" }) };
}
return null;
```

### Rule R3 – Tắt bơm khi có mưa (ưu tiên cao nhất)

| Mục | Nội dung |
|---|---|
| **ID** | R3 |
| **Tên** | Rain override - Force pump OFF |
| **Trigger** | MQTT In nhận `garden/mist/status` |
| **Condition** | `isRaining == true` (bất kể mode) |
| **Action** | Publish `{"action":"off"}` → `garden/mist/cmd` |
| **Ưu tiên** | **CAO NHẤT** – ghi đè R1 và R2 |

```javascript
// Node-RED Function node – R3 (đặt TRƯỚC R1, R2)
if (msg.payload.isRaining === true) {
    return { payload: JSON.stringify({ action: "off" }) };
}
return null;
```

### Rule R4 – Cảnh báo cảm biến lỗi

| Mục | Nội dung |
|---|---|
| **ID** | R4 |
| **Tên** | Sensor error alert |
| **Trigger** | MQTT In nhận `garden/mist/status` |
| **Condition** | `sensorOk == false` |
| **Action** | Gửi thông báo cảnh báo lên dashboard / Telegram |

```javascript
// Node-RED Function node – R4
if (msg.payload.sensorOk === false) {
    return {
        payload: `⚠️ Cảm biến DHT22 lỗi! Device: ${msg.payload.device}. Đang dùng giá trị cũ.`,
        topic: "sensor_alert"
    };
}
return null;
```

### Rule R5 – Cảnh báo thiết bị offline

| Mục | Nội dung |
|---|---|
| **ID** | R5 |
| **Tên** | Device offline alert |
| **Trigger** | MQTT In nhận `garden/mist/status` (bao gồm LWT) |
| **Condition** | `status == "offline"` |
| **Action** | Dashboard hiển thị badge OFFLINE + gửi alert |

```javascript
// Node-RED Function node – R5
if (msg.payload.status === "offline") {
    return {
        payload: `🔴 THIẾT BỊ OFFLINE: ${msg.payload.device}`,
        topic: "offline_alert"
    };
}
return null;
```

### Rule R6 – Ghi log dữ liệu

| Mục | Nội dung |
|---|---|
| **ID** | R6 |
| **Tên** | Periodic data logging |
| **Trigger** | Mọi message từ `garden/mist/status` (1s/lần) |
| **Condition** | `status == "online"` |
| **Action** | Ghi vào InfluxDB / file CSV để vẽ biểu đồ lịch sử |

### 3.1 Flow Node-RED Tuần 5 – Topology đề xuất

```
[MQTT In: garden/mist/status]
        │
        ▼
  [JSON Parse]
        │
        ├──► [Function R5: offline?]      ──► [Notification / Alert]
        ├──► [Function R4: sensor error?] ──► [Alert Node]
        ├──► [Function R3: raining?]      ──► [MQTT Out: cmd]
        ├──► [Function R1: hot?]          ──► [MQTT Out: cmd]
        ├──► [Function R2: cool?]         ──► [MQTT Out: cmd]
        └──► [Function R6: log]           ──► [InfluxDB Out]

[Dashboard Buttons] ──► [MQTT Out: garden/mist/cmd]
[Dashboard Gauges]  ◄── [MQTT In → UI update nodes]
```

**Thứ tự ưu tiên rules:**
```
R3 (mưa) > R1 (nóng→bật) > R2 (mát→tắt) > giữ nguyên
```

---

## 4. Hỗ Trợ Nhóm

### 4.1 Review Bảng Test Case

| TC# | Kịch bản | Input | Expected Output | Priority |
|---|---|---|---|---|
| TC01 | Temp cao, không mưa, AUTO | T=33°C, rain=false, mode=AUTO | Relay=BẬT | P1 |
| TC02 | Temp thấp, không mưa, AUTO | T=29°C, rain=false, mode=AUTO | Relay=TẮT | P1 |
| TC03 | Vùng hysteresis, AUTO | T=31°C, rain=false, mode=AUTO | Relay giữ nguyên | P1 |
| TC04 | Có mưa, dù nóng, AUTO | T=35°C, rain=true, mode=AUTO | Relay=TẮT | **P0** |
| TC05 | CMD on → MANUAL | CMD `{action:"on"}` | mode=MANUAL, relay=BẬT | P1 |
| TC06 | CMD off → MANUAL | CMD `{action:"off"}` | mode=MANUAL, relay=TẮT | P1 |
| TC07 | CMD auto → về AUTO | CMD `{action:"auto"}` | mode=AUTO | P1 |
| TC08 | MANUAL mode, mưa | mode=MANUAL, rain=true | Relay giữ theo CMD, không tự tắt | P2 |
| TC09 | DHT22 đọc lỗi | Sensor error | `sensorOk=false`, dùng lastValidTemp | P1 |
| TC10 | WiFi mất kết nối | WiFi drop | MQTT ngắt, LWT publish "offline" | P1 |
| TC11 | WiFi kết nối lại | WiFi reconnect | Subscribe lại cmd, publish "online" retained | P1 |
| TC12 | Rain debounce | rain signal thay đổi <2s | `stableRaining` không đổi | P2 |
| TC13 | Payload đầy đủ | status publish | 9 fields: device/status/temp/hum/rain/relay/mode/sensorOk/uptime | P1 |
| TC14 | Device ID unique | ESP restart | deviceId = `GardenMist-XXXXXXXX` (MAC-based) | P2 |

> ⚠️ **Lỗi thường gặp khi viết test case:**
> - Quên test vùng hysteresis (30 < T ≤ 32): relay phải giữ nguyên
> - Quên test MANUAL mode bỏ qua rain/temp (relay theo CMD)
> - Thiếu test rain debounce (ổn định 2s mới chấp nhận)

### 4.2 Câu Hỏi Thuyết Trình Chéo – Phần Firmware

**Q1: Tại sao cần hysteresis (32°C bật, 30°C tắt)?**
> Nếu cùng 1 ngưỡng, relay đóng/ngắt liên tục (chattering) khi nhiệt dao động quanh ngưỡng → hỏng bơm, hỏng relay. Hysteresis 2°C tạo vùng "chết": khi đã bật phải xuống 30°C mới tắt.

**Q2: Tại sao dùng `INPUT_PULLUP` cho cảm biến mưa?**
> Không có điện trở ngoài → GPIO floating → đọc ngẫu nhiên. `INPUT_PULLUP` kéo lên 3.3V (không mưa). Khi cảm biến nối xuống GND → LOW (có mưa). Logic đảo: `LOW = CÓ MƯA`.

**Q3: Tại sao rain cần debounce 2 giây?**
> Cảm biến có thể tạo nhiễu khi tiếp xúc giọt nước đầu tiên. Debounce 2s đảm bảo chỉ chấp nhận trạng thái mưa khi tín hiệu ổn định liên tục ≥ 2s – tránh tắt bơm nhầm.

**Q4: Non-blocking reconnect nghĩa là gì?**
> `delay()` blocking dừng `loop()` – firmware không đọc sensor, bỏ sót CMD. Non-blocking dùng `millis()` kiểm tra đã đủ 5s chưa mà không dừng loop – relay vẫn hoạt động đúng khi mạng mất.

**Q5: LWT hoạt động như thế nào?**
> Khi kết nối, ESP32 gửi "di chúc" cho broker: *"Nếu tôi mất kết nối đột ngột, hãy publish message này."* Khi keepAlive (30s) timeout → broker tự publish `{status:"offline"}` retained → dashboard tự hiển thị OFFLINE.

**Q6: `relayState` trong MANUAL có bị reset khi WiFi mất không?**
> Không. `relayState` là biến trong RAM, giữ giá trị cũ. `updateRelayState()` trong MANUAL chỉ `digitalWrite(RELAY_PIN, relayState)` – relay ON vẫn ON dù WiFi mất.

**Q7: Tại sao `sensorOk=false` không tắt hệ thống?**
> Safety-first: nếu DHT22 lỗi nhất thời, dùng lastValidTemp để hệ thống vẫn hoạt động. Mùa hè 34°C mà sensor lỗi → dùng 34°C → bơm vẫn bật đúng. Tắt hoàn toàn khi sensor lỗi gây mất mát nông sản.

---

## 5. Checklist Deliverable SV3

- [x] State Machine: sơ đồ 3 chiều (MODE / CONNECTION / PUMP)
- [x] State Machine: bảng điều kiện chuyển trạng thái đầy đủ
- [x] UI Mockup: cập nhật theo payload thật Tuần 3 (9 fields)
- [x] UI Mockup: mapping payload → widget rõ ràng
- [x] UI Mockup: thêm badge ONLINE/OFFLINE, MODE toggle, sensorOk
- [x] Business Rules: 6 rules dạng trigger–condition–action
- [x] Business Rules: code JS cho từng Function node Node-RED
- [x] Business Rules: topology flow Node-RED tuần 5
- [x] Hỗ trợ nhóm: 14 test case với expected output
- [x] Hỗ trợ nhóm: 7 câu hỏi thuyết trình chéo + trả lời mẫu

---

## 6. Chuẩn Bị Cho Tuần 4

Tuần 4 SV3 cần thêm:
- Thiết kế Node-RED dashboard thực tế (deploy lên localhost:1880)
- Thêm biểu đồ lịch sử nhiệt độ (chart node)
- Thêm Rule R7: cảnh báo T > 40°C (nhiệt độ cực cao)
- Topic `garden/mist/cmd/ack` – UI hiển thị xác nhận lệnh đã thực thi
