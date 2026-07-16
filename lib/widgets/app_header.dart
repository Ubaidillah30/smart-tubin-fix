import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header aplikasi dengan status online dan toggle tema
class AppHeader extends StatelessWidget {
  final bool online;
  final bool mqttConnected;
  final bool isDark;
  final VoidCallback onToggleTheme;

  const AppHeader({
    super.key,
    required this.online,
    this.mqttConnected = false,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final txtPrimary = isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final bgCard = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo/Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.wind_power,
              color: AppColors.accentGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Title dan Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Turbin',
                  style: TextStyle(
                    color: txtPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                // Row status wrapped in FittedBox biar nggak overflow
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      // Dashboard status
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: mqttConnected ? AppColors.accentGreen : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        mqttConnected ? "Online" : "Offline",
                        style: TextStyle(
                          color: mqttConnected ? AppColors.accentGreen : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ESP32 status
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: online ? AppColors.accentGreen : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ESP: ${online ? "On" : "Off"}',
                        style: TextStyle(
                          color: online ? AppColors.accentGreen : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Theme Toggle Button
          IconButton(
            onPressed: onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: txtPrimary,
            ),
            tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
          ),
        ],
      ),
    );
  }
}
