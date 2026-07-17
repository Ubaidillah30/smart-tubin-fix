import 'package:firebase_database/firebase_database.dart';

import '../models/turbin_data.dart';

/// Membaca data dari Firebase RTDB: https://smart-turbin-default-rtdb.asia-southeast1.firebasedatabase.app/
///
/// PENTING (samakan dengan firmware, lihat komentar FIREBASE di file .ino):
/// - Firebase HANYA berisi "telemetry/{device}" (rekap angin 5 menitan, push key
///   otomatis per entri) dan "history/relay" (log perubahan relay, push key
///   otomatis juga). TIDAK ADA data power/baterai realtime di Firebase --
///   itu hanya lewat MQTT (lihat mqtt_service.dart).
/// - deviceId rekap angin: "ANEMO-001", "ANEMO-002", "ANEMO-003" (lihat loop()
///   firmware: pushToFirebase("ANEMO-001", ...) dst, urut S1/S2/S3).
class FirebaseService {
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  /// Histori relay, urut terbaru dulu, dibatasi [limit] entri terakhir.
  Stream<List<RelayHistoryItem>> historiRelay({int limit = 10}) {
    final query = _root.child('history/relay').limitToLast(limit);
    return query.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <RelayHistoryItem>[];
      final items = data.values
          .whereType<Map>()
          .map((e) => RelayHistoryItem.fromJson(e))
          .toList();
      items.sort((a, b) => b.waktu.compareTo(a.waktu));
      return items;
    });
  }

  /// Hapus history relay tertua jika total > [maxEntries].
  /// Konsep queue: FIFO — hapus entry paling lama sampai tersisa [maxEntries].
  Future<void> pruneRelayHistory({int maxEntries = 10}) async {
    final snapshot = await _root.child('history/relay').get();
    final data = snapshot.value;
    if (data == null || data is! Map) return;

    if (data.length <= maxEntries) return;

    // Sort entries by timestamp ascending (oldest first)
    final entries = data.entries.map((e) {
      final map = e.value as Map;
      final ts = map['ts'] ?? map['epoch'] ?? 0;
      return MapEntry(e.key, (ts as num).toInt());
    }).toList();
    entries.sort((a, b) => a.value.compareTo(b.value));

    // Delete oldest entries until only maxEntries remain
    final deleteCount = entries.length - maxEntries;
    final updates = <String, Object?>{};
    for (int i = 0; i < deleteCount; i++) {
      updates['history/relay/${entries[i].key}'] = null;
    }
    await _root.update(updates);
  }

  /// Rekap kecepatan angin 5 menitan untuk 1 sensor.
  /// [deviceId] = "ANEMO-001" (S1) / "ANEMO-002" (S2) / "ANEMO-003" (S3).
  Stream<List<TelemetryItem>> telemetryAngin(String deviceId,
      {int limit = 50}) {
    final query = _root.child('telemetry/$deviceId').limitToLast(limit);
    return query.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <TelemetryItem>[];
      final items =
          data.values.whereType<Map>().map((e) => TelemetryItem.fromJson(e)).toList();
      items.sort((a, b) => a.waktu.compareTo(b.waktu));
      return items;
    });
  }
}
