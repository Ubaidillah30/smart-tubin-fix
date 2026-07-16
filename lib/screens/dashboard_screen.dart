import 'package:flutter/material.dart';

import '../models/turbin_data.dart';
import '../services/mqtt_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/battery_gauge.dart';
import '../widgets/monitoring_chart.dart';
import '../widgets/power_card.dart';
import '../widgets/relay_card.dart';
import '../widgets/wind_card.dart';
import 'history_jadwal_screen.dart';

class DashboardScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const DashboardScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MqttService _mqtt = MqttService();

  TurbinData _data = TurbinData.kosong();
  bool _online = false;
  int _tabIndex = 0;

  MetrikGrafik _metrik = MetrikGrafik.teganganMasuk;
  final List<double> _bufferGrafik = [];
  static const int _maxBufferPoint = 60; // ~2 menit data (interval 2 detik)

  @override
  void initState() {
    super.initState();
    _mqtt.statusStream.listen((status) {
      if (mounted) setState(() => _online = status);
    });
    _mqtt.dataStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _data = data;
        _bufferGrafik.add(_nilaiUntukMetrik(data, _metrik));
        if (_bufferGrafik.length > _maxBufferPoint) {
          _bufferGrafik.removeAt(0);
        }
      });
    });
    _mqtt.connect();
  }

  double _nilaiUntukMetrik(TurbinData d, MetrikGrafik m) {
    switch (m) {
      case MetrikGrafik.teganganMasuk:
        return d.dayaMasuk.tegangan;
      case MetrikGrafik.arusMasuk:
        return d.dayaMasuk.arus;
      case MetrikGrafik.dayaMasukM:
        return d.dayaMasuk.daya;
      case MetrikGrafik.teganganKeluar:
        return d.dayaKeluar.tegangan;
      case MetrikGrafik.arusKeluar:
        return d.dayaKeluar.arus;
      case MetrikGrafik.dayaKeluar:
        return d.dayaKeluar.daya;
      case MetrikGrafik.teganganBaterai:
        return d.teganganBaterai;
      case MetrikGrafik.anginS1:
        return d.anginS1;
      case MetrikGrafik.anginS2:
        return d.anginS2;
      case MetrikGrafik.anginS3:
        return d.anginS3;
    }
  }

  void _gantiMetrik(MetrikGrafik m) {
    // Buffer grafik direset karena riwayat lama tidak relevan untuk metrik baru
    // (app hanya menyimpan buffer realtime di memory, bukan histori per-metrik).
    setState(() {
      _metrik = m;
      _bufferGrafik.clear();
    });
  }

  void _kirimPerintahRelay(String perintah) {
    setState(() {
      if (perintah == 'ON') {
        _data = _data.copyWith(relayOn: true, relayMode: 'MANUAL_ON');
      } else if (perintah == 'OFF') {
        _data = _data.copyWith(relayOn: false, relayMode: 'MANUAL_OFF');
      } else if (perintah == 'AUTO') {
        _data = _data.copyWith(relayMode: 'AUTO');
      }
    });
    _mqtt.setRelay(perintah);
  }

  @override
  void dispose() {
    _mqtt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tabIndex,
          children: [
            _buildDashboardTab(),
            HistoryJadwalScreen(
              online: _online,
              isDark: widget.isDark,
              onToggleTheme: widget.onToggleTheme,
              jadwalSaatIni: _data.jadwal,
              onSimpanJadwal: (slots) => _mqtt.setJadwal(slots),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: AppColors.bgDark,
        selectedItemColor: AppColors.accentGreen,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'History & Jadwal'),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppHeader(
          online: _online,
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              WindCard(s1: _data.anginS1, s2: _data.anginS2, s3: _data.anginS3),
              const SizedBox(height: 14),
              PowerCard(
                title: 'ENERGI MASUK (SUMBER)',
                icon: Icons.wind_power,
                tegangan: _data.dayaMasuk.tegangan,
                arus: _data.dayaMasuk.arus,
                daya: _data.dayaMasuk.daya,
              ),
              const SizedBox(height: 14),
              PowerCard(
                title: 'ENERGI KELUAR (BEBAN)',
                icon: Icons.electrical_services,
                tegangan: _data.dayaKeluar.tegangan,
                arus: _data.dayaKeluar.arus,
                daya: _data.dayaKeluar.daya,
              ),
              const SizedBox(height: 14),
              _buildKartuBaterai(),
              const SizedBox(height: 14),
              RelayCard(
                relayOn: _data.relayOn,
                mode: _data.relayMode,
                onPilihMode: _kirimPerintahRelay,
              ),
              const SizedBox(height: 14),
              MonitoringChart(
                metrikTerpilih: _metrik,
                onMetrikChanged: _gantiMetrik,
                dataPoints: _bufferGrafik,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKartuBaterai() {
    final dark = widget.isDark;
    final txtPrimary = dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            BatteryGauge(persen: _data.persenBaterai.round()),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BATERAI',
                      style: TextStyle(
                          color: txtPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text('${_data.teganganBaterai.toStringAsFixed(2)} V',
                      style: TextStyle(
                          color: txtPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _data.statusBaterai,
                      style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
