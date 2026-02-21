import 'package:flutter/material.dart';
import '../theme.dart';

class DateSeparator extends StatelessWidget {
  final String date;
  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: SignalColors.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            date,
            style: const TextStyle(
              color: SignalColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
