import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../themes/theme_provider.dart';

class GroupListItem extends StatelessWidget {
  const GroupListItem({
    super.key,
    required this.dataSrc,
    required this.press,
    required this.pressJoin,
    required this.isMember,
  });

  final Map<String, dynamic> dataSrc;
  final VoidCallback press;
  final VoidCallback pressJoin;
  final bool isMember;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final List<dynamic>? mediaPaths = dataSrc['mediaPaths'] as List<dynamic>?;
    final String? mediaType = dataSrc['mediaType'] as String?;

    final String? mediaPath = mediaPaths != null && mediaPaths.isNotEmpty
        ? mediaPaths.first as String
        : extPlaceholderImage;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 12,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Media Preview (Image/Video/Multi-image)
            GestureDetector(
              onTap: press,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      image: mediaPath != null && mediaPath.isNotEmpty && mediaPath.contains('http')
                          ? DecorationImage(
                              image: NetworkImage(mediaPath),
                              fit: BoxFit.cover,
                            )
                          : const DecorationImage(
                              image:
                                  AssetImage(intPlaceholderImage),
                              fit: BoxFit.cover,
                            ),
                    ),
                    clipBehavior: Clip.hardEdge,
                  ),

                  // ✅ Video Overlay Icon
                  if (mediaType == 'video')
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.slideshow,
                        color: Colors.white,
                        size: 24,
                      ),
                    )

                  // ✅ Multiple Images Overlay Icon
                  else if (mediaPaths != null && mediaPaths.length > 1)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.content_copy,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(
              width: 16,
            ),

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  //title
                  Text(
                    dataSrc['title'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                  ),
                  const Spacer(),

                  //user
                  Text(
                    dataSrc['user'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),

                  //desc
                  Text(
                    dataSrc['category'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(
              width: 16,
            ),

            //join
            GestureDetector(
              onTap: pressJoin,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeProvider.isDarkMode
                      ? kDarkModeAccent.withOpacity(0.08)
                      : kAccent.withOpacity(0.08),
                ),
                child: Icon(
                  Icons.join_full_rounded,
                  color: themeProvider.isDarkMode
                      ? kDarkModeAccent.withOpacity(0.50)
                      : kAccent.withOpacity(0.50),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
