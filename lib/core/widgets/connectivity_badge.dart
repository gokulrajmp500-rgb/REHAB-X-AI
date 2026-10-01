import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppConnectionState {
  online,
  offline,
  aiUnavailable,
}

class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({
    super.key,
    this.state = AppConnectionState.offline,
    this.compact = false,
  });

  final AppConnectionState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (state) {
      AppConnectionState.online => ('ONLINE', AppColors.green, Icons.wifi),
      AppConnectionState.offline => ('OFFLINE MODE', AppColors.muted, Icons.wifi_off),
      AppConnectionState.aiUnavailable => ('AI UNAVAILABLE', AppColors.orange, Icons.cloud_off),
    };

    if (compact) {
      return Tooltip(
        message: label,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(120),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
