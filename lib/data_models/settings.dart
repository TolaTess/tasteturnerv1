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

List<Setting> demoSetting = [
  Setting(
    category: "Edit",
    prefixicon: Icons.person,
    suffixicon: Icons.navigate_next,
  ),
  Setting(
    category: "Nutrition & Goals",
    prefixicon: Icons.check,
    suffixicon: Icons.navigate_next,
  ),
  Setting(
    category: "Dark Mode",
    prefixicon: Icons.visibility,
  ),
  Setting(
    category: "Premium",
    prefixicon: Icons.payment,
    suffixicon: Icons.navigate_next,
  ),
  Setting(
    category: "Privacy & Security",
    prefixicon: Icons.lock,
    suffixicon: Icons.navigate_next,
  ),
  Setting(
    category: "Help & Support",
    prefixicon: Icons.headset_mic,
    suffixicon: Icons.navigate_next,
  ),
];
