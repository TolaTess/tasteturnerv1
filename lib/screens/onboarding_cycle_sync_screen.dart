import 'package:flutter/material.dart';

import '../constants.dart';

// NOTE: This file is intentionally lightweight. The main onboarding logic and
// state live in `onboarding_screen.dart`. This widget exists only to keep the
// UI for the cycle syncing slide structured if we ever want to reuse it.

class OnboardingCycleSyncScreen extends StatelessWidget {
  final bool isDarkMode;
  final bool isEnabled;
  final DateTime? lastPeriodStart;
  final TextEditingController cycleLengthController;
  final VoidCallback onToggle;
  final VoidCallback onPickDate;

  const OnboardingCycleSyncScreen({
    super.key,
    required this.isDarkMode,
    required this.isEnabled,
    required this.lastPeriodStart,
    required this.cycleLengthController,
    required this.onToggle,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support Your Cycle',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'If you have a cycle, I\'ll gently modify the daily specials to match your body\'s rhythm adding extra fuel when you need energy, and comfort foods when you need recovery.',
          style: textTheme.bodyMedium?.copyWith(    
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Enable cycle syncing for my cycle',
                style: textTheme.bodyMedium,
              ),
            ),
            Switch(
              activeColor: kAccent,
              activeTrackColor: kAccent.withValues(alpha: 0.5),
              value: isEnabled,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
        if (isEnabled) ...[
          const SizedBox(height: 16),
          Text(
            'Last period start date',
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onPickDate,
            child: Text(
              style: const TextStyle(color: kAccent),
              lastPeriodStart != null
                  ? '${lastPeriodStart!.day.toString().padLeft(2, '0')}-'
                      '${lastPeriodStart!.month.toString().padLeft(2, '0')}-'
                      '${lastPeriodStart!.year}'
                  : 'Select date',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Typical cycle length (days)',
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: cycleLengthController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Usually between 21 and 40 days',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}


