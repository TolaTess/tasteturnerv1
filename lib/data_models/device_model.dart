// import '../constants.dart';

// class Device {
//   final String id;
//   final String userId;
//   final String name;
//   final String type;
//   final String? imageUrl;
//   final Map<String, dynamic>? settings;
//   final bool isConnected;
//   final DateTime lastSync;
//   final DateTime createdAt;
//   final DateTime updatedAt;

//   Device({
//     required this.id,
//     required this.userId,
//     required this.name,
//     required this.type,
//     this.imageUrl = intPlaceholderImage,
//     this.settings,
//     this.isConnected = false,
//     required this.lastSync,
//     required this.createdAt,
//     required this.updatedAt,
//   });

//   // ... existing code ...
// }

// // ... existing code ...

// List<Device> demoDevices = [
//   Device(
//     id: '1',
//     userId: '1',
//     name: 'Apple Watch Series 6',
//     type: 'smartwatch',
//     imageUrl: intPlaceholderImage,
//     settings: {   
//       'heartRate': true,
//       'steps': true,
//       'workouts': true,
//     },
//     isConnected: true,
//     lastSync: DateTime.now(),
//     createdAt: DateTime.now(),
//     updatedAt: DateTime.now(),
//   ),
//   Device(
//     id: '2',
//     userId: '1',
//     name: 'Fitbit Charge 4',
//     type: 'fitness_tracker',
//     imageUrl: intPlaceholderImage,
//     settings: {
//       'heartRate': true,
//       'steps': true,
//       'sleep': true,
//     },
//     isConnected: false,
//     lastSync: DateTime.now().subtract(const Duration(days: 1)),
//     createdAt: DateTime.now(),
//     updatedAt: DateTime.now(),
//   ),
// ];
