import 'package:cloud_firestore/cloud_firestore.dart';

enum CyclePhase {
  follicular, // Days 1-13 (after period ends)
  ovulation,  // Days 14-16
  luteal,     // Days 17-28 (before period)
  menstrual,  // Days 1-5 (period)
}

class CycleData {
  final DateTime? lastPeriodStart;
  final int cycleLength; // Average cycle length in days (default: 28)
  final CyclePhase? currentPhase;
  final bool isEnabled;

  CycleData({
    this.lastPeriodStart,
    this.cycleLength = 28,
    this.currentPhase,
    this.isEnabled = false,
  });

  factory CycleData.fromMap(Map<String, dynamic> json) {
    CyclePhase? phase;
    if (json['currentPhase'] != null) {
      switch (json['currentPhase'].toString().toLowerCase()) {
        case 'follicular':
          phase = CyclePhase.follicular;
          break;
        case 'ovulation':
          phase = CyclePhase.ovulation;
          break;
        case 'luteal':
          phase = CyclePhase.luteal;
          break;
        case 'menstrual':
          phase = CyclePhase.menstrual;
          break;
      }
    }

    DateTime? lastPeriod;
    if (json['lastPeriodStart'] != null) {
      if (json['lastPeriodStart'] is Timestamp) {
        lastPeriod = (json['lastPeriodStart'] as Timestamp).toDate();
      } else if (json['lastPeriodStart'] is String) {
        lastPeriod = DateTime.tryParse(json['lastPeriodStart'] as String);
      }
    }

    return CycleData(
      lastPeriodStart: lastPeriod,
      cycleLength: (json['cycleLength'] as num?)?.toInt() ?? 28,
      currentPhase: phase,
      isEnabled: json['isEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (lastPeriodStart != null)
        'lastPeriodStart': Timestamp.fromDate(lastPeriodStart!),
      'cycleLength': cycleLength,
      if (currentPhase != null) 'currentPhase': currentPhase!.name,
      'isEnabled': isEnabled,
    };
  }

  CycleData copyWith({
    DateTime? lastPeriodStart,
    int? cycleLength,
    CyclePhase? currentPhase,
    bool? isEnabled,
  }) {
    return CycleData(
      lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
      cycleLength: cycleLength ?? this.cycleLength,
      currentPhase: currentPhase ?? this.currentPhase,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

