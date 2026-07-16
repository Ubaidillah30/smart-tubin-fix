import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WindCard extends StatelessWidget {
  final double s1, s2, s3;

  const WindCard({super.key, required this.s1, required this.s2, required this.s3});

  Widget _sensor(BuildContext context, String label, double nilai) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txtPrimary = dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final txtSec = dark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: txtSec, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            nilai.toStringAsFixed(1),
            style: TextStyle(
                color: txtPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700),
          ),
          Text('m/s', style: TextStyle(color: txtSec, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txtPrimary = dark ? AppColors.textPrimary : AppColors.textPrimaryLight;

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
                  child: const Icon(Icons.air, color: AppColors.accentGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Text('KECEPATAN ANGIN',
                    style: TextStyle(
                        color: txtPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _sensor(context, 'Sensor 1', s1),
                _sensor(context, 'Sensor 2', s2),
                _sensor(context, 'Sensor 3', s3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
