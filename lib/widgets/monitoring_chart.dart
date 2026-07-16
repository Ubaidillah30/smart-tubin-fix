import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pilihan metrik untuk grafik -- dipetakan langsung ke field TurbinData yang
/// benar-benar ada di payload MQTT firmware (bukan field simulasi).
enum MetrikGrafik {
  teganganMasuk('Tegangan Masuk (Sumber)'),
  arusMasuk('Arus Masuk (Sumber)'),
  dayaMasukM('Power Masuk (Sumber)'),
  teganganKeluar('Tegangan Keluar (Beban)'),
  arusKeluar('Arus Keluar (Beban)'),
  dayaKeluar('Power Keluar (Beban)'),
  teganganBaterai('Tegangan Baterai'),
  anginS1('Angin Sensor 1'),
  anginS2('Angin Sensor 2'),
  anginS3('Angin Sensor 3');

  final String label;
  const MetrikGrafik(this.label);
}

class MonitoringChart extends StatelessWidget {
  final MetrikGrafik metrikTerpilih;
  final ValueChanged<MetrikGrafik> onMetrikChanged;
  final List<double> dataPoints;

  const MonitoringChart({
    super.key,
    required this.metrikTerpilih,
    required this.onMetrikChanged,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txtPrimary = dark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final txtSec = dark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final dropdownBg = dark ? AppColors.cardDarkAlt : const Color(0xFFEDF2F7);
    final gridColor = dark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    final spots = <FlSpot>[
      for (int i = 0; i < dataPoints.length; i++) FlSpot(i.toDouble(), dataPoints[i]),
    ];
    final maxY = dataPoints.isEmpty
        ? 10.0
        : (dataPoints.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1, double.infinity);

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
                  child: const Icon(Icons.show_chart, color: AppColors.accentGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('GRAFIK MONITORING',
                      style: TextStyle(
                          color: txtPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: dropdownBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<MetrikGrafik>(
                  value: metrikTerpilih,
                  isExpanded: true,
                  dropdownColor: dropdownBg,
                  style: TextStyle(color: txtPrimary),
                  icon: Icon(Icons.keyboard_arrow_down, color: txtSec),
                  items: MetrikGrafik.values
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.label, style: TextStyle(color: txtPrimary))))
                      .toList(),
                  onChanged: (m) {
                    if (m != null) onMetrikChanged(m);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: dataPoints.isEmpty
                  ? Center(
                      child: Text('Menunggu data...',
                          style: TextStyle(color: txtSec)),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY.toDouble(),
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: maxY / 4,
                          getDrawingHorizontalLine: (v) =>
                              FlLine(color: gridColor, strokeWidth: 1),
                          drawVerticalLine: false,
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              getTitlesWidget: (v, meta) => Text(
                                v.toStringAsFixed(0),
                                style: TextStyle(color: txtSec, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.accentGreen,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.accentGreen.withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
