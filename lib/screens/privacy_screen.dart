import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  _PrivacyScreenState createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _locationAccessEnabled = true;
  bool _dataSharingEnabled = false;
  bool _personalizedAdsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPrivacySetting(
              'Location Access',
              _locationAccessEnabled,
              (value) {
                setState(() {
                  _locationAccessEnabled = value;
                });
              },
            ),
            _buildPrivacySetting(
              'Data Sharing',
              _dataSharingEnabled,
              (value) {
                setState(() {
                  _dataSharingEnabled = value;
                });
              },
            ),
            _buildPrivacySetting(
              'Personalized Ads',
              _personalizedAdsEnabled,
              (value) {
                setState(() {
                  _personalizedAdsEnabled = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySetting(
      String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
