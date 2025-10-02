import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../service/cloud_notification_service.dart';
import '../constants.dart';
import '../helper/utils.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final CloudNotificationService _cloudNotificationService =
      Get.find<CloudNotificationService>();

  bool _mealPlanReminderEnabled = true;
  bool _waterReminderEnabled = true;
  bool _eveningReviewEnabled = true;

  TimeOfDay _mealPlanReminderTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _waterReminderTime = const TimeOfDay(hour: 11, minute: 0);
  TimeOfDay _eveningReviewTime = const TimeOfDay(hour: 21, minute: 0);

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final preferences = _cloudNotificationService.notificationPreferences;

    setState(() {
      _mealPlanReminderEnabled =
          preferences['mealPlanReminder']?['enabled'] ?? true;
      _waterReminderEnabled = preferences['waterReminder']?['enabled'] ?? true;
      _eveningReviewEnabled = preferences['eveningReview']?['enabled'] ?? true;

      // Load times (convert from 24-hour format)
      final mealPlanTime = preferences['mealPlanReminder']?['time'];
      if (mealPlanTime != null) {
        _mealPlanReminderTime = TimeOfDay(
          hour: mealPlanTime['hour'] ?? 21,
          minute: mealPlanTime['minute'] ?? 0,
        );
      }

      final waterTime = preferences['waterReminder']?['time'];
      if (waterTime != null) {
        _waterReminderTime = TimeOfDay(
          hour: waterTime['hour'] ?? 11,
          minute: waterTime['minute'] ?? 0,
        );
      }

      final eveningTime = preferences['eveningReview']?['time'];
      if (eveningTime != null) {
        _eveningReviewTime = TimeOfDay(
          hour: eveningTime['hour'] ?? 21,
          minute: eveningTime['minute'] ?? 0,
        );
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final preferences = {
        'mealPlanReminder': {
          'enabled': _mealPlanReminderEnabled,
          'time': {
            'hour': _mealPlanReminderTime.hour,
            'minute': _mealPlanReminderTime.minute,
          },
          'timezone': 'UTC'
        },
        'waterReminder': {
          'enabled': _waterReminderEnabled,
          'time': {
            'hour': _waterReminderTime.hour,
            'minute': _waterReminderTime.minute,
          },
          'timezone': 'UTC'
        },
        'eveningReview': {
          'enabled': _eveningReviewEnabled,
          'time': {
            'hour': _eveningReviewTime.hour,
            'minute': _eveningReviewTime.minute,
          },
          'timezone': 'UTC'
        }
      };

      await _cloudNotificationService
          .updateNotificationPreferences(preferences);

      if (mounted) {
        showTastySnackbar(
          'Settings Saved',
          'Your notification preferences have been updated',
          context,
          backgroundColor: kGreen,
        );
      }
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to save settings. Please try again.',
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

  Future<void> _selectTime(
      TimeOfDay currentTime, Function(TimeOfDay) onTimeSelected) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (picked != null && picked != currentTime) {
      onTimeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
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
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: kPrimaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cloud Notifications',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Notifications are sent from our servers for maximum reliability',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Meal Plan Reminder
                  _buildNotificationCard(
                    title: 'Meal Plan Reminder',
                    subtitle: 'Reminds you to plan meals for tomorrow',
                    icon: Icons.restaurant_menu,
                    enabled: _mealPlanReminderEnabled,
                    time: _mealPlanReminderTime,
                    onToggle: (value) {
                      setState(() {
                        _mealPlanReminderEnabled = value;
                      });
                    },
                    onTimeTap: () {
                      _selectTime(_mealPlanReminderTime, (time) {
                        setState(() {
                          _mealPlanReminderTime = time;
                        });
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Water Reminder
                  _buildNotificationCard(
                    title: 'Water Reminder',
                    subtitle: 'Reminds you to stay hydrated',
                    icon: Icons.water_drop,
                    enabled: _waterReminderEnabled,
                    time: _waterReminderTime,
                    onToggle: (value) {
                      setState(() {
                        _waterReminderEnabled = value;
                      });
                    },
                    onTimeTap: () {
                      _selectTime(_waterReminderTime, (time) {
                        setState(() {
                          _waterReminderTime = time;
                        });
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Evening Review
                  _buildNotificationCard(
                    title: 'Evening Review',
                    subtitle: 'Review your goals and plan for tomorrow',
                    icon: Icons.nightlight_round,
                    enabled: _eveningReviewEnabled,
                    time: _eveningReviewTime,
                    onToggle: (value) {
                      setState(() {
                        _eveningReviewEnabled = value;
                      });
                    },
                    onTimeTap: () {
                      _selectTime(_eveningReviewTime, (time) {
                        setState(() {
                          _eveningReviewTime = time;
                        });
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Settings',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Notifications are sent from our servers every 5 minutes. Times are in UTC.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool enabled,
    required TimeOfDay time,
    required Function(bool) onToggle,
    required VoidCallback onTimeTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? kPrimaryColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: enabled ? kPrimaryColor : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: enabled ? kPrimaryColor : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeColor: kPrimaryColor,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            InkWell(
              onTap: onTimeTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: kPrimaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Time: ${time.format(context)}',
                      style: TextStyle(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit,
                      color: kPrimaryColor,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
