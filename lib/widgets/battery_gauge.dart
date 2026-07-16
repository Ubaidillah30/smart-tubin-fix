import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BatteryGauge extends StatelessWidget {
  final int persen;
  final double size;

  const BatteryGauge({super.key, required this.persen, this.size = 130});

  Color _warnaStatus() {
    if (persen >= 50) return AppColors.accentGreen;
    if (persen >= 20) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final trackColor = dark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.08);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (persen.clamp(0, 100)) / 100,
              strokeWidth: 8,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation(_warnaStatus()),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$persen%',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
