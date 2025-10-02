import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../service/hybrid_notification_service.dart';
import '../constants.dart';
import '../helper/utils.dart';

class TestNotificationsScreen extends StatefulWidget {
  const TestNotificationsScreen({super.key});

  @override
  State<TestNotificationsScreen> createState() =>
      _TestNotificationsScreenState();
}

class _TestNotificationsScreenState extends State<TestNotificationsScreen> {
  final HybridNotificationService _hybridNotificationService =
      Get.find<HybridNotificationService>();

  String _fcmToken = 'Not available';
  bool _isLoading = false;
  List<Map<String, dynamic>> _notificationHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _fcmToken = _hybridNotificationService.getFCMToken() ?? 'Not available';
    });

    _loadNotificationHistory();
  }

  Future<void> _loadNotificationHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history =
          await _hybridNotificationService.getNotificationHistory(limit: 10);
      setState(() {
        _notificationHistory = history;
      });
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to load notification history: $e',
          context,
          backgroundColor: kRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First check if we have an FCM token
      final fcmToken = _hybridNotificationService.getFCMToken();
      if (fcmToken == null) {
        if (mounted) {
          showTastySnackbar(
            'No FCM Token',
            'FCM token not available. Try running the debug tool first.',
            context,
            backgroundColor: Colors.orange,
          );
        }
        return;
      }

      print('🔔 Sending test notification...');
      print('🔑 FCM Token: ${fcmToken.substring(0, 20)}...');

      print('🧪 Sending test notification via hybrid service...');
      await _hybridNotificationService.sendTestNotification();
      print('✅ Test notification sent successfully');

      if (mounted) {
        showTastySnackbar(
          'Test Notification Sent',
          'Check your device for the test notification!',
          context,
          backgroundColor: kGreen,
        );
      }

      // Refresh notification history
      _loadNotificationHistory();
    } catch (e) {
      print('❌ Test notification error: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to send test notification: $e',
          context,
          backgroundColor: kRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forceFCMToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Forcing FCM token generation...');
      await _hybridNotificationService.forceFCMTokenGeneration();

      // Refresh the FCM token display
      setState(() {
        _fcmToken = _hybridNotificationService.getFCMToken() ?? 'Not available';
      });

      if (mounted) {
        showTastySnackbar(
          'FCM Token Generation',
          'Attempted to generate FCM token. Check logs for details.',
          context,
          backgroundColor: kBlue,
        );
      }
    } catch (e) {
      print('❌ Force FCM token error: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to generate FCM token: $e',
          context,
          backgroundColor: kRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Test Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_active,
                              color: kPrimaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notification Status',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimaryColor,
                                  ),
                                ),
                                Text(
                                  'Platform: ${_hybridNotificationService.platform}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _hybridNotificationService.platform
                                  .contains('Android')
                              ? 'FCM Token:'
                              : 'Local Notifications:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _hybridNotificationService.platform
                                    .contains('Android')
                                ? _fcmToken
                                : 'iOS Local Notifications Active',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _hybridNotificationService
                                      .areNotificationsEnabled()
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _hybridNotificationService
                                      .areNotificationsEnabled()
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _hybridNotificationService
                                      .areNotificationsEnabled()
                                  ? 'Notifications Enabled'
                                  : 'Notifications Disabled',
                              style: TextStyle(
                                fontSize: 14,
                                color: _hybridNotificationService
                                        .areNotificationsEnabled()
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Test Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _testNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Send Test Notification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Force FCM Token Button (Android only)
                  if (_hybridNotificationService.platform.contains('Android'))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _forceFCMToken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '🔄 Force FCM Token Generation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

         
                  const SizedBox(height: 24),

                  // Notification History
                  Text(
                    'Recent Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_notificationHistory.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._notificationHistory.map((notification) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification['title'] ?? 'No Title',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification['body'] ?? 'No Body',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(notification['sentAt']),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: notification['status'] == 'sent'
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      notification['status'] ?? 'unknown',
                                      style: TextStyle(
                                        color: notification['status'] == 'sent'
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )),

                  const SizedBox(height: 16),

                  // Refresh Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loadData,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Refresh Data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown date';

    try {
      if (date is String) {
        final parsed = DateTime.parse(date);
        return '${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour}:${parsed.minute.toString().padLeft(2, '0')}';
      }
      return 'Invalid date';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
