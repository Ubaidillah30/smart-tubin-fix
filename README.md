# Smart Turbin App (Flutter)

Dashboard monitoring & kontrol untuk firmware `3_anemo_esp32-1.ino` (ESP32 +
INA226 + relay + jadwal). Dua sumber data:

- **MQTT** (`broker.emqx.io`, topik `turbin/`) → data realtime (angin, daya
  masuk/keluar, baterai, status relay, jadwal) + kirim perintah kontrol.
- **Firebase RTDB** (`smart-turbin-default-rtdb...`) → histori perubahan
  relay (`history/relay`) & rekap angin 5 menitan (`telemetry/ANEMO-00x`).

## 1. Setup Firebase (WAJIB, sekali saja)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=smart-turbin
```

Perintah ini akan menimpa `lib/firebase_options.dart` dengan kredensial asli
project kamu, dan menaruh `google-services.json` (Android) /
`GoogleService-Info.plist` (iOS) otomatis.

## 2. Firebase RTDB Rules

Firmware ESP32 menulis ke Firebase **tanpa autentikasi** (REST API polos).
Supaya app & firmware bisa baca/tulis, set rules di Firebase Console →
Realtime Database → Rules (mode uji coba / development):

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

> ⚠️ Ini rules TERBUKA (siapa saja bisa baca/tulis). Cukup untuk
> development/skripsi. Untuk produksi, tambahkan autentikasi di firmware
> (Firebase Auth token) dan persempit rules-nya.

## 3. Install dependencies

```bash
flutter pub get
```

## 4. Jalankan

```bash
flutter run
```

## Catatan Arsitektur Penting

- **Data power/baterai/angin realtime HANYA lewat MQTT**, bukan Firebase —
  ini sesuai desain firmware (lihat komentar di kepala file `.ino`). Kalau
  broker `broker.emqx.io` (broker publik gratis) down/lambat, data realtime
  di app akan berhenti update walau Firebase tetap normal.
- **Grafik monitoring** di app adalah buffer realtime di memory (60 titik
  terakhir ≈ 2 menit, direset tiap ganti metrik), BUKAN data historis dari
  Firebase — karena firmware memang tidak mengirim histori power/baterai ke
  Firebase.
- **Jadwal relay**: firmware sudah dipatch supaya field `jadwal` ikut
  dipublish di payload MQTT retained `turbin/data`, jadi app bisa
  menampilkan jadwal aktual tersimpan di device (bukan cuma kirim buta).
  Pastikan firmware yang di-upload ke ESP32 adalah versi terbaru
  (`3_anemo_esp32-1_koreksi.ino`) supaya field ini ada.
- Tab **History** hanya menampilkan **Riwayat Relay** karena itu satu-satunya
  histori yang firmware kirim ke Firebase saat ini. Kartu "Riwayat Pompa
  Tandon / Pembersih Panel / Penyiraman / Lampu" di foto referensi kamu
  BELUM ada padanannya di firmware — device fisik untuk itu belum
  diimplementasikan di kode `.ino` ini.

## Struktur Folder

```
lib/
  models/turbin_data.dart       # parsing JSON MQTT & Firebase
  services/mqtt_service.dart    # koneksi MQTT + publish perintah
  services/firebase_service.dart# baca histori relay & rekap angin
  theme/app_theme.dart          # tema dark/light
  widgets/                      # kartu-kartu UI (angin, daya, baterai, relay, grafik)
  screens/dashboard_screen.dart # tab Dashboard
  screens/history_jadwal_screen.dart # tab History & Jadwal
  main.dart
```
