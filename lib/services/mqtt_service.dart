import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/turbin_data.dart';

/// Service untuk koneksi MQTT ke broker (data realtime dari ESP32)
class MqttService {
  // Konfigurasi broker MQTT - HARUS SAMA dengan firmware ESP32
  static const String _broker = 'broker.emqx.io'; // Sama dengan firmware
  static const int _port = 1883;
  static const String _clientId = 'smart_turbin_app';

  // Topics MQTT - HARUS SAMA dengan firmware ESP32
  static const String _topicData = 'turbin/data'; // ESP32 publish data ke sini (retained)
  static const String _topicRelaySet = 'turbin/relay/set'; // App publish perintah relay
  static const String _topicJadwalSet = 'turbin/relay/jadwal/set'; // App publish jadwal

  late MqttServerClient _client;

  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  final StreamController<TurbinData> _dataController = StreamController<TurbinData>.broadcast();

  /// Stream status koneksi (true = online, false = offline)
  Stream<bool> get statusStream => _statusController.stream;

  /// Stream data turbin realtime dari MQTT
  Stream<TurbinData> get dataStream => _dataController.stream;

  MqttService() {
    _client = MqttServerClient(_broker, _clientId);
    _client.port = _port;
    _client.keepAlivePeriod = 20;
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;
    _client.autoReconnect = true;
    _client.logging(on: false);

    // Protokol MQTT v3.1.1
    _client.setProtocolV311();
  }

  /// Koneksi ke broker MQTT
  Future<void> connect() async {
    try {
      await _client.connect();
    } catch (e) {
      print('MQTT connect error: $e');
      _client.disconnect();
      _statusController.add(false);
    }
  }

  void _onConnected() {
    print('MQTT connected to $_broker');
    _statusController.add(true);

    // Subscribe ke topic data dari ESP32
    _client.subscribe(_topicData, MqttQos.atLeastOnce);

    // Listen untuk pesan masuk
    _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final recMessage = message.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);

        if (message.topic == _topicData) {
          _parseDataMessage(payload);
        }
      }
    });
  }

  void _onDisconnected() {
    print('MQTT disconnected');
    _statusController.add(false);
  }

  void _onSubscribed(String topic) {
    print('MQTT subscribed to $topic');
  }

  /// Parse pesan JSON dari ESP32 menjadi TurbinData
  /// Format dari firmware: {angin:{s1,s2,s3}, daya:{masuk:{v,i,p}, keluar:{v,i,p}},
  /// baterai:{v,persen,status}, relay:{status,mode}, jadwal:[...]}
  void _parseDataMessage(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;

      // Konversi format firmware ke format model Flutter
      final angin = json['angin'] as Map<String, dynamic>? ?? {};
      final daya = json['daya'] as Map<String, dynamic>? ?? {};
      final masuk = daya['masuk'] as Map<String, dynamic>? ?? {};
      final keluar = daya['keluar'] as Map<String, dynamic>? ?? {};
      final baterai = json['baterai'] as Map<String, dynamic>? ?? {};
      final relay = json['relay'] as Map<String, dynamic>? ?? {};

      final convertedJson = {
        'anginS1': angin['s1'] ?? 0,
        'anginS2': angin['s2'] ?? 0,
        'anginS3': angin['s3'] ?? 0,
        'dayaMasuk': {
          'tegangan': masuk['v'] ?? 0,
          'arus': masuk['i'] ?? 0,
          'daya': masuk['p'] ?? 0,
        },
        'dayaKeluar': {
          'tegangan': keluar['v'] ?? 0,
          'arus': keluar['i'] ?? 0,
          'daya': keluar['p'] ?? 0,
        },
        'teganganBaterai': baterai['v'] ?? 0,
        'persenBaterai': baterai['persen'] ?? 0,
        'statusBaterai': baterai['status'] ?? 'Unknown',
        'relayOn': relay['status'] == 'ON',
        'relayMode': relay['mode'] ?? 'AUTO',
        'jadwal': json['jadwal'] ?? [],
      };

      final data = TurbinData.fromJson(convertedJson);
      _dataController.add(data);
    } catch (e) {
      print('Error parsing MQTT data: $e');
    }
  }

  /// Kirim perintah relay: "ON", "OFF", atau "AUTO"
  /// Firmware mengharapkan payload plain text, bukan JSON
  void setRelay(String perintah) {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      print('MQTT not connected, cannot send relay command');
      return;
    }

    // Firmware ESP32 expects plain text "ON", "OFF", or "AUTO"
    final builder = MqttClientPayloadBuilder();
    builder.addString(perintah);

    _client.publishMessage(
      _topicRelaySet,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    print('MQTT sent relay command: $perintah');
  }

  /// Kirim jadwal relay ke ESP32
  /// Firmware mengharapkan JSON array langsung: [{"mulai":"06:00","selesai":"09:00","aktif":true},...]
  void setJadwal(List<Map<String, dynamic>> slots) {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      print('MQTT not connected, cannot send jadwal');
      return;
    }

    // Firmware ESP32 expects JSON array directly, not wrapped in object
    final message = jsonEncode(slots);
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    _client.publishMessage(
      _topicJadwalSet,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    print('MQTT sent jadwal: ${slots.length} slots');
  }

  /// Cleanup saat service di-dispose
  void dispose() {
    _client.disconnect();
    _statusController.close();
    _dataController.close();
  }
}
