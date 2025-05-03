import 'package:flutter/material.dart';
import '../constants.dart';
import '../screens/buddy_screen.dart';
import '../screens/premium_screen.dart';
import '../service/user_service.dart';
import '../themes/theme_provider.dart';
import '../widgets/optimized_image.dart';

Widget buildTastyFloatingActionButton({
  required BuildContext context,
  required Key? buttonKey,
  required UserService userService,
  required ThemeProvider themeProvider,
}) {
  return FloatingActionButton(
    key: buttonKey,
    onPressed: () {
      if (userService.currentUser?.isPremium ?? false) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TastyScreen(),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
            title: const Text(
              'Premium Feature',
              style: TextStyle(color: kAccent),
            ),
            content: Text(
              'Upgrade to premium to chat with your AI buddy Tasty 👋 and get personalized nutrition advice!',
              style: TextStyle(
                color: themeProvider.isDarkMode ? kWhite : kBlack,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: themeProvider.isDarkMode ? kWhite : kBlack,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PremiumScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Upgrade',
                  style: TextStyle(color: kAccentLight),
                ),
              ),
            ],
          ),
        );
      }
    },
    backgroundColor: kPrimaryColor,
    child: Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: kAccentLight,
        shape: BoxShape.circle,
        image: DecorationImage(
          image: AssetImage(tastyImage),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

// Add this class before the MessageScreen class
class CustomFloatingActionButtonLocation extends FloatingActionButtonLocation {
  final double verticalOffset;
  final double horizontalOffset;

  const CustomFloatingActionButtonLocation({
    this.verticalOffset = 0,
    this.horizontalOffset = 0,
  });

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset offset =
        FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    return Offset(offset.dx - horizontalOffset, offset.dy - verticalOffset);
  }
}

Widget buildProfileAvatar({
  required String imageUrl,
  double outerRadius = 38,
  double innerRadius = 35,
  double imageSize = 70,
  Color? backgroundColor,
}) {
  return CircleAvatar(
    radius: outerRadius,
    backgroundColor: backgroundColor ?? kAccent.withOpacity(kOpacity),
    child: CircleAvatar(
      radius: innerRadius,
      child: ClipOval(
        child: OptimizedImage(
          imageUrl: imageUrl,
          width: imageSize,
          height: imageSize,
          isProfileImage: true,
        ),
      ),
    ),
  );
}

ImageProvider getAvatarImage(String? imageUrl) {
  if (imageUrl != null &&
      imageUrl.isNotEmpty &&
      imageUrl.startsWith("http") &&
      imageUrl != "null") {
    return NetworkImage(imageUrl);
  }
  return const AssetImage(intPlaceholderImage);
}

String getMealTimeOfDay() {
  final now = DateTime.now();
  final hour = now.hour;

  if (hour >= 5 && hour < 11) {
    return 'Breakfast';
  } else if (hour >= 11 && hour < 16) {
    return 'Lunch';
  } else {
    return 'Dinner';
  }
}

String getSharedCalendarHeader(String userName, String friendName) {
  // Handle null or empty names
  userName = userName.trim();
  friendName = friendName.trim();

  if (userName.isEmpty || friendName.isEmpty) {
    return 'Shared Calendar';
  }

  // Get initials from names
  String userInitial = userName[0].toUpperCase();

  return '$userInitial & $friendName';
}

Widget getBirthdayTextContainer(String birthdayName, bool isShrink) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: isShrink ? 5 : 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: isShrink
          ? Border.all(color: kAccentLight, width: 1)
          : Border.all(color: kAccentLight, width: 0),
    ),
    child: Text(
      '${birthdayName}s birthday is today! 🎂',
      style: TextStyle(
        color: kAccentLight,
        fontSize: isShrink ? 12 : 14,
        fontWeight: isShrink ? FontWeight.normal : FontWeight.w400,
        overflow: isShrink ? TextOverflow.ellipsis : TextOverflow.visible,
      ),
    ),
  );
}
