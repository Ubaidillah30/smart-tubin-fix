import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PowerCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double tegangan;
  final double arus;
  final double daya;

  const PowerCard({
    super.key,
    required this.title,
    required this.icon,
    required this.tegangan,
    required this.arus,
    required this.daya,
  });

  Widget _kolom(BuildContext context, String label, String nilai,
      {Color? warna}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txtPrimary =
        dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final txtSec = dark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: txtSec, fontSize: 13)),
        const SizedBox(height: 4),
        Text(nilai,
            style: TextStyle(
                color: warna ?? txtPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ],
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
                  child: Icon(icon, color: AppColors.accentGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: TextStyle(
                        color: txtPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _kolom(context, 'Tegangan', '${tegangan.toStringAsFixed(1)} V'),
                _kolom(context, 'Arus', '${arus.toStringAsFixed(2)} A'),
                _kolom(context, 'Daya', '${daya.toStringAsFixed(0)} W',
                    warna: AppColors.accentGreen),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
