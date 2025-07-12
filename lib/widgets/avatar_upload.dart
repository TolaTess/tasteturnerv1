import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

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
            radius: getResponsiveBoxSize(context, 50, 50),
            child: ClipOval(
              child: avatarUrl.isNotEmpty && avatarUrl.contains('http')
                  ? buildOptimizedNetworkImage(
                      imageUrl: avatarUrl,
                      width: getResponsiveBoxSize(context, 100, 100),
                      height: getResponsiveBoxSize(context, 100, 100),
                      fit: BoxFit.cover,
                      isProfileImage: true,
                    )
                  : Image.asset(
                      intPlaceholderImage,
                      width: getResponsiveBoxSize(context, 100, 100),
                      height: getResponsiveBoxSize(context, 100, 100),
                      fit: BoxFit.cover,
                    ),
            ),
          ),

          //camera icon
          Positioned(
            right: 5,
            top: 0,
            child: Container(
              padding: EdgeInsets.all(getPercentageWidth(0.5, context)),
              decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(
                    30,
                  ),
                  border: Border.all(
                      color: Colors.white,
                      width: getPercentageWidth(0.3, context))),
              child: Icon(
                Icons.photo_camera,
                color: Colors.white,
                size: getResponsiveBoxSize(context, 20, 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
