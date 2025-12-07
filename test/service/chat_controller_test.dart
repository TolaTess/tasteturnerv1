import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tasteturner/service/buddy_chat_controller.dart';

void main() {
  group('BuddyChatController Tests', () {
    late BuddyChatController chatController;

    setUp(() {
      // Initialize Get for testing
      Get.testMode = true;
      chatController = BuddyChatController();
      Get.put(chatController);
    });

    tearDown(() {
      Get.reset();
    });

    test('Initial state is correct', () {
      expect(chatController.currentMode.value, 'sous chef');
      expect(chatController.showForm.value, false);
      expect(chatController.isFormSubmitted.value, false);
      expect(chatController.messages.length, 0);
      expect(chatController.isResponding.value, false);
    });

    test('Welcome messages are populated', () {
      expect(chatController.tastyWelcomeMessages, isNotEmpty);
      expect(chatController.mealPlanWelcomeMessages, isNotEmpty);
      expect(chatController.tastyWelcomeMessages.length, greaterThan(0));
      expect(chatController.mealPlanWelcomeMessages.length, greaterThan(0));
    });

    test('Planning form state updates', () {
      chatController.showForm.value = true;
      expect(chatController.showForm.value, true);

      chatController.isFormSubmitted.value = true;
      expect(chatController.isFormSubmitted.value, true);
    });

    test('Mode switching updates currentMode', () {
      expect(chatController.currentMode.value, 'sous chef');
      
      chatController.currentMode.value = 'meal';
      expect(chatController.currentMode.value, 'meal');
      
      chatController.currentMode.value = 'sous chef';
      expect(chatController.currentMode.value, 'sous chef');
    });

    test('Response loading state updates', () {
      expect(chatController.isResponding.value, false);
      
      chatController.isResponding.value = true;
      expect(chatController.isResponding.value, true);
      
      chatController.isResponding.value = false;
      expect(chatController.isResponding.value, false);
    });
  });
}
