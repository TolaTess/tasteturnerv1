import 'package:flutter/material.dart';
import '../constants.dart';

// an avatar upload button widget

class AvatarUpload extends StatelessWidget {
  const AvatarUpload({
    super.key,
    required this.avatarUrl,
    required this.press,
  });

  final String avatarUrl; // feed avatar url
  final VoidCallback press; // to do when pressed

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Stack(
        children: [
          //user avatar
          CircleAvatar(
            radius: 65,
            backgroundImage: avatarUrl != null &&
                    avatarUrl.isNotEmpty &&
                    avatarUrl.contains('http')
                ? NetworkImage(avatarUrl)
                : const AssetImage(intPlaceholderImage) as ImageProvider,
          ),

          //camera icon
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(
                    30,
                  ),
                  border: Border.all(color: Colors.white, width: 3)),
              child: const Icon(
                Icons.photo_camera,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
