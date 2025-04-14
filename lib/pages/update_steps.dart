import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import 'safe_text_field.dart';

class UpdateStepsModal extends StatefulWidget {
  final String title;
  final double total;
  final double current;
  final ValueNotifier<double> currentNotifier;
  final bool isHealthSynced;

  const UpdateStepsModal({
    super.key,
    required this.total,
    required this.current,
    required this.title,
    required this.isHealthSynced,
    required this.currentNotifier,
  });

  @override
  State<UpdateStepsModal> createState() => _UpdateStepsModalState();
}

class _UpdateStepsModalState extends State<UpdateStepsModal> {
  late ValueNotifier<double> currentNotifier;

  @override
  void initState() {
    super.initState();
    currentNotifier = ValueNotifier<double>(widget.current);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final TextEditingController stepsController =
        TextEditingController(text: widget.current.toInt().toString());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? kWhite : kDarkGrey,
            ),
          ),
          const SizedBox(height: 20),
          if (widget.isHealthSynced)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Steps are being automatically synced from your health app",
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            SafeTextField(
              controller: stepsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Enter steps",
                labelStyle: TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
                enabledBorder: outlineInputBorder(20),
                focusedBorder: outlineInputBorder(20),
              ),
              style: TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
            ),
          const SizedBox(height: 20),
          if (!widget.isHealthSynced)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: () async {
                final steps = int.tryParse(stepsController.text);
                if (steps != null) {
                  try {
                    nutritionController.updateCurrentSteps(
                        userService.userId ?? '', steps.toDouble());

                    Get.back();
                    Get.snackbar(
                        'Success', 'Your steps were updated successfully!',
                        snackPosition: SnackPosition.BOTTOM);
                  } catch (e) {
                    print("Error updating steps: $e");
                    Get.snackbar(
                      'Error',
                      'Failed to update steps',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                }
              },
              child: const Text(
                "Update Steps",
                style: TextStyle(
                  fontSize: 16,
                  color: kWhite,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
