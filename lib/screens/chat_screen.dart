import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../helper/utils.dart';
import '../pages/photo_manager.dart';
import '../pages/safe_text_field.dart';
import '../service/chat_controller.dart';

import '../widgets/icon_widget.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? friendId;
  final String? screen;
  final Map<String, dynamic>? dataSrc;
  final UserModel? friend;

  const ChatScreen({
    super.key,
    this.chatId,
    this.friendId,
    this.dataSrc,
    this.screen,
    this.friend,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();

  late String? chatId;
  @override
  void initState() {
    super.initState();
    chatId = widget.chatId;

    if (chatId != null && chatId!.isNotEmpty) {
      chatController.chatId = chatId!;
      chatController.listenToMessages();
      chatController.markMessagesAsRead(chatId!, widget.friendId!);

      if (widget.dataSrc != null && widget.dataSrc!.isNotEmpty) {
        _shareImage(widget.dataSrc?['mediaPaths'][0]);
      }
    } else if (widget.friendId != null) {
      chatController.initializeChat(widget.friendId!).then((_) {
        setState(() {
          chatId = chatController.chatId;
        });
        chatController.markMessagesAsRead(chatId!, widget.friendId!);

        if (widget.dataSrc?['mediaPaths'][0] != null &&
            widget.dataSrc?['mediaPaths'][0]!.isNotEmpty) {
          _shareImage(
              widget.dataSrc?['mediaPaths'][0] ?? widget.dataSrc?['image']);
        }
      });
    }
  }

  void _shareImage(String imageUrl) {
    String message = '';
    if (widget.screen == 'group_cha') {
      message =
          'Shared from ${capitalizeFirstLetter(widget.dataSrc?['title'])} Challenge /${widget.dataSrc?['id']} /${widget.dataSrc?['title']} /${widget.screen}';
    } else if (widget.screen == 'battle_post') {
      message =
          'Shared from ${capitalizeFirstLetter(widget.dataSrc?['name'])} for ${capitalizeFirstLetter(widget.dataSrc?['category'])} Battle /${widget.dataSrc?['id']} /${widget.dataSrc?['name']} /${widget.screen}';
    } else {
      message =
          'Shared caption: ${capitalizeFirstLetter(widget.dataSrc?['title'])} /${widget.dataSrc?['id']} /${widget.dataSrc?['title']} /${widget.screen}';
    }

    chatController.sendMessage(
      messageContent: message,
      imageUrls: [imageUrl],
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onNewMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        leadingWidth: MediaQuery.of(context).size.width,
        leading: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: IconCircleButton(
                  isRemoveContainer: true,
                ),
              ),
            ),
            const Spacer(),
            Text(
              widget.friend?.displayName ?? 'Chat',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: isDarkMode ? kWhite : kDarkGrey),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: widget.friendId!.isEmpty
                  ? () {}
                  : () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfileScreen(userId: widget.friendId!),
                        ),
                      );
                    },
              child: CircleAvatar(
                backgroundColor: kAccent,
                radius: 23,
                child: CircleAvatar(
                  backgroundImage: widget.friend?.profileImage != null &&
                          widget.friend!.profileImage!.isNotEmpty &&
                          widget.friend!.profileImage!.contains('http')
                      ? NetworkImage(widget.friend!.profileImage!)
                      : const AssetImage(intPlaceholderImage) as ImageProvider,
                  radius: 20,
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
      body: chatId == null
          ? noItemTastyWidget(
              "No chat yet...",
              "",
              context,
              false,
            )
          : Column(
              children: [
                Expanded(
                  child: Obx(() {
                    final messages = chatController.messages;

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text("No messages yet."),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController
                            .jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return ChatItem(
                          dataSrc: message,
                          isMe: message.senderId == userService.userId,
                        );
                      },
                    );
                  }),
                ),
                _buildInputSection(isDarkMode),
              ],
            ),
    );
  }

  Future<void> _handleImageSend(List<File> images, String? caption) async {
    List<String> uploadedUrls = [];

    for (File image in images) {
      final String fileName =
          'chats/$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = firebaseStorage.ref().child(fileName);

      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      uploadedUrls.add(imageUrl);
    }

    // Send text + images together as a single message or separate depending on your logic
    await chatController.sendMessage(
      messageContent: caption,
      imageUrls: uploadedUrls,
    );
    _onNewMessage();
  }

  Widget _buildInputSection(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) {
                  return CustomImagePickerModal(
                    onSend: _handleImageSend,
                  );
                },
              );
            },
            child: const IconCircleButton(
              icon: Icons.camera_alt,
              h: 35,
              w: 35,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SafeTextFormField(
              controller: textController,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDarkMode ? kLightGrey : kWhite,
                enabledBorder: outlineInputBorder(20),
                focusedBorder: outlineInputBorder(20),
                border: outlineInputBorder(20),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                hintText: 'Type your caption...',
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              final messageText = textController.text.trim();
              if (messageText.isNotEmpty && chatId != null) {
                await chatController.sendMessage(messageContent: messageText);
                textController.clear();
              }
            },
            child: const IconCircleButton(
              icon: Icons.send,
              h: 40,
              w: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatItem extends StatelessWidget {
  final ChatScreenData dataSrc;
  final bool isMe;

  const ChatItem({
    super.key,
    required this.dataSrc,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    double screenWidth = MediaQuery.of(context).size.width;
    List<String> extractedItems = extractSlashedItems(dataSrc.messageContent);
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
      child: Align(
        alignment: isMe ? Alignment.topRight : Alignment.topLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: screenWidth * 0.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: isMe
                ? (isDarkMode
                    ? kLightGrey.withOpacity(kMidOpacity)
                    : kAccent.withOpacity(kMidOpacity))
                : (isDarkMode
                    ? kLightGrey.withOpacity(kLowOpacity)
                    : kDarkGrey.withOpacity(kLowOpacity)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Show Image if Available
              if (dataSrc.imageUrls.isNotEmpty)
                Column(
                  children: dataSrc.imageUrls.map((url) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          if (extractedItems.isNotEmpty &&
                              extractedItems.last == 'post') {
                            // Navigate to PostDetailScreen
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChallengeDetailScreen(
                                  dataSrc: dataSrc.toMap(),
                                  screen: 'myPost',
                                ),
                              ),
                            );
                          } else {
                            // Navigate to ChallengeDetailScreen
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChallengeDetailScreen(
                                  screen: extractedItems.isNotEmpty
                                      ? extractedItems.last
                                      : 'battle_post',
                                  dataSrc: dataSrc.toMap(),
                                ),
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            height: 150,
                            width: screenWidth * 0.7,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              intPlaceholderImage,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Show Text if Available
              if (dataSrc.messageContent.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    getTextBeforeSlash(dataSrc.messageContent),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

              const SizedBox(height: 4),

              // Timestamp & Read Status
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(dataSrc.timestamp.toDate()),
                    style: const TextStyle(fontSize: 10),
                  ),
                  if (isMe) const SizedBox(width: 4),
                  if (isMe)
                    const Icon(
                      Icons.done_all,
                      size: 14,
                      color: Colors.blue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
