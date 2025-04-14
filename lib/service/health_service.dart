import 'package:health/health.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';

class HealthService extends GetxController {
  static HealthService instance = Get.find();
  final Health health = Health(); // Updated to Health()

  final RxBool isAuthorized = false.obs;
  final RxInt steps = 0.obs;
  final RxBool isSyncing = false.obs;

  // Required health data types
  static final List<HealthDataType> types = [
    HealthDataType.STEPS,
    // Add more types as needed
  ];

  // Required health data access permissions
  static final List<HealthDataAccess> permissions = [
    HealthDataAccess.READ,
  ];

  // Initialize health service
  Future<bool> initializeHealth() async {
    try {
      final granted = await health.requestAuthorization(types);
      if (!granted) {
        throw Exception('Health data access not authorized');
      }

      // Types are already defined in the class constructor/initialization
      await _initializeHealthConnect();
      return granted;
    } catch (e) {
      print('Error initializing health service: $e');
      throw Exception('Failed to initialize health service: $e');
    }
  }

  Future<void> _initializeHealthConnect() async {
    try {
      // Platform-specific health connect initialization if needed
    } catch (e) {
      print('Error initializing health connect: $e');
    }
  }

  // Sync health data
  Future<void> syncHealthData(String userId) async {
    if (userId.isEmpty) {
      print('Invalid user ID for health data sync');
      return;
    }

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      List<HealthDataPoint> healthData = [];

      for (HealthDataType type in types) {
        try {
          final typeData = await health.getHealthDataFromTypes(
            startTime: midnight,
            endTime: now,
            types: [type],
          );
          healthData.addAll(typeData);
        } catch (e) {
          print('Error fetching $type data: $e');
          continue;
        }
      }

      if (healthData.isEmpty) {
        print('No health data available for sync');
        return;
      }

      final batch = firestore.batch();
      final userRef = firestore.collection('users').doc(userId);
      final healthRef =
          userRef.collection('health_data').doc(midnight.toIso8601String());

      final Map<String, dynamic> healthMetrics = {
        'date': midnight.toIso8601String(),
        'steps': 0,
        'calories': 0.0,
        'distance': 0.0,
      };

      for (var dataPoint in healthData) {
        try {
          switch (dataPoint.type) {
            case HealthDataType.STEPS:
              healthMetrics['steps'] = (healthMetrics['steps'] as num) +
                  (dataPoint.value as num).toInt();
              break;
            case HealthDataType.ACTIVE_ENERGY_BURNED:
              healthMetrics['calories'] = (healthMetrics['calories'] as num) +
                  (dataPoint.value as num).toDouble();
              break;
            case HealthDataType.DISTANCE_WALKING_RUNNING:
              healthMetrics['distance'] = (healthMetrics['distance'] as num) +
                  (dataPoint.value as num).toDouble();
              break;
            default:
              break;
          }
        } catch (e) {
          print('Error processing health data point: $e');
          continue;
        }
      }

      batch.set(healthRef, healthMetrics, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      print('Error syncing health data: $e');
      throw Exception('Failed to sync health data: $e');
    }
  }

  Future<Map<String, dynamic>> getHealthMetrics(
      String userId, DateTime date) async {
    if (userId.isEmpty) {
      print('Invalid user ID for health metrics');
      return {};
    }

    try {
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('health_data')
          .doc(date.toIso8601String());

      final doc = await docRef.get();
      if (!doc.exists) {
        return {};
      }

      final data = doc.data() as Map<String, dynamic>;
      return {
        'steps': (data['steps'] as num?)?.toInt() ?? 0,
        'calories': (data['calories'] as num?)?.toDouble() ?? 0.0,
        'distance': (data['distance'] as num?)?.toDouble() ?? 0.0,
        'date': data['date'] as String? ?? date.toIso8601String(),
      };
    } catch (e) {
      print('Error fetching health metrics: $e');
      return {};
    }
  }

  // Check if device supports health tracking
  Future<bool> isHealthDataAvailable() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (GetPlatform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Health app is available on iOS 8.0 and above
        return double.parse(iosInfo.systemVersion) >= 8.0;
      } else if (GetPlatform.isAndroid) {
        // Check if Google Fit is available
        return await health.hasPermissions(types, permissions: permissions) ??
            false;
      }
      return false;
    } catch (e) {
      print("Error checking health data availability: $e");
      return false;
    }
  }
}
