# Ghi Chú Kỹ Thuật – SV2: MQTT & Network/Middleware
**Đề tài 26: Dàn phun sương làm mát sân vườn | Nhóm 05 | Tuần 3**
**Phụ trách:** SV2 – Trần Thị Cẩm Vân

---

## 1. Thông Số MQTT

| Thông số | Giá trị | Ghi chú |
|---|---|---|
| Broker | `broker.emqx.io` | Public broker, miễn phí, không cần auth |
| Port | `1883` | TCP không mã hóa (TLS: 8883) |
| Client ID | `GardenMist-XXXXXXXX` | Dựa trên MAC address – cố định, unique |
| QoS sensor data | 0 | Fire & forget – OK cho dữ liệu thời gian thực |
| QoS status / LWT | 1 | At-least-once – đảm bảo dashboard nhận được |
| KeepAlive | 30 giây | Broker ping ESP32 mỗi 30s để kiểm tra còn sống |
| Publish interval | 1000 ms | Đọc sensor + publish mỗi 1 giây |
| MQTT reconnect | 5 giây | Non-blocking: thử kết nối lại sau mỗi 5s |
| WiFi check | 10 giây | Non-blocking: kiểm tra WiFi mỗi 10s |
| Buffer size | 512 byte | Tăng từ 256 (mặc định) để chứa status payload |

---

## 2. Bảng Topics MQTT

| Topic | Hướng | QoS | Retain | Payload mẫu |
|---|---|---|---|---|
| `garden/mist/temp` | Publish (ESP→Broker) | 0 | false | `{"temp": 34.00, "humidity": 65.50, "unit": "C"}` |
| `garden/mist/rain` | Publish (ESP→Broker) | 0 | false | `{"isRaining": false, "state": "KHONG"}` |
| `garden/mist/status` | Publish (ESP→Broker) | 1 | false | Xem Mục 3 |
| `garden/mist/status` | LWT (Broker tự publish) | 1 | **true** | `{"device": "GardenMist-ABCD1234", "status": "offline"}` |
| `garden/mist/cmd` | Subscribe (Broker→ESP) | 1 | – | `{"action": "on"}` / `{"action": "off"}` / `{"action": "auto"}` |

---

## 3. Payload Chuẩn Hóa – garden/mist/status

```json
{
  "device": "GardenMist-ABCD1234",
  "status": "online",
  "temp": 34.00,
  "humidity": 65.50,
  "isRaining": false,
  "relayState": "BAT",
  "mode": "AUTO",
  "sensorOk": true,
  "uptime": 12345
}
```

| Trường | Kiểu | Mô tả |
|---|---|---|
| `device` | string | Device ID (từ MAC) – nhận biết thiết bị trên dashboard |
| `status` | string | `"online"` khi đang chạy; broker tự publish `"offline"` khi mất kết nối (LWT) |
| `temp` | float | Nhiệt độ (°C), 2 chữ số thập phân |
| `humidity` | float | Độ ẩm (%), 2 chữ số thập phân |
| `isRaining` | bool | Trạng thái mưa ổn định (sau debounce) |
| `relayState` | string | `"BAT"` hoặc `"TAT"` |
| `mode` | string | `"AUTO"` hoặc `"MANUAL"` |
| `sensorOk` | bool | `true` nếu DHT22 đọc thành công; `false` nếu dùng giá trị cũ |
| `uptime` | integer | Thời gian hoạt động từ lúc khởi động (ms) |

---

## 4. Cơ Chế WiFi Reconnect Non-Blocking

```
loop() mỗi vòng
│
├── maintainWiFi()  ← kiểm tra mỗi 10s
│    ├── WiFi.status() == WL_CONNECTED?
│    │    ├── YES + wifiWasConnected=false → Log "kết nối lại thành cong"
│    │    │                                → Reset lastReconnectAttempt=0
│    │    └── YES + wifiWasConnected=true  → Bình thường, không làm gì
│    └── WiFi NGẮT
│         ├── wifiWasConnected=true → Log "mất kết nối"
│         └── Gọi WiFi.begin() để thử kết nối lại
│
└── reconnectMQTT() ← kiểm tra mỗi 5s (chỉ khi WiFi connected)
     ├── mqttClient.connected()? → return (đã kết nối rồi)
     └── Thử connect với LWT → Nếu OK: Subscribe cmd + Publish "online"
```

**Tại sao non-blocking quan trọng?**
- `delay()` blocking sẽ làm ngừng `mqttClient.loop()` → mất callback cmd
- Non-blocking đảm bảo hệ thống **vẫn đọc sensor và điều khiển relay** khi mạng đang tái kết nối

---

## 5. LWT (Last Will and Testament)

| Bước | Hành động |
|---|---|
| Kết nối MQTT | ESP gửi "di chúc": nếu mất kết nối đột ngột, broker publish `{"status":"offline"}` (retained) |
| ESP mất điện đột ngột | Broker phát hiện mất keepAlive (sau 30s) → tự publish LWT → Dashboard hiện "OFFLINE" |
| ESP khởi động lại + kết nối lại | ESP publish `{"status":"online"}` retained → ghi đè LWT → Dashboard hiện "ONLINE" |

---

## 6. MQTT Command Subscribe

**Topic:** `garden/mist/cmd` | **QoS:** 1

| Payload từ MQTTX | Kết quả |
|---|---|
| `{"action":"on"}` | Mode=MANUAL, Relay=BẬT → Serial: `[CMD] -> MANUAL + BAT relay` |
| `{"action":"off"}` | Mode=MANUAL, Relay=TẮT → Serial: `[CMD] -> MANUAL + TAT relay` |
| `{"action":"auto"}` | Mode=AUTO → Serial: `[CMD] -> ve che do AUTO` |

**Cách test với MQTTX:**
1. Mở MQTTX → New Connection: Host `broker.emqx.io`, Port `1883`
2. Subscribe `garden/mist/status` để xem dữ liệu ESP đang publish
3. Publish vào `garden/mist/cmd` payload `{"action":"on"}`
4. Xem Serial Monitor trong Wokwi có log `[MQTT CMD]` và `[CMD]`

---

## 7. Log Mã Lỗi MQTT

| Mã | Tên | Nguyên nhân |
|---|---|---|
| -4 | CONNECTION_TIMEOUT | Broker không phản hồi (mạng chậm, port sai) |
| -3 | CONNECTION_LOST | Kết nối bị ngắt giữa chừng |
| -2 | CONNECT_FAILED | Không tới được broker (DNS lỗi, firewall) |
| -1 | DISCONNECTED | Chưa kết nối / đã ngắt bình thường |
| 0 | CONNECTED | Đang kết nối bình thường ✅ |
| 2 | BAD_CLIENT_ID | Client ID bị từ chối (trùng với client khác) |
| 3 | UNAVAILABLE | Broker quá tải |

---

## 8. Checklist Deliverable SV2

- [x] WiFi reconnect non-blocking (`maintainWiFi()` mỗi 10s trong loop)
- [x] MQTT reconnect non-blocking (`reconnectMQTT()` mỗi 5s)
- [x] LWT `offline` (retained, QoS 1) khi kết nối MQTT
- [x] Publish `online` (retained) ngay sau khi kết nối lại thành công
- [x] Subscribe `garden/mist/cmd` với QoS 1
- [x] Payload chuẩn hóa: thêm `device`, `status`, `uptime`, `sensorOk`
- [x] Log MQTT rõ ràng: mã lỗi có giải thích, WiFi/MQTT status trong Serial mỗi vòng
- [x] Buffer MQTT tăng lên 512 byte
- [x] Device ID cố định từ MAC address
- [x] Ghi chú kỹ thuật đầy đủ (file này)

---

## 9. Chuẩn Bị Cho Tuần 4

Tuần 3 đã đặt nền:
- Subscribe `garden/mist/cmd` hoạt động đầy đủ, xử lý lệnh ngay
- Payload có `mode` và `relayState` → dashboard hiển thị đúng trạng thái
- Device ID cố định → dashboard biết đúng thiết bị nào gửi dữ liệu

Tuần 4 cần thêm:
- Topic `garden/mist/cmd/ack` để xác nhận lệnh đã thực thi
- QoS 2 cho lệnh quan trọng (exactly-once delivery)
- TLS/SSL nếu chuyển sang broker bảo mật (port 8883)
