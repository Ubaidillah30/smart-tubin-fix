import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/turbin_data.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

const int _kMaxSlot = 10; // HARUS sinkron dengan JUMLAH_SLOT_JADWAL di firmware (10)

class HistoryJadwalScreen extends StatefulWidget {
  final bool online;
  final bool mqttConnected;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final List<JadwalSlot> jadwalSaatIni;
  final void Function(List<Map<String, dynamic>> slots) onSimpanJadwal;

  const HistoryJadwalScreen({
    super.key,
    required this.online,
    this.mqttConnected = false,
    required this.isDark,
    required this.onToggleTheme,
    required this.jadwalSaatIni,
    required this.onSimpanJadwal,
  });

  @override
  State<HistoryJadwalScreen> createState() => _HistoryJadwalScreenState();
}

class _HistoryJadwalScreenState extends State<HistoryJadwalScreen> {
  final FirebaseService _fb = FirebaseService();
  bool _tabHistory = true;

  late List<JadwalSlot> _slotLokal;

  @override
  void initState() {
    super.initState();
    _slotLokal = _hanyaAktif(widget.jadwalSaatIni);
  }

  @override
  void didUpdateWidget(covariant HistoryJadwalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jadwalSaatIni != widget.jadwalSaatIni) {
      setState(() => _slotLokal = _hanyaAktif(widget.jadwalSaatIni));
    }
  }

  List<JadwalSlot> _hanyaAktif(List<JadwalSlot> src) {
    return src
        .where((s) => s.aktif && s.mulai != '00:00' && s.selesai != '00:00')
        .toList();
  }

  /// Helper: parse "YYYY-MM-DD HH:MM" -> DateTime, atau null
  DateTime? _parseWaktu(String str) {
    try {
      if (str.length >= 16 && str.contains('-')) {
        return DateTime.parse(str.replaceAll(' ', 'T'));
      }
      // format "HH:MM" saja -> pakai hari ini
      final parts = str.split(':');
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  /// Format DateTime -> "YYYY-MM-DD HH:MM"
  String _formatWaktu(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Dialog date + time picker untuk mulai dan selesai
  Future<MapEntry<String, String>?> _tampilkanDialogEditor(
      JadwalSlot? slotLama) {
    DateTime? mulai = slotLama != null
        ? _parseWaktu(slotLama.mulai) ?? DateTime.now()
        : null;
    DateTime? selesai = slotLama != null
        ? _parseWaktu(slotLama.selesai) ?? DateTime.now().add(const Duration(hours: 1))
        : null;

    final dark = widget.isDark;
    final bg = dark ? AppColors.cardDark : Colors.white;
    final txtPrimary = dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final txtSec = dark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return showDialog<MapEntry<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final valid = mulai != null && selesai != null;

            Widget tombolDateTime(String label, DateTime? nilai,
                VoidCallback onTap) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: txtSec,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      foregroundColor: AppColors.accentGreen,
                      side: BorderSide(
                          color: AppColors.accentGreen.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      nilai == null
                          ? 'Pilih Tanggal & Jam'
                          : '${DateFormat('dd MMM HH:mm').format(nilai)}',
                      style: TextStyle(
                          color: txtPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    onPressed: onTap,
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                slotLama == null ? 'Tambah Jadwal Baru' : 'Edit Jadwal',
                style: TextStyle(
                    color: txtPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tombolDateTime('WAKTU MULAI', mulai, () async {
                    final dt = await _pilihDateTime(
                        context, mulai ?? DateTime.now(), 'Pilih Waktu Mulai');
                    if (dt != null) setDialogState(() => mulai = dt);
                  }),
                  const SizedBox(height: 16),
                  tombolDateTime('WAKTU SELESAI', selesai, () async {
                    final dt = await _pilihDateTime(
                        context,
                        selesai ?? DateTime.now().add(const Duration(hours: 1)),
                        'Pilih Waktu Selesai');
                    if (dt != null) setDialogState(() => selesai = dt);
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal',
                      style: TextStyle(color: AppColors.danger)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: Colors.black87,
                    disabledBackgroundColor:
                        AppColors.accentGreen.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: valid
                      ? () => Navigator.pop(context,
                          MapEntry(_formatWaktu(mulai!), _formatWaktu(selesai!)))
                      : null,
                  child: const Text('Simpan',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Date picker lalu time picker, return DateTime gabungan
  Future<DateTime?> _pilihDateTime(
      BuildContext context, DateTime initial, String title) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: title,
    );
    if (date == null) return null;

    if (!context.mounted) return date;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: title,
    );
    if (time == null) return date;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppHeader(
          online: widget.online,
          mqttConnected: widget.mqttConnected,
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildSwitchTab(),
              const SizedBox(height: 14),
              _tabHistory ? _buildHistoryList() : _buildJadwalEditor(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTab() {
    final dark = widget.isDark;

    Widget tombol(String label, bool aktif, VoidCallback onTap) {
      final inactiveBg =
          dark ? AppColors.cardDark : const Color(0xFFEDF2F7);
      final inactiveTxt =
          dark ? AppColors.textSecondary : AppColors.textSecondaryLight;
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: aktif ? AppColors.accentGreen : inactiveBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    color: aktif ? Colors.black87 : inactiveTxt,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return Row(
      children: [
        tombol('HISTORY', _tabHistory,
            () => setState(() => _tabHistory = true)),
        const SizedBox(width: 10),
        tombol('JADWAL', !_tabHistory,
            () => setState(() => _tabHistory = false)),
      ],
    );
  }

  // =========================================================
  // ── History Tab ──
  // =========================================================
  Widget _buildHistoryList() {
    return StreamBuilder<List<RelayHistoryItem>>(
      stream: _fb.historiRelay(),
      builder: (context, snapshot) {
        final dark = widget.isDark;
        final txtPrimary =
            dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
        final txtSec =
            dark ? AppColors.textSecondary : AppColors.textSecondaryLight;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt,
                          color: AppColors.accentGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('RIWAYAT RELAY',
                        style: TextStyle(
                            color: txtPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                if (!snapshot.hasData)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accentGreen)),
                  )
                else if (snapshot.data!.isEmpty)
                  Text('Belum ada riwayat.', style: TextStyle(color: txtSec))
                else
                  ...snapshot.data!.map((item) => _buildHistoryRow(item, dark)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryRow(RelayHistoryItem item, bool dark) {
    final formatter = DateFormat('dd MMM yyyy, HH:mm');
    final nyala = item.aksi == 'ON';
    final txtPrimary =
        dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final txtSec =
        dark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: nyala ? AppColors.accentGreen : AppColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${item.aksi} · ${item.mode}',
                style: TextStyle(
                    color: txtPrimary, fontWeight: FontWeight.w600)),
          ),
          Text(formatter.format(item.waktu),
              style: TextStyle(color: txtSec, fontSize: 12)),
        ],
      ),
    );
  }

  // =========================================================
  // ── Jadwal Tab ──
  // =========================================================
  Widget _buildJadwalEditor() {
    final dark = widget.isDark;
    final txtPrimary =
        dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final txtSec =
        dark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final bisaTambah = _slotLokal.length < _kMaxSlot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule,
                      color: AppColors.accentGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'JADWAL RELAY (${_slotLokal.length}/$_kMaxSlot)',
                      style: TextStyle(
                          color: txtPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
                if (bisaTambah)
                  TextButton.icon(
                    onPressed: _tambahSlot,
                    icon: const Icon(Icons.add,
                        size: 18, color: AppColors.accentGreen),
                    label: const Text('Tambah',
                        style: TextStyle(color: AppColors.accentGreen)),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Maks. $_kMaxSlot jadwal tersimpan di firmware.',
              style: TextStyle(color: txtSec, fontSize: 11),
            ),
            const SizedBox(height: 14),

            if (_slotLokal.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Belum ada jadwal.\nTekan "+ Tambah" untuk membuat jadwal baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: txtSec, fontSize: 13),
                  ),
                ),
              )
            else
              for (int i = 0; i < _slotLokal.length; i++)
                _buildSlotRow(i, _slotLokal[i], dark),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotRow(int index, JadwalSlot slot, bool dark) {
    final bgCard =
        dark ? AppColors.cardDarkAlt : const Color(0xFFEDF2F7);
    final txtPrimary =
        dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final txtSec =
        dark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: slot.aktif
              ? AppColors.accentGreen.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('${index + 1}',
                style: const TextStyle(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mulai: ${slot.mulai}',
                    style: TextStyle(
                        color: txtPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('Selesai: ${slot.selesai}',
                    style: TextStyle(color: txtSec, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: AppColors.accentGreen, size: 20),
            tooltip: 'Edit waktu',
            onPressed: () => _editWaktuSlot(index, slot),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: AppColors.danger, size: 20),
            tooltip: 'Hapus jadwal',
            onPressed: () => _hapusSlot(index),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ── Actions ──
  // =========================================================
  void _tambahSlot() async {
    final hasil = await _tampilkanDialogEditor(null);
    if (hasil == null || !mounted) return;

    setState(() {
      _slotLokal = [
        ..._slotLokal,
        JadwalSlot(mulai: hasil.key, selesai: hasil.value, aktif: true),
      ];
    });
    _kirimSemuaSlot();
  }

  Future<void> _editWaktuSlot(int index, JadwalSlot slot) async {
    final hasil = await _tampilkanDialogEditor(slot);
    if (hasil == null || !mounted) return;

    setState(() {
      final updated = List<JadwalSlot>.from(_slotLokal);
      updated[index] = JadwalSlot(
          mulai: hasil.key, selesai: hasil.value, aktif: slot.aktif);
      _slotLokal = updated;
    });
    _kirimSemuaSlot();
  }

  void _hapusSlot(int index) {
    setState(() {
      final updated = List<JadwalSlot>.from(_slotLokal);
      updated.removeAt(index);
      _slotLokal = updated;
    });
    _kirimSemuaSlot();
  }

  /// Kirim semua slot ke firmware via MQTT. Format dengan tanggal penuh.
  void _kirimSemuaSlot() {
    final payload = <Map<String, dynamic>>[];
    for (int i = 0; i < _kMaxSlot; i++) {
      if (i < _slotLokal.length) {
        final s = _slotLokal[i];
        payload.add({'mulai': s.mulai, 'selesai': s.selesai, 'aktif': true});
      } else {
        payload.add(
            {'mulai': '00:00', 'selesai': '00:00', 'aktif': false});
      }
    }
    widget.onSimpanJadwal(payload);
  }
}