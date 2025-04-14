import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../data_models/post_model.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../themes/theme_provider.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';

class NewPostScreenFinal extends StatefulWidget {
  final List<String> imagePaths;

  const NewPostScreenFinal(this.imagePaths, {super.key});

  @override
  State<NewPostScreenFinal> createState() => _NewPostScreenFinalState();
}

class _NewPostScreenFinalState extends State<NewPostScreenFinal> {
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userId = userService.userId ?? '';
    final user = userService.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const IconCircleButton(
            isRemoveContainer: true,
          ),
        ),
        title: const Text("New Post"),
        actions: [
          Align(
            alignment: Alignment.center,
            child: InkWell(
              onTap: () async {
                if (userId.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("User ID is missing."),
                      ),
                    );
                  }
                  return;
                }

                final post = Post(
                  id: '',
                  userId: userId,
                  title: _captionController.text.trim(),
                  avatar: user!.profileImage,
                  username: user.displayName,
                  mediaPaths: [],
                  timestamp: Timestamp.now(),
                );

                await postController.uploadPost(
                    post, userId, widget.imagePaths);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Post Added."),
                    ),
                  );
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BottomNavSec()),
                );
              },
              child: const Text(
                "Post",
                style: TextStyle(
                  color: kAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Thumbnails and Caption
                Row(
                  children: [
                    if (widget.imagePaths.isNotEmpty)
                      Image.file(
                        File(widget.imagePaths.first),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: SafeTextFormField(
                        controller: _captionController,
                        style: TextStyle(
                            color: themeProvider.isDarkMode ? kWhite : kBlack),
                        maxLines: 3,  
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: themeProvider.isDarkMode
                              ? kLightGrey.withValues(alpha: kLowOpacity)
                              : kDarkModeAccent,
                          enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide.none),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide.none),
                          border: const OutlineInputBorder(
                              borderSide: BorderSide.none),
                          hintStyle: TextStyle(
                              color:
                                  themeProvider.isDarkMode ? kWhite : kBlack),
                          hintText: "Write a caption",
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          contentPadding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            right: 8,
                            left: 8,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),

                // Display Remaining Selected Images
                if (widget.imagePaths.length > 1)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.imagePaths
                        .skip(1)
                        .map(
                          (path) => Image.file(
                            File(path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),

                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("Your Recent Posts"),
                ),
                FutureBuilder<List<Post>>(
                  future: postController.getUserPosts(userId),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                        color: kAccent,
                      ));
                    }
                    if (!postSnapshot.hasData || postSnapshot.data!.isEmpty) {
                      return noItemTastyWidget(
                        "No posts yet.",
                        "",
                        context,
                        false,
                      );
                    }

                    final posts = postSnapshot.data!;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: posts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final mediaPath = post.mediaPaths.first;

                        return mediaPath.startsWith(
                                'http') // Check if it's a network URL
                            ? Image.network(
                                mediaPath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                  intPlaceholderImage,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.file(
                                File(mediaPath), // Handle local file paths
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                  intPlaceholderImage,
                                  fit: BoxFit.cover,
                                ),
                              );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
