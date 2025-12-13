import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../constants.dart';

class ChatSummaryController extends GetxController {
  static ChatSummaryController get instance {
    if (!Get.isRegistered<ChatSummaryController>()) {
      debugPrint('⚠️ ChatSummaryController not registered, registering now');
      return Get.put(ChatSummaryController());
    }
    return Get.find<ChatSummaryController>();
  }

  var chatSummaries =
      <ChatSummary>[].obs; // Observable list initialized as empty

  void fetchChatSummaries() {
    firestore
        .collection('chats')
        .where('participants', arrayContains: userService.userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .listen((querySnapshot) {
      chatSummaries.value = querySnapshot.docs.map((doc) {
        return ChatSummary.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }
}

class ChatSummary {
  final String chatId;
  final List<String> participants;
  final String? lastMessage;
  final String? lastMessageTime;

  ChatSummary({
    required this.chatId,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
  });

  // Factory constructor to parse Firestore data
  factory ChatSummary.fromFirestore(String chatId, Map<String, dynamic> data) {
    // Convert Firestore Timestamp to ISO8601 String or fallback
    final lastMessageTime = (data['lastMessageTime'] is Timestamp)
        ? (data['lastMessageTime'] as Timestamp).toDate().toIso8601String()
        : null;

    return ChatSummary(
      chatId: chatId,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: lastMessageTime,
    );
  }
}
