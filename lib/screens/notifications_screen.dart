// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';

// class NotificationsScreen extends StatefulWidget {
//   const NotificationsScreen({super.key});

//   @override
//   _NotificationsScreenState createState() => _NotificationsScreenState();
// }

// class _NotificationsScreenState extends State<NotificationsScreen> {
//   bool _pushNotificationsEnabled = true;
//   bool _emailNotificationsEnabled = false;
//   bool _inAppNotificationsEnabled = true;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Notifications'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             _buildNotificationSetting(
//               'Push Notifications',
//               _pushNotificationsEnabled,
//               (value) {
//                 setState(() {
//                   _pushNotificationsEnabled = value;
//                 });
//               },
//             ),
//             _buildNotificationSetting(
//               'Email Notifications',
//               _emailNotificationsEnabled,
//               (value) {
//                 setState(() {
//                   _emailNotificationsEnabled = value;
//                 });
//               },
//             ),
//              _buildNotificationSetting(
//               'In-App Notifications',
//               _inAppNotificationsEnabled,
//               (value) {
//                 setState(() {
//                   _inAppNotificationsEnabled = value;
//                 });
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNotificationSetting(
//       String title, bool value, ValueChanged<bool> onChanged) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(fontSize: 16),
//           ),
//           CupertinoSwitch(
//             value: value,
//             onChanged: onChanged,
//           ),
//         ],
//       ),
//     );
//   }
// }
