import 'package:flutter/material.dart';

class Setting {
  final String category;
  final IconData? suffixicon;
  final IconData prefixicon;

  Setting({
    required this.category,
    this.suffixicon,
    required this.prefixicon,
  });
}

// Demo settings model
// IMPORTANT: Both "Dark Mode" and "Notifications" must always be listed separately
// They appear as toggle switches in the settings screen

List<Setting> demoSetting = [
  Setting(
    category: "Edit Station",
    prefixicon: Icons.person,
    suffixicon: Icons.navigate_next,
  ),
  Setting(
    category: "Edit Menu Specs",
    prefixicon: Icons.check,
    suffixicon: Icons.navigate_next,
  ),
  // Dark Mode toggle - always visible
  Setting(
    category: "Night Shift",
    prefixicon: Icons.visibility,
  ),
  // Notifications toggle - always visible
  Setting(
    category: "Reminders",
    prefixicon: Icons.notifications,
  ),
  Setting(
    category: "Executive Chef",
    prefixicon: Icons.payment,
    suffixicon: Icons.navigate_next,
  ),
  Setting(
    category: "Help Center",
    prefixicon: Icons.headset_mic,
    suffixicon: Icons.navigate_next,
  ),
];
