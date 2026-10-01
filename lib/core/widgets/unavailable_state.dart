import 'package:flutter/material.dart';

import '../../main.dart';

class UnavailableState extends StatelessWidget {
  const UnavailableState({super.key, required this.title, required this.message, this.icon = Icons.info_outline});
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => GlassCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: AppColors.orange), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(message)])),
  ]));
}