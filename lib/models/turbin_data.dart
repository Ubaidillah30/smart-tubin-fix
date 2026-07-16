/// Model data turbin angin hybrid (ESP32 + MQTT + Firebase RTDB)
class TurbinData {
  final DayaInfo dayaMasuk;
  final DayaInfo dayaKeluar;
  final double teganganBaterai;
  final double persenBaterai;
  final String statusBaterai;
  final double anginS1;
  final double anginS2;
  final double anginS3;
  final bool relayOn;
  final String relayMode;
  final List<JadwalSlot> jadwal;

  TurbinData({
    required this.dayaMasuk,
    required this.dayaKeluar,
    required this.teganganBaterai,
    required this.persenBaterai,
    required this.statusBaterai,
    required this.anginS1,
    required this.anginS2,
    required this.anginS3,
    required this.relayOn,
    required this.relayMode,
    required this.jadwal,
  });

  factory TurbinData.kosong() {
    return TurbinData(
      dayaMasuk: DayaInfo(tegangan: 0, arus: 0, daya: 0),
      dayaKeluar: DayaInfo(tegangan: 0, arus: 0, daya: 0),
      teganganBaterai: 0,
      persenBaterai: 0,
      statusBaterai: 'Unknown',
      anginS1: 0,
      anginS2: 0,
      anginS3: 0,
      relayOn: false,
      relayMode: 'AUTO',
      jadwal: [],
    );
  }

  factory TurbinData.fromJson(Map<String, dynamic> json) {
    return TurbinData(
      dayaMasuk: DayaInfo.fromJson(json['dayaMasuk'] ?? {}),
      dayaKeluar: DayaInfo.fromJson(json['dayaKeluar'] ?? {}),
      teganganBaterai: (json['teganganBaterai'] ?? 0).toDouble(),
      persenBaterai: (json['persenBaterai'] ?? 0).toDouble(),
      statusBaterai: json['statusBaterai'] ?? 'Unknown',
      anginS1: (json['anginS1'] ?? 0).toDouble(),
      anginS2: (json['anginS2'] ?? 0).toDouble(),
      anginS3: (json['anginS3'] ?? 0).toDouble(),
      relayOn: json['relayOn'] ?? false,
      relayMode: json['relayMode'] ?? 'AUTO',
      jadwal: (json['jadwal'] as List<dynamic>?)
              ?.map((e) => JadwalSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  TurbinData copyWith({
    DayaInfo? dayaMasuk,
    DayaInfo? dayaKeluar,
    double? teganganBaterai,
    double? persenBaterai,
    String? statusBaterai,
    double? anginS1,
    double? anginS2,
    double? anginS3,
    bool? relayOn,
    String? relayMode,
    List<JadwalSlot>? jadwal,
  }) {
    return TurbinData(
      dayaMasuk: dayaMasuk ?? this.dayaMasuk,
      dayaKeluar: dayaKeluar ?? this.dayaKeluar,
      teganganBaterai: teganganBaterai ?? this.teganganBaterai,
      persenBaterai: persenBaterai ?? this.persenBaterai,
      statusBaterai: statusBaterai ?? this.statusBaterai,
      anginS1: anginS1 ?? this.anginS1,
      anginS2: anginS2 ?? this.anginS2,
      anginS3: anginS3 ?? this.anginS3,
      relayOn: relayOn ?? this.relayOn,
      relayMode: relayMode ?? this.relayMode,
      jadwal: jadwal ?? this.jadwal,
    );
  }
}

/// Info daya (tegangan, arus, daya)
class DayaInfo {
  final double tegangan;
  final double arus;
  final double daya;

  DayaInfo({
    required this.tegangan,
    required this.arus,
    required this.daya,
  });

  factory DayaInfo.fromJson(Map<String, dynamic> json) {
    return DayaInfo(
      tegangan: (json['tegangan'] ?? 0).toDouble(),
      arus: (json['arus'] ?? 0).toDouble(),
      daya: (json['daya'] ?? 0).toDouble(),
    );
  }
}

/// Slot jadwal relay (dengan dukungan tanggal penuh)
class JadwalSlot {
  final String mulai;    // "HH:MM" atau "YYYY-MM-DD HH:MM"
  final String selesai;  // "HH:MM" atau "YYYY-MM-DD HH:MM"
  final bool aktif;

  JadwalSlot({
    required this.mulai,
    required this.selesai,
    required this.aktif,
  });

  /// Parsing dari JSON firmware.
  /// Format baru: "2026-07-16 06:00" (dengan tanggal)
  /// Format lama: "06:00" (tanpa tanggal, backward compat)
  factory JadwalSlot.fromJson(Map<String, dynamic> json) {
    return JadwalSlot(
      mulai: json['mulai'] ?? '00:00',
      selesai: json['selesai'] ?? '00:00',
      aktif: json['aktif'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mulai': mulai,
      'selesai': selesai,
      'aktif': aktif,
    };
  }

  /// Apakah slot ini memiliki tanggal lengkap (bukan hanya jam)?
  bool get punyaTanggal => mulai.length >= 16 && mulai.contains('-');

  /// Parse tanggal dari string "YYYY-MM-DD HH:MM"
  DateTime? get waktuMulai {
    if (!punyaTanggal) return null;
    try {
      return DateTime.parse(mulai.replaceAll(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  DateTime? get waktuSelesai {
    if (!punyaTanggal) return null;
    try {
      return DateTime.parse(selesai.replaceAll(' ', 'T'));
    } catch (_) {
      return null;
    }
  }
}

/// Histori relay dari Firebase
class RelayHistoryItem {
  final DateTime waktu;
  final String aksi;
  final String mode;

  RelayHistoryItem({
    required this.waktu,
    required this.aksi,
    required this.mode,
  });

  factory RelayHistoryItem.fromJson(Map<dynamic, dynamic> json) {
    // Firmware sends: {aksi:"ON/OFF", mode:"MANUAL/AUTO", epoch:<unix>, ts:<firebase_timestamp_ms>}
    // Gunakan 'ts' (Firebase server timestamp) sebagai waktu utama, fallback ke 'epoch' jika tidak ada
    int timestamp = json['ts'] ?? json['epoch'] ?? 0;
    return RelayHistoryItem(
      waktu: DateTime.fromMillisecondsSinceEpoch(timestamp),
      aksi: json['aksi'] ?? 'OFF',
      mode: json['mode'] ?? 'AUTO',
    );
  }
}

/// Telemetri angin dari Firebase (rekap 5 menitan)
class TelemetryItem {
  final DateTime waktu;
  final double kecepatan;

  TelemetryItem({
    required this.waktu,
    required this.kecepatan,
  });

  factory TelemetryItem.fromJson(Map<dynamic, dynamic> json) {
    // Firmware sends: {avg:<float>, max:<float>, ts:<firebase_timestamp_ms>}
    // Gunakan 'avg' sebagai kecepatan rata-rata 5 menitan
    return TelemetryItem(
      waktu: DateTime.fromMillisecondsSinceEpoch(json['ts'] ?? 0),
      kecepatan: (json['avg'] ?? 0).toDouble(),
    );
  }
}
