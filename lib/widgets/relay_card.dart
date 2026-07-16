import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RelayCard extends StatelessWidget {
  final bool relayOn;
  final String mode; // AUTO | MANUAL_ON | MANUAL_OFF
  final void Function(String perintah) onPilihMode; // "AUTO" | "ON" | "OFF"

  const RelayCard({
    super.key,
    required this.relayOn,
    required this.mode,
    required this.onPilihMode,
  });

  bool get _isJadwal => mode == 'AUTO';
  bool get _isManual => mode == 'MANUAL_ON' || mode == 'MANUAL_OFF';

  Widget _modeChip(
    BuildContext context,
    String label,
    bool aktif,
    IconData icon,
    VoidCallback onTap,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.accentGreen;
    final inactiveBg = dark ? AppColors.cardDarkAlt : const Color(0xFFEDF2F7);
    final inactiveTxt = dark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: aktif ? activeColor : inactiveBg,
            borderRadius: BorderRadius.circular(12),
            border: aktif
                ? Border.all(color: AppColors.accentGreenDark, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: aktif ? Colors.black87 : inactiveTxt,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: aktif ? Colors.black87 : inactiveTxt,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final subtitleColor = dark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final dividerColor =
        dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.power_settings_new,
                          color: AppColors.accentGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('KONTROL RELAY',
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (relayOn ? AppColors.accentGreen : AppColors.danger)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    relayOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: relayOn ? AppColors.accentGreen : AppColors.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Pilih Mode ──
            Text('MODE', style: TextStyle(color: subtitleColor, fontSize: 11, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Row(
              children: [
                _modeChip(context, 'Jadwal', _isJadwal, Icons.schedule,
                    () => onPilihMode('AUTO')),
                _modeChip(context, 'Manual', _isManual, Icons.touch_app,
                    () {
                  // Masuk manual, pertahankan state relay saat ini
                  onPilihMode(relayOn ? 'ON' : 'OFF');
                }),
              ],
            ),

            // ── Switch ON/OFF (hanya muncul di mode Manual) ──
            if (_isManual) ...[
              Divider(height: 24, color: dividerColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status Relay',
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Text(
                        relayOn ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: relayOn ? AppColors.accentGreen : subtitleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Switch(
                        value: relayOn,
                        onChanged: (v) => onPilihMode(v ? 'ON' : 'OFF'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
