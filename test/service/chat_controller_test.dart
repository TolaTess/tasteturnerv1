import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tasteturner/service/chat_controller.dart';
import 'package:mocktail/mocktail.dart';

// Mock dependencies if needed
class MockChatController extends Mock implements ChatController {}

void main() {
  group('ChatController Tests', () {
    late ChatController chatController;

    setUp(() {
      // Initialize Get for testing
      Get.testMode = true;
      chatController = ChatController();
      Get.put(chatController);
    });

    tearDown(() {
      Get.reset();
    });

    test('Initial state is correct', () {
      expect(chatController.currentMode.value, 'tasty');
      expect(chatController.showForm.value, false);
      expect(chatController.messages.length, 0);
    });


    test('Welcome messages are populated', () {
      expect(chatController.tastyWelcomeMessages, isNotEmpty);
      expect(chatController.mealPlanWelcomeMessages, isNotEmpty);
    });

    test('Planning form state updates', () {
      chatController.showForm.value = true;
      expect(chatController.showForm.value, true);

      chatController.isFormSubmitted.value = true;
      expect(chatController.isFormSubmitted.value, true);
    });
  });
}
