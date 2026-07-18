/* ==============================================================================
   FIRMWARE ESP32 - ANEMOMETER + MONITORING DAYA (IN/OUT) + BATERAI + RELAY
   Migrasi dari ESP8266 -> ESP32, gaya procedural (TIDAK memakai class/OOP).

   PENAMBAHAN DARI VERSI ASLI:
   1. Sensor tegangan/arus/daya MASUK  (INA226 #1, alamat default 0x40)
   2. Sensor tegangan/arus/daya KELUAR (INA226 #2, alamat default 0x41)
   3. Status baterai (tegangan, persentase, kategori) dari tegangan sisi baterai
   4. Kontrol 1 relay: manual ON/OFF via MQTT + otomatis berdasar jadwal (multi slot)
   5. History relay (langsung dikirim & disimpan di Firebase RTDB, tanpa buffer di ESP32)
   6. NTP sebagai sumber waktu UTAMA (dipakai kalau internet tersedia,
      via klien SNTP background bawaan ESP32 -- tidak nge-block loop),
      dengan RTC DS3231 sebagai CADANGAN otomatis kalau NTP gagal/offline.
      Lihat waktuSekarangJamMenit()/epochUtcSekarang() untuk detail logika
      "coba NTP dulu, RTC kalau gagal" dan konversi lokal (WIB) <-> UTC.

   ARSITEKTUR DATA (MQTT vs FIREBASE):
   - MQTT topik "turbin/data" (retained, JSON, tiap 2 detik + saat relay berubah):
     SEMUA data monitoring realtime -> angin (s1,s2,s3), daya masuk, daya keluar,
     baterai, status+mode relay. Tidak ada lagi topik terpisah per sensor.
   - MQTT topik perintah (subscribe): "turbin/relay/set" (ON/OFF/AUTO),
     "turbin/relay/jadwal/set" (JSON jadwal).
   - Firebase RTDB HANYA menyimpan 2 hal: (1) rata-rata & maksimal kecepatan
     angin tiap 5 menit di "telemetry/{device}", (2) history perubahan relay
     di "history/relay". Jadwal relay CUKUP di NVS lokal (persisten walau
     reboot) + dikontrol lewat MQTT "turbin/relay/jadwal/set" - tidak perlu ke
     Firebase karena app bisa langsung baca/atur jadwal via MQTT (retained di
     "turbin/data") atau kirim ulang perintah set kapan saja.
     Data monitoring realtime (daya/baterai) TIDAK dikirim ke Firebase sama sekali.

   CATATAN PENTING (WAJIB DISESUAIKAN DENGAN HARDWARE ASLI):
   - Alamat I2C INA226 diatur lewat pin A0/A1 modul. Sesuaikan INA_IN_ADDR /
     INA_OUT_ADDR jika beda dari 0x40 / 0x41.
   - Nilai shunt resistor & arus maksimum (INA_SHUNT_OHM, INA_MAX_AMPERE) HARUS
     disesuaikan dengan modul INA226 yang dipakai supaya kalibrasi arus/daya akurat.
   - Asumsi topologi: INA226 "OUT" dipasang seri antara BATERAI -> BEBAN, sehingga
     tegangan bus INA226 OUT dipakai sebagai acuan tegangan baterai
     (lihat fungsi bacaTeganganBaterai()). Ubah jika topologi kabelmu berbeda.
   - Tabel persentase baterai memakai kurva lead-acid 12V. Ganti BATTERY_CURVE
     jika baterai memakai LiFePO4/Li-ion.
   - Perlu library: WiFiManager (tzapu, kompatibel ESP32), PubSubClient, ArduinoJson,
     INA226 (by RobTillaart), RTClib (by Adafruit - install dari Library Manager,
     cari "RTClib", akan otomatis minta install dependensi "Adafruit BusIO").
   - RTC DS3231 nyambung ke bus I2C yang SAMA dengan INA226 (SDA=21, SCL=22),
     alamat default 0x68, tidak konflik dengan 0x40/0x41. Pasang baterai
     CR2032 di modul RTC supaya waktu tetap jalan walau ESP32 mati/reset.
   ============================================================================== */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WiFiManager.h>
#include <PubSubClient.h>
#include <HTTPClient.h>
#include <Wire.h>
#include <INA226.h>
#include <RTClib.h>
#include <time.h>
#include <Preferences.h>
#include <ArduinoJson.h>

// ================= FIREBASE =================
// PASTIKAN diakhiri dengan tanda "/"
const char* FIREBASE_HOST = "https://smart-turbin-default-rtdb.asia-southeast1.firebasedatabase.app/";

// ================= MQTT =================
const char* MQTT_SERVER = "broker.emqx.io";
const int   MQTT_PORT   = 1883;

// Topik dasar
const char* TOPIK_DASAR = "turbin/";

// ================= PIN ANEMOMETER (disesuaikan ke GPIO ESP32) =================
#define ANEMO1 16
#define ANEMO2 17
#define ANEMO3 18

const float JUMLAH_CELAH = 18.0;
const float alpha = 0.15;

volatile unsigned long pulse1 = 0;
volatile unsigned long pulse2 = 0;
volatile unsigned long pulse3 = 0;

float filtered1 = 0;
float filtered2 = 0;
float filtered3 = 0;

// Nilai angin realtime terakhir (dipakai untuk publish JSON gabungan)
float anginS1 = 0, anginS2 = 0, anginS3 = 0;

// ================= VARIABEL HISTORI ANGIN (5 MENIT) =================
float sum1 = 0, sum2 = 0, sum3 = 0;
float max1 = 0, max2 = 0, max3 = 0;
int readCountAngin = 0;

// ================= PIN RELAY =================
#define RELAY_PIN 25
#define RELAY_AKTIF_LOW false   // ubah true kalau modul relay aktif LOW

// ================= I2C / INA226 =================
#define I2C_SDA 21
#define I2C_SCL 22

#define INA_IN_ADDR  0x40   // sensor sisi MASUK (sumber -> baterai)
#define INA_OUT_ADDR 0x41   // sensor sisi KELUAR (baterai -> beban)

const float INA_SHUNT_OHM  = 0.1;   // ohm, SESUAIKAN dengan modul
const float INA_MAX_AMPERE = 3.2;   // ampere, SESUAIKAN dengan kebutuhan

// Objek library INA226 (RobTillaart) - kalibrasi tinggal 1 baris, tanpa
// hitung register/LSB manual.
INA226 ina226Masuk(INA_IN_ADDR);
INA226 ina226Keluar(INA_OUT_ADDR);

// Hasil pembacaan terakhir
float teganganMasuk = 0, arusMasuk = 0, dayaMasuk = 0;
float teganganKeluar = 0, arusKeluar = 0, dayaKeluar = 0;

// ================= BATERAI =================
float teganganBaterai = 0;
int   persenBaterai = 0;
String statusBaterai = "TIDAK DIKETAHUI";

// Kurva tegangan (V) -> persentase (%) untuk baterai lead-acid 12V.
// GANTI kurva ini jika memakai LiFePO4 / Li-ion.
const float BATTERY_CURVE_V[] = {11.31, 11.58, 11.75, 11.90, 12.06, 12.20, 12.32, 12.42, 12.50, 12.70};
const int   BATTERY_CURVE_P[] = {   0,    10,    20,    30,    40,    50,    60,    70,    80,   100};
const int   BATTERY_CURVE_N = sizeof(BATTERY_CURVE_P) / sizeof(int);

// ================= RELAY: MODE, JADWAL (dengan TANGGAL), HISTORY =================
// relayMode: 0 = AUTO (ikut jadwal), 1 = MANUAL ON, 2 = MANUAL OFF
int relayMode = 0;
bool statusRelay = false;

struct JadwalRelay {
  uint16_t tahunMulai;
  uint8_t bulanMulai;
  uint8_t hariMulai;
  uint8_t jamMulai;
  uint8_t menitMulai;
  uint16_t tahunSelesai;
  uint8_t bulanSelesai;
  uint8_t hariSelesai;
  uint8_t jamSelesai;
  uint8_t menitSelesai;
  bool aktif;
};

#define JUMLAH_SLOT_JADWAL 10
JadwalRelay jadwal[JUMLAH_SLOT_JADWAL] = {
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},            // slot 1-10: kosong / nonaktif
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false},
  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false}
};

// History relay TIDAK disimpan di RAM ESP32 - langsung dikirim ke Firebase
// (lihat kirimHistoryKeFirebase()). Untuk lihat riwayat, query Firebase
// RTDB path "history/relay" dari aplikasi Flutter.

// ================= RTC (DS3231) =================
// Strategi waktu: NTP adalah sumber UTAMA (dipakai kalau internet ada --
// setelah configTime() dipanggil sekali di setup(), ESP32 punya klien SNTP
// background yang terus sinkronisasi sendiri selama WiFi hidup, jadi
// getLocalTime() di bawah ini CEPAT/non-blocking, bukan request jaringan
// baru tiap dipanggil). RTC DS3231 adalah CADANGAN yang otomatis dipakai
// kalau NTP gagal/tidak tersedia (WiFi mati / belum pernah sync).
//
// RTC kita SET & BACA dalam waktu LOKAL (WIB, UTC+7) supaya gampang
// dicocokkan ke jadwal. Sedangkan system clock hasil NTP (time()/getLocalTime())
// secara internal tetap UTC murni, cuma tampilan tm_hour/tm_min-nya sudah
// otomatis digeser ke WIB oleh configTime(7*3600, ...) di setup().
RTC_DS3231 rtc;
bool rtcSiap = false;
const long WIB_OFFSET_SECONDS = 7 * 3600;

// Ambil jam & menit SEKARANG (lokal/WIB): coba NTP dulu, RTC sebagai cadangan.
// Return false hanya jika KEDUANYA tidak tersedia (offline & RTC juga tidak
// terdeteksi/belum pernah di-set).
bool waktuSekarangJamMenit(int &jam, int &menit) {
  struct tm t;
  if (getLocalTime(&t, 100)) { // 100ms: cukup kalau system clock sudah pernah sync
    jam = t.tm_hour;
    menit = t.tm_min;
    return true;
  }
  if (rtcSiap) {
    DateTime now = rtc.now();
    jam = now.hour();
    menit = now.minute();
    return true;
  }
  return false; // NTP gagal DAN RTC tidak tersedia
}

// Ambil tanggal & jam LENGKAP sekarang (lokal/WIB): NTP dulu, RTC cadangan.
// Return false jika KEDUANYA tidak tersedia.
bool waktuSekarangLengkap(int &tahun, int &bulan, int &hari, int &jam, int &menit) {
  struct tm t;
  if (getLocalTime(&t, 100)) {
    tahun = t.tm_year + 1900;
    bulan = t.tm_mon + 1;
    hari = t.tm_mday;
    jam = t.tm_hour;
    menit = t.tm_min;
    return true;
  }
  if (rtcSiap) {
    DateTime now = rtc.now();
    tahun = now.year();
    bulan = now.month();
    hari = now.day();
    jam = now.hour();
    menit = now.minute();
    return true;
  }
  return false;
}

// Ambil epoch UTC murni sekarang, untuk field "epoch" history relay.
// Sama-sama NTP diutamakan, RTC cadangan.
unsigned long epochUtcSekarang() {
  struct tm t;
  if (getLocalTime(&t, 100)) {
    time_t utc;
    time(&utc); // sudah UTC murni (bawaan sistem, bukan hasil geser manual)
    return (unsigned long)utc;
  }
  if (rtcSiap) {
    return (unsigned long)(rtc.now().unixtime() - WIB_OFFSET_SECONDS);
  }
  return 0; // tidak diketahui (offline & RTC juga tidak ada)
}

Preferences preferensi;

// ================= TIMER =================
unsigned long lastReadMillis = 0;
unsigned long lastFirebaseMillis = 0;
unsigned long lastPowerReadMillis = 0;
unsigned long lastJadwalCekMillis = 0;
const long interval2s   = 2000;            // realtime MQTT (angin + daya)
const long interval5m   = 5 * 60 * 1000;   // rekap ke Firebase
const long intervalJadwal = 15 * 1000;     // cek jadwal tiap 15 detik

// ================= NETWORK CLIENT =================
WiFiClient espClient;
PubSubClient mqtt(espClient);
WiFiClientSecure secureClient;

// ================= INTERRUPT (ESP32 pakai IRAM_ATTR, bukan ICACHE_RAM_ATTR) =====
void IRAM_ATTR isr1() { pulse1++; }
void IRAM_ATTR isr2() { pulse2++; }
void IRAM_ATTR isr3() { pulse3++; }

// ================= DEKLARASI FUGSI
void ina226SetupSensor();
void bacaSensorDaya();
void hitungStatusBaterai();
void tulisRelay(bool nyala);
void catatHistory(bool state, uint8_t mode);
void setRelay(bool nyala, uint8_t mode);
bool cekDalamJadwal(int tahunSekarang, int bulanSekarang, int hariSekarang, int jamSekarang, int menitSekarangArg);
void cekJadwalRelay();
void simpanJadwal();
void muatJadwal();
void mqttCallback(char *topic, byte *payload, unsigned int length);
void reconnectMQTT();
float hitungKecepatan(unsigned long pulsa, float &filteredVal, float dt);
void pushToFirebase(const char* deviceId, float avgSpeed, float mGust);
void kirimHistoryKeFirebase(bool state, uint8_t mode, time_t waktu);
void publishDataGabungan();


// =====================================================================
// ================================ SETUP ==============================
// =====================================================================
void setup() {
  Serial.begin(115200);

  // ---- Relay ----
  pinMode(RELAY_PIN, OUTPUT);
  tulisRelay(false);

  // ---- Anemometer ----
  pinMode(ANEMO1, INPUT);
  pinMode(ANEMO2, INPUT);
  pinMode(ANEMO3, INPUT);
  attachInterrupt(digitalPinToInterrupt(ANEMO1), isr1, RISING);
  attachInterrupt(digitalPinToInterrupt(ANEMO2), isr2, RISING);
  attachInterrupt(digitalPinToInterrupt(ANEMO3), isr3, RISING);

  // ---- I2C & INA226 ----
  Wire.begin(I2C_SDA, I2C_SCL);
  ina226SetupSensor();

  // ---- WiFi (WiFiManager, sama seperti versi ESP8266) ----
  WiFiManager wifiManager;
  wifiManager.autoConnect("ESP32-Turbin-Multi v.1");
  Serial.println("WiFi Terhubung!");

  // ---- RTC DS3231 ----
  if (!rtc.begin()) {
    Serial.println("ERROR: RTC DS3231 tidak terdeteksi! Cek wiring I2C (SDA/SCL) & alamat 0x68.");
    rtcSiap = false;
  } else {
    rtcSiap = true;
    if (rtc.lostPower()) {
      // RTC kehilangan daya (baterai CR2032 modul habis / baru pertama pasang).
      // Set sementara dari waktu KOMPILASI kode ini (asumsi dikompilasi di
      // waktu lokal WIB) - akan dikoreksi otomatis oleh NTP di bawah kalau
      // ESP32 berhasil konek WiFi.
      Serial.println("RTC kehilangan daya, set awal dari waktu kompilasi...");
      rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
    }
  }

  // ---- NTP: dipanggil sekali di sini untuk mengaktifkan klien SNTP
  // background bawaan ESP32 (akan terus sinkronisasi sendiri selama WiFi
  // hidup -- lihat waktuSekarangJamMenit()/epochUtcSekarang() yang otomatis
  // pakai NTP kalau tersedia, RTC sebagai cadangan kalau tidak). Di sini
  // juga sekalian mengoreksi RTC dengan waktu NTP yang akurat, supaya kalau
  // nanti offline lama, RTC tidak terlalu ngaco.
  if (WiFi.status() == WL_CONNECTED) {
    configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov"); // WIB (UTC+7)
    struct tm waktuNtp;
    if (getLocalTime(&waktuNtp, 5000)) { // tunggu maks 5 detik
      if (rtcSiap) {
        rtc.adjust(DateTime(waktuNtp.tm_year + 1900, waktuNtp.tm_mon + 1, waktuNtp.tm_mday,
                             waktuNtp.tm_hour, waktuNtp.tm_min, waktuNtp.tm_sec));
        Serial.println("RTC berhasil disinkronkan dari NTP.");
      }
    } else {
      Serial.println("NTP tidak tersedia, pakai waktu RTC yang tersimpan.");
    }
  }

  // ---- Firebase (skip verifikasi SSL, hemat resource) ----
  secureClient.setInsecure();

  // ---- MQTT ----
  // PENTING: default buffer PubSubClient hanya 256 byte. Payload JSON gabungan
  // kita (angin+daya+baterai+relay) bisa >300 byte, sehingga TANPA baris di
  // bawah ini publish() akan gagal diam-diam (return false) tanpa error jelas.
  mqtt.setBufferSize(1024);
  mqtt.setServer(MQTT_SERVER, MQTT_PORT);
  mqtt.setCallback(mqttCallback);

  // ---- Muat konfigurasi relay tersimpan ----
  muatJadwal();
  // DEBUG SEMENTARA — hapus setelah masalah selesai
  // Serial.println("=== ISI JADWAL SETELAH MUAT DARI NVS ===");
  // for (int i = 0; i < JUMLAH_SLOT_JADWAL; i++) {
  //   Serial.printf("Slot %d: aktif=%d | mulai=%04d-%02d-%02d %02d:%02d | selesai=%04d-%02d-%02d %02d:%02d\n",
  //     i, jadwal[i].aktif,
  //     jadwal[i].tahunMulai, jadwal[i].bulanMulai, jadwal[i].hariMulai, jadwal[i].jamMulai, jadwal[i].menitMulai,
  //     jadwal[i].tahunSelesai, jadwal[i].bulanSelesai, jadwal[i].hariSelesai, jadwal[i].jamSelesai, jadwal[i].menitSelesai);
  // }
}

// =====================================================================
// ================================ LOOP ================================
// =====================================================================
void loop() {
  // WiFiManager.autoConnect() di setup() hanya menyambungkan sekali di awal.
  // Kalau WiFi putus di tengah jalan (router restart, sinyal hilang, dll),
  // tanpa baris ini ESP32 tidak akan pernah otomatis konek ulang.
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastWifiRetry = 0;
    if (millis() - lastWifiRetry >= 5000) {
      lastWifiRetry = millis();
      Serial.println("WiFi terputus, mencoba reconnect...");
      WiFi.reconnect();
    }
    return; // tunggu WiFi nyambung dulu sebelum lanjut ke MQTT/sensor
  }

  if (!mqtt.connected()) {
    reconnectMQTT();
  }
  mqtt.loop();

  unsigned long currentMillis = millis();

  // ---------------------------------------------------------
  // LOGIKA 1: BACA ANEMOMETER + SENSOR DAYA & PUBLISH MQTT (2 detik)
  // ---------------------------------------------------------
  if (currentMillis - lastReadMillis >= interval2s) {
    float dt = (currentMillis - lastReadMillis) / 1000.0;
    lastReadMillis = currentMillis;

    noInterrupts();
    unsigned long p1 = pulse1; pulse1 = 0;
    unsigned long p2 = pulse2; pulse2 = 0;
    unsigned long p3 = pulse3; pulse3 = 0;
    interrupts();

    float s1 = hitungKecepatan(p1, filtered1, dt);
    float s2 = hitungKecepatan(p2, filtered2, dt);
    float s3 = hitungKecepatan(p3, filtered3, dt);

    sum1 += s1; sum2 += s2; sum3 += s3;
    readCountAngin++;

    if (s1 > max1) max1 = s1;
    if (s2 > max2) max2 = s2;
    if (s3 > max3) max3 = s3;

    anginS1 = s1; anginS2 = s2; anginS3 = s3;

    Serial.printf("Angin -> S1: %.2f | S2: %.2f | S3: %.2f (m/s)\n", s1, s2, s3);

    // Baca sensor daya + hitung status baterai, lalu publish SEMUA data
    // monitoring (angin, daya, baterai, relay) dalam satu topik JSON.
    bacaSensorDaya();
    publishDataGabungan();

    Serial.printf("Masuk  -> V:%.2f I:%.3f P:%.2f | Keluar -> V:%.2f I:%.3f P:%.2f | Baterai: %.2fV (%d%%, %s)\n",
                  teganganMasuk, arusMasuk, dayaMasuk,
                  teganganKeluar, arusKeluar, dayaKeluar,
                  teganganBaterai, persenBaterai, statusBaterai.c_str());
  }

  // ---------------------------------------------------------
  // LOGIKA 2: CEK JADWAL RELAY (setiap 15 detik, hanya mode AUTO)
  // ---------------------------------------------------------
  if (currentMillis - lastJadwalCekMillis >= intervalJadwal) {
    lastJadwalCekMillis = currentMillis;
    cekJadwalRelay();
  }

  // ---------------------------------------------------------
  // LOGIKA 3: REKAP & KIRIM KE FIREBASE (setiap 5 menit)
  // ---------------------------------------------------------
  if (currentMillis - lastFirebaseMillis >= interval5m) {
    lastFirebaseMillis = currentMillis;

    if (readCountAngin > 0) {
      float avg1 = sum1 / readCountAngin;
      float avg2 = sum2 / readCountAngin;
      float avg3 = sum3 / readCountAngin;

      Serial.println("\n=== MENGIRIM REKAP 5 MENIT KE FIREBASE ===");
      pushToFirebase("ANEMO-001", avg1, max1);
      pushToFirebase("ANEMO-002", avg2, max2);
      pushToFirebase("ANEMO-003", avg3, max3);

      sum1 = 0; sum2 = 0; sum3 = 0;
      max1 = 0; max2 = 0; max3 = 0;
      readCountAngin = 0;
    }
  }
}

// =====================================================================
// ============================ FUNGSI INA226 =========================
// =====================================================================
// Inisialisasi & kalibrasi kedua sensor - cukup 1 baris per sensor,
// tidak perlu hitung register/LSB manual lagi.
void ina226SetupSensor() {
  if (!ina226Masuk.begin()) {
    Serial.println("ERROR: INA226 MASUK (0x40) tidak terdeteksi! Cek wiring/alamat I2C.");
  }
  ina226Masuk.setMaxCurrentShunt(INA_MAX_AMPERE, INA_SHUNT_OHM);

  if (!ina226Keluar.begin()) {
    Serial.println("ERROR: INA226 KELUAR (0x41) tidak terdeteksi! Cek wiring/alamat I2C.");
  }
  ina226Keluar.setMaxCurrentShunt(INA_MAX_AMPERE, INA_SHUNT_OHM);
}

void bacaSensorDaya() {
  teganganMasuk = 11.50;//ina226Masuk.getBusVoltage();   // Volt
  arusMasuk     = 2.5;//ina226Masuk.getCurrent();      // Ampere
  dayaMasuk     = 3.6;//ina226Masuk.getPower();        // Watt

  teganganKeluar = 12.50;//ina226Keluar.getBusVoltage();
  arusKeluar     = 2.31;//ina226Keluar.getCurrent();
  dayaKeluar     = 3.4;//ina226Keluar.getPower();

  hitungStatusBaterai();
}


// =====================================================================
// ============================ FUNGSI BATERAI ========================
// =====================================================================
void hitungStatusBaterai() {
  // Asumsi: tegangan baterai diwakili oleh sisi KELUAR (baterai -> beban).
  // Ganti ke teganganMasuk jika topologi wiring-mu berbeda.
  teganganBaterai = teganganKeluar;

  if (teganganBaterai <= BATTERY_CURVE_V[0]) {
    persenBaterai = 0;
  } else if (teganganBaterai >= BATTERY_CURVE_V[BATTERY_CURVE_N - 1]) {
    persenBaterai = 100;
  } else {
    for (int i = 0; i < BATTERY_CURVE_N - 1; i++) {
      if (teganganBaterai >= BATTERY_CURVE_V[i] && teganganBaterai <= BATTERY_CURVE_V[i + 1]) {
        float rasio = (teganganBaterai - BATTERY_CURVE_V[i]) / (BATTERY_CURVE_V[i + 1] - BATTERY_CURVE_V[i]);
        persenBaterai = BATTERY_CURVE_P[i] + rasio * (BATTERY_CURVE_P[i + 1] - BATTERY_CURVE_P[i]);
        break;
      }
    }
  }

  if (persenBaterai >= 90) statusBaterai = "PENUH";
  else if (persenBaterai >= 50) statusBaterai = "BAIK";
  else if (persenBaterai >= 20) statusBaterai = "RENDAH";
  else statusBaterai = "KRITIS";
}

// =====================================================================
// ============================ FUNGSI RELAY ==========================
// =====================================================================
void tulisRelay(bool nyala) {
  bool level = RELAY_AKTIF_LOW ? !nyala : nyala;
  digitalWrite(RELAY_PIN, level ? HIGH : LOW);
  statusRelay = nyala;
}

void catatHistory(bool state, uint8_t mode) {
  // Sebelumnya pakai time(&sekarang) yang bergantung system clock ESP32
  // (hasil configTime/NTP) -- kalau NTP gagal/offline, nilainya ngaco.
  // Sekarang pakai RTC DS3231 (tetap akurat walau offline), dan sudah
  // dikonversi ke UTC murni oleh epochUtcSekarang().
  unsigned long epochUtc = epochUtcSekarang();
  kirimHistoryKeFirebase(state, mode, (time_t)epochUtc);
}

void setRelay(bool nyala, uint8_t mode) {
  if (statusRelay != nyala) {
    tulisRelay(nyala);
    catatHistory(nyala, mode);
    Serial.printf("Relay -> %s (mode=%s)\n", nyala ? "ON" : "OFF", mode == 1 ? "MANUAL" : "AUTO");
    publishDataGabungan(); // langsung publish supaya dashboard tahu perubahan tanpa nunggu siklus 2 detik
  }
}

// Cek apakah waktu sekarang (tanggal + jam:menit, LOKAL/WIB) berada di dalam salah
// satu slot jadwal. Sekarang mendukung perbandingan TANGGAL penuh.
bool cekDalamJadwal(int tahunSekarang, int bulanSekarang, int hariSekarang, int jamSekarang, int menitSekarangArg) {
  unsigned long menitSekarang = ((unsigned long)(tahunSekarang * 365 + bulanSekarang * 30 + hariSekarang)) * 1440 + jamSekarang * 60 + menitSekarangArg;
  for (int i = 0; i < JUMLAH_SLOT_JADWAL; i++) {
    if (!jadwal[i].aktif) continue;
    unsigned long mulai = ((unsigned long)(jadwal[i].tahunMulai * 365 + jadwal[i].bulanMulai * 30 + jadwal[i].hariMulai)) * 1440
                          + jadwal[i].jamMulai * 60 + jadwal[i].menitMulai;
    unsigned long selesai = ((unsigned long)(jadwal[i].tahunSelesai * 365 + jadwal[i].bulanSelesai * 30 + jadwal[i].hariSelesai)) * 1440
                           + jadwal[i].jamSelesai * 60 + jadwal[i].menitSelesai;
    if (mulai == selesai) continue; // slot kosong

    if (mulai < selesai) {
      if (menitSekarang >= mulai && menitSekarang < selesai) return true;
    } else {
      // Melewati tengah malam (jarang dengan tanggal, tapi tetap support)
      if (menitSekarang >= mulai || menitSekarang < selesai) return true;
    }
  }
  return false;
}

void cekJadwalRelay() {
  if (relayMode != 0) return; // hanya berlaku kalau mode AUTO

  int tahun, bulan, hari, jam, menit;
  if (!waktuSekarangLengkap(tahun, bulan, hari, jam, menit)) {
    Serial.println("Waktu tidak tersedia (NTP gagal & RTC tidak terdeteksi), jadwal dilewati.");
    return;
  }

  bool harusNyala = cekDalamJadwal(tahun, bulan, hari, jam, menit);
  setRelay(harusNyala, 0);
}

//   bool harusNyala = cekDalamJadwal(jam, menit);
//   setRelay(harusNyala, 0);
// }

// =====================================================================
// ==================== SIMPAN / MUAT JADWAL (NVS) ====================
// =====================================================================
void simpanJadwal() {
  preferensi.begin("relay-cfg", false);
  preferensi.putBytes("jadwal", jadwal, sizeof(jadwal));
  preferensi.putInt("mode", relayMode);
  preferensi.end();
}

void muatJadwal() {
  preferensi.begin("relay-cfg", true);
  if (preferensi.isKey("jadwal")) {
    preferensi.getBytes("jadwal", jadwal, sizeof(jadwal));
  }
  if (preferensi.isKey("mode")) {
    relayMode = preferensi.getInt("mode", 0);
  }
  preferensi.end();
}

// =====================================================================
// ============================ FUNGSI MQTT ============================
// =====================================================================

// Terima perintah manual relay: payload "ON" / "OFF" / "AUTO"
void mqttCallback(char *topic, byte *payload, unsigned int length) {
  String pesan;
  for (unsigned int i = 0; i < length; i++) pesan += (char)payload[i];
  pesan.trim();

  String t = String(topic);

  if (t == String(TOPIK_DASAR) + "relay/set") {
    pesan.toUpperCase();
    if (pesan == "ON") {
      relayMode = 1;
      setRelay(true, 1);
    } else if (pesan == "OFF") {
      relayMode = 2;
      setRelay(false, 1);
    } else if (pesan == "AUTO") {
      relayMode = 0;
      cekJadwalRelay();
    }
    simpanJadwal();
  }
  else if (t == String(TOPIK_DASAR) + "relay/jadwal/set") {
    // Contoh payload JSON (dengan tanggal):
    // [{"mulai":"2026-07-16 06:00","selesai":"2026-07-16 09:00","aktif":true}, ...]
    // Format lama (tanpa tanggal) juga tetap didukung untuk backward compat:
    // [{"mulai":"06:00","selesai":"09:00","aktif":true}, ...]
    StaticJsonDocument<2048> doc;
    DeserializationError err = deserializeJson(doc, pesan);
    if (!err && doc.is<JsonArray>()) {
      JsonArray arr = doc.as<JsonArray>();
      int idx = 0;
      for (JsonObject obj : arr) {
        if (idx >= JUMLAH_SLOT_JADWAL) break;
        String mulai = obj["mulai"].as<String>();
        String selesai = obj["selesai"].as<String>();

        // Format baru: "YYYY-MM-DD HH:MM" atau "YYYY-MM-DDTHH:MM"
        // Format lama (backward compat): "HH:MM" — pakai tanggal 0 (tanpa filter tanggal)
        if (mulai.length() >= 16 && mulai.indexOf('-') >= 0) {
          jadwal[idx].tahunMulai  = mulai.substring(0, 4).toInt();
          jadwal[idx].bulanMulai  = mulai.substring(5, 7).toInt();
          jadwal[idx].hariMulai   = mulai.substring(8, 10).toInt();
          jadwal[idx].jamMulai    = mulai.substring(11, 13).toInt();
          jadwal[idx].menitMulai  = mulai.substring(14, 16).toInt();
        } else {
          // Backward compat: tanpa tanggal, set ke 0 (tidak filter tanggal)
          jadwal[idx].tahunMulai = 0; jadwal[idx].bulanMulai = 0; jadwal[idx].hariMulai = 0;
          jadwal[idx].jamMulai   = mulai.substring(0, 2).toInt();
          jadwal[idx].menitMulai = mulai.substring(3, 5).toInt();
        }
        if (selesai.length() >= 16 && selesai.indexOf('-') >= 0) {
          jadwal[idx].tahunSelesai  = selesai.substring(0, 4).toInt();
          jadwal[idx].bulanSelesai  = selesai.substring(5, 7).toInt();
          jadwal[idx].hariSelesai   = selesai.substring(8, 10).toInt();
          jadwal[idx].jamSelesai    = selesai.substring(11, 13).toInt();
          jadwal[idx].menitSelesai  = selesai.substring(14, 16).toInt();
        } else {
          jadwal[idx].tahunSelesai = 0; jadwal[idx].bulanSelesai = 0; jadwal[idx].hariSelesai = 0;
          jadwal[idx].jamSelesai   = selesai.substring(0, 2).toInt();
          jadwal[idx].menitSelesai = selesai.substring(3, 5).toInt();
        }
        jadwal[idx].aktif = obj["aktif"] | true;
        idx++;
      }
      simpanJadwal();
      // Langsung cek jadwal agar relay berubah segera (tidak nunggu siklus 15 detik)
      cekJadwalRelay();
      Serial.println("Jadwal relay diperbarui.");
    } else {
      Serial.println("Format JSON jadwal tidak valid.");
    }
  }
}

void reconnectMQTT() {
  // Non-blocking retry: tanpa jeda ini, selama MQTT gagal konek, loop() akan
  // memanggil mqtt.connect() di SETIAP iterasi (ratusan kali/detik) sehingga
  // membanjiri broker dan bikin loop lain (baca sensor dst) ikut tersendat.
  static unsigned long lastMqttRetry = 0;
  if (millis() - lastMqttRetry < 5000) return;
  lastMqttRetry = millis();

  Serial.print("Mencoba koneksi MQTT...");
  String clientId = "TURBIN-ESP32-" + WiFi.macAddress();
  clientId.replace(":", "");

  // LWT (Last Will & Testament): jika ESP32 disconnect mendadak, broker akan
  // publish "offline" ke topik turbin/status dengan retain=true.
  // Dashboard Flutter langsung tahu device offline meskipun ESP32 mati total.
  const char* willTopic = "turbin/status";
  const char* willPayload = "offline";
  bool willRetain = true;
  int willQos = 1;

  if (mqtt.connect(clientId.c_str(), NULL, NULL, willTopic, willQos, willRetain, willPayload)) {
    Serial.println("Terhubung!");
    // Publish "online" — broker auto-publish "offline" saat disconnect mendadak
    mqtt.publish(willTopic, "online", true);
    mqtt.subscribe((String(TOPIK_DASAR) + "relay/set").c_str());
    mqtt.subscribe((String(TOPIK_DASAR) + "relay/jadwal/set").c_str());
    publishDataGabungan();
  } else {
    Serial.print("Gagal, rc=");
    Serial.println(mqtt.state());
  }
}

// =====================================================================
// ========================= FUNGSI KALKULASI ANGIN ====================
// =====================================================================
float hitungKecepatan(unsigned long pulsa, float &filteredVal, float dt) {
  float speedRaw = 0;
  if (pulsa > 0 && dt > 0) {
    float rps = ((float)pulsa / JUMLAH_CELAH) / dt;
    speedRaw = (3.9301 * rps) - 13.0285;
    if (speedRaw < 0) speedRaw = 0;
  }

  if (pulsa == 0) {
    filteredVal = 0;
  } else {
    filteredVal = alpha * speedRaw + (1.0 - alpha) * filteredVal;
  }
  return filteredVal;
}

// =====================================================================
// ============================ FIREBASE (REST) ========================
// =====================================================================
void pushToFirebase(const char* deviceId, float avgSpeed, float mGust) {
  if (WiFi.status() != WL_CONNECTED) return;
  HTTPClient http;
  String url = String(FIREBASE_HOST) + "telemetry/" + String(deviceId) + ".json";

  http.begin(secureClient, url);
  http.addHeader("Content-Type", "application/json");

  String payload = "{\"avg\":" + String(avgSpeed, 2) +
                    ",\"max\":" + String(mGust, 2) +
                    ",\"ts\":{\".sv\":\"timestamp\"}}";

  int httpResponseCode = http.POST(payload);
  if (httpResponseCode > 0) {
    Serial.printf("Firebase Sukses [%s]: %d\n", deviceId, httpResponseCode);
  } else {
    Serial.printf("Firebase Gagal [%s]: %s\n", deviceId, http.errorToString(httpResponseCode).c_str());
  }
  http.end();
}

void kirimHistoryKeFirebase(bool state, uint8_t mode, time_t waktu) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.printf("WARNING: WiFi down, history %s tidak terkirim!\n", state ? "ON" : "OFF");
    return;
  }
  HTTPClient http;
  String url = String(FIREBASE_HOST) + "history/relay.json";

  http.begin(secureClient, url);
  http.addHeader("Content-Type", "application/json");

  String payload = "{\"aksi\":\"" + String(state ? "ON" : "OFF") + "\"" +
                    ",\"mode\":\"" + String(mode == 1 ? "MANUAL" : "AUTO") + "\"" +
                    ",\"epoch\":" + String((unsigned long)waktu) +
                    ",\"ts\":{\".sv\":\"timestamp\"}}";

  // Retry 3x kalau gagal
  int httpResponseCode = -1;
  for (int retry = 0; retry < 3 && httpResponseCode <= 0; retry++) {
    if (retry > 0) delay(200);
    httpResponseCode = http.POST(payload);
  }
  if (httpResponseCode > 0) {
    Serial.printf("History %s -> Firebase OK\n", state ? "ON" : "OFF");
  } else {
    Serial.printf("Firebase Gagal (history): %s\n", http.errorToString(httpResponseCode).c_str());
  }
  http.end();
}

// =====================================================================
// ================= MQTT: DATA GABUNGAN (turbin/data) ==================
// =====================================================================
// Semua data monitoring realtime (angin, daya masuk/keluar, baterai, relay)
// digabung jadi SATU topik JSON, retained, supaya dashboard cukup subscribe
// 1 topik dan langsung dapat state terakhir saat reconnect.
void publishDataGabungan() {
  StaticJsonDocument<2048> doc;

  JsonObject angin = doc.createNestedObject("angin");
  angin["s1"] = anginS1;
  angin["s2"] = anginS2;
  angin["s3"] = anginS3;

  JsonObject daya = doc.createNestedObject("daya");
  JsonObject masuk = daya.createNestedObject("masuk");
  masuk["v"] = teganganMasuk;
  masuk["i"] = arusMasuk;
  masuk["p"] = dayaMasuk;
  JsonObject keluar = daya.createNestedObject("keluar");
  keluar["v"] = teganganKeluar;
  keluar["i"] = arusKeluar;
  keluar["p"] = dayaKeluar;

  JsonObject baterai = doc.createNestedObject("baterai");
  baterai["v"] = teganganBaterai;
  baterai["persen"] = persenBaterai;
  baterai["status"] = statusBaterai;

  JsonObject relay = doc.createNestedObject("relay");
  relay["status"] = statusRelay ? "ON" : "OFF";
  relay["mode"] = relayMode == 0 ? "AUTO" : (relayMode == 1 ? "MANUAL_ON" : "MANUAL_OFF");

  // Jadwal ikut dipublish (read-back) supaya app bisa menampilkan jadwal
  // aktual yang tersimpan di device, bukan cuma bisa "set" tanpa lihat hasil.
  // Format: "mulai":"2026-07-16 06:00", "selesai":"2026-07-16 09:00"
  // Backward compat: jika tahun=0, kirim "HH:MM" saja (tanpa tanggal)
  JsonArray jadwalArr = doc.createNestedArray("jadwal");
  for (int i = 0; i < JUMLAH_SLOT_JADWAL; i++) {
    JsonObject slot = jadwalArr.createNestedObject();
    if (jadwal[i].tahunMulai > 0) {
      char mulaiBuf[20], selesaiBuf[20];
      snprintf(mulaiBuf, sizeof(mulaiBuf), "%04d-%02d-%02d %02d:%02d",
               jadwal[i].tahunMulai, jadwal[i].bulanMulai, jadwal[i].hariMulai,
               jadwal[i].jamMulai, jadwal[i].menitMulai);
      snprintf(selesaiBuf, sizeof(selesaiBuf), "%04d-%02d-%02d %02d:%02d",
               jadwal[i].tahunSelesai, jadwal[i].bulanSelesai, jadwal[i].hariSelesai,
               jadwal[i].jamSelesai, jadwal[i].menitSelesai);
      slot["mulai"] = mulaiBuf;
      slot["selesai"] = selesaiBuf;
    } else {
      // Backward compat: tanpa tanggal
      char mulaiBuf[6], selesaiBuf[6];
      snprintf(mulaiBuf, sizeof(mulaiBuf), "%02d:%02d", jadwal[i].jamMulai, jadwal[i].menitMulai);
      snprintf(selesaiBuf, sizeof(selesaiBuf), "%02d:%02d", jadwal[i].jamSelesai, jadwal[i].menitSelesai);
      slot["mulai"] = mulaiBuf;
      slot["selesai"] = selesaiBuf;
    }
    slot["aktif"] = jadwal[i].aktif;
  }

  char buf[900];
  size_t len = serializeJson(doc, buf, sizeof(buf));

  String topik = String(TOPIK_DASAR) + "data";
  if (!mqtt.publish(topik.c_str(), (const uint8_t*)buf, len, true)) { // retained
    Serial.println("WARNING: publish turbin/data gagal (cek MQTT buffer size / koneksi).");
  }
}
