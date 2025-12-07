import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants.dart';

/// Shared utilities for both BuddyChatController and ChatController
class ChatUtilities {
  // Get or create a chat document based on participants
  static Future<String> getOrCreateChatId(String userId1, String userId2) async {
    // Validate inputs
    if (userId1.isEmpty || userId2.isEmpty) {
      throw Exception('User IDs cannot be empty');
    }

    try {
      final userDoc = await firestore.collection('users').doc(userId1).get();
      final existingChatIds = List<String>.from(userDoc.data()?['chats'] ?? []);

      for (final chatId in existingChatIds) {
        try {
          final chatDoc = await firestore.collection('chats').doc(chatId).get();
          if (!chatDoc.exists) {
            continue;
          }
          final participants =
              List<String>.from(chatDoc.data()?['participants'] ?? []);
          if (participants.contains(userId2)) {
            return chatId;
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error loading user chats: $e');
    }

    // Create a new chat if none exists   
    // Ensure current user is in participants array for security rules
    final currentUserId = userService.userId ?? userId1;
    final participants = [userId1, userId2];
    if (!participants.contains(currentUserId)) {
      participants.add(currentUserId);
    }

    final chatDoc = await firestore.collection('chats').add({
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': null,
      'isActive': true,
    });

    await updateUserChats(userId1, chatDoc.id);
    await updateUserChats(userId2, chatDoc.id);

    return chatDoc.id;
  }

  // Add chat reference to user's chat list
  static Future<void> updateUserChats(String userId, String chatId) async {
    await firestore.collection('users').doc(userId).set({
      'chats': FieldValue.arrayUnion([chatId]),
    }, SetOptions(merge: true));
  }

  // Sanitize data for Firestore - ensure all values are serializable
  static Map<String, dynamic> sanitizeForFirestore(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value == null) {
        sanitized[entry.key] = null;
      } else if (value is String ||
          value is int ||
          value is double ||
          value is bool) {
        sanitized[entry.key] = value;
      } else if (value is List) {
        sanitized[entry.key] = value.map((item) {
          if (item is String || item is int || item is double || item is bool) {
            return item;
          } else if (item is Map) {
            return sanitizeForFirestore(item as Map<String, dynamic>);
          }
          return item.toString();
        }).toList();
      } else if (value is Map) {
        sanitized[entry.key] =
            sanitizeForFirestore(value as Map<String, dynamic>);
      } else {
        // Convert any other type to string
        sanitized[entry.key] = value.toString();
      }
    }
    return sanitized;
  }
}

// Message data model - shared by both controllers
class ChatScreenData {
  final String messageContent;
  final List<String> imageUrls;
  final String senderId;
  final Timestamp timestamp;
  final Map<String, dynamic>? shareRequest;
  final Map<String, dynamic>? friendRequest;
  final Map<String, dynamic>? actionButtons;
  final String messageId;

  ChatScreenData({
    required this.messageContent,
    required this.imageUrls,
    required this.senderId,
    required this.timestamp,
    this.shareRequest,
    this.friendRequest,
    this.actionButtons,
    required this.messageId,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': messageContent,
      'mediaPaths': imageUrls,
      'senderId': senderId,
      'timestamp': timestamp,
      'messageId': messageId,
      if (shareRequest != null) 'shareRequest': shareRequest,
      if (friendRequest != null) 'friendRequest': friendRequest,
      if (actionButtons != null) 'actionButtons': actionButtons,
    };
  }

  factory ChatScreenData.fromFirestore(Map<String, dynamic> data,
      {String? messageId}) {
    return ChatScreenData(
      messageContent: data['messageContent'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      shareRequest: data['shareRequest'] as Map<String, dynamic>?,
      friendRequest: data['friendRequest'] as Map<String, dynamic>?,
      actionButtons: data['actionButtons'] as Map<String, dynamic>?,
      messageId: messageId ?? '',
    );
  }
}

