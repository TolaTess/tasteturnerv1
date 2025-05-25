import 'dart:async';
import 'package:flutter/material.dart';
import '../helper/utils.dart';

class Countdown extends StatefulWidget {
  final DateTime targetDate;

  const Countdown({super.key, required this.targetDate});

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final difference = widget.targetDate.difference(now);

    setState(() {
      _remainingTime = difference.isNegative ? Duration.zero : difference;
    });

    if (_remainingTime.inSeconds == 0) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours % 24;
    final minutes = _remainingTime.inMinutes % 60;
    final seconds = _remainingTime.inSeconds % 60;

    return Text(
      '$days days, ${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}',
      style: TextStyle(
        fontSize: getPercentageWidth(4, context),
        fontWeight: FontWeight.w500,
        color: Color(0xFFDF2D20),
      ),
    );
  }
}
