// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:provider/provider.dart';
// import '../constants.dart';
// import '../helper/utils.dart';
// import '../themes/theme_provider.dart';
// import '../widgets/custom_drawer.dart';
// import 'home_screen.dart';
// import '../screens/message_screen.dart';
// import 'post_screen.dart';

// class HomeTabScreen extends StatefulWidget {
//   final int initialTabIndex;
//   const HomeTabScreen({super.key, this.initialTabIndex = 0});

//   @override
//   State<HomeTabScreen> createState() => _HomeTabScreenScreenState();
// }

// class _HomeTabScreenScreenState extends State<HomeTabScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   int _lastUnreadCount = 0; // Track last unread count

//   // Add this method to handle notifications
//   Future<void> _handleUnreadNotifications(int unreadCount) async {
//     // Only proceed if the unread count has changed
//     if (unreadCount == _lastUnreadCount) return;

//     if (unreadCount >= 1) {
//       // Only show notification if we haven't shown it before
//       if (!await notificationService.hasShownUnreadNotification) {
//         await notificationService.showNotification(
//           title: 'Unread Messages',
//           body: 'You have $unreadCount unread messages',
//         );
//         await notificationService.setHasShownUnreadNotification(true);
//       }
//     } else if (_lastUnreadCount > 0) {
//       // Only reset if we're transitioning from unread to read
//       await notificationService.resetUnreadNotificationState();
//     }

//     _lastUnreadCount = unreadCount; // Update last unread count
//   }

//   @override
//   void initState() {
//     super.initState();
//     // Ensure initialTabIndex is within bounds
//     final validInitialIndex = widget.initialTabIndex.clamp(0, 1);
//     _tabController =
//         TabController(length: 2, vsync: this, initialIndex: validInitialIndex);
//     _tabController.addListener(_handleTabIndex);
//     chatController.loadUserChats(userService.userId ?? '');
//   }

//   @override
//   void dispose() {
//     _tabController.removeListener(_handleTabIndex);
//     _tabController.dispose();
//     super.dispose();
//   }

//   void _handleTabIndex() {
//     setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);

//     // Safely access user data with null checks
//     final currentUser = userService.currentUser;
//     if (currentUser == null) {
//       // Show a loading state if user data isn't available yet
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }

//     final inspiration = currentUser.bio ?? getRandomBio(bios);
//     final avatarUrl = currentUser.profileImage ?? intPlaceholderImage;

//     return Scaffold(
//       drawer: const CustomDrawer(),
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(75),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   // Avatar and Greeting Section
//                   Row(
//                     children: [
//                       Builder(builder: (context) {
//                         return GestureDetector(
//                           onTap: () {
//                             Scaffold.of(context).openDrawer();
//                           },
//                           child: CircleAvatar(
//                             radius: 25,
//                             backgroundColor: kAccent.withOpacity(kOpacity),
//                             child: CircleAvatar(
//                               backgroundImage: _getAvatarImage(avatarUrl),
//                               radius: 23,
//                             ),
//                           ),
//                         );
//                       }),
//                       const SizedBox(width: 12),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             '$greeting ${currentUser.displayName}!',
//                             style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           Text(
//                             inspiration,
//                             style: const TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w400,
//                               color: kLightGrey,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                   // Message Section
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 10,
//                       vertical: 5,
//                     ),
//                     decoration: BoxDecoration(
//                       color: themeProvider.isDarkMode
//                           ? kDarkModeAccent.withOpacity(kLowOpacity)
//                           : kBackgroundColor,
//                       borderRadius: BorderRadius.circular(50),
//                     ),
//                     child: Row(
//                       children: [
//                         GestureDetector(
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => const MessageScreen(),
//                               ),
//                             );
//                           },
//                           child: Icon(Icons.message,
//                               size: 30, color: kAccent.withOpacity(0.6)),
//                         ),
//                         const SizedBox(width: 5),

//                         // Unread Count Badge
//                         Obx(() {
//                           final nonBuddyChats = chatController.userChats
//                               .where((chat) => !(chat['participants'] as List)
//                                   .contains('buddy'))
//                               .toList();

//                           if (nonBuddyChats.isEmpty) {
//                             return const SizedBox
//                                 .shrink(); // Hide badge if no chats
//                           }

//                           // Calculate total unread count across all non-buddy chats
//                           final int unreadCount = nonBuddyChats.fold<int>(
//                             0,
//                             (sum, chat) =>
//                                 sum + (chat['unreadCount'] as int? ?? 0),
//                           );

//                           // Handle notifications
//                           _handleUnreadNotifications(unreadCount);

//                           if (unreadCount >= 1) {
//                             return Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 6, vertical: 2),
//                               decoration: BoxDecoration(
//                                 color: kRed,
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: Text(
//                                 unreadCount.toString(),
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                 ),
//                               ),
//                             );
//                           } else {
//                             return const SizedBox
//                                 .shrink(); // Hide badge if unreadCount is 0
//                           }
//                         }),
//                       ],
//                     ),
//                   )
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // TabBar at the top
//             TabBar(
//               controller: _tabController,
//               tabs: const [
//                 Tab(
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(home),
//                       SizedBox(width: 8),
//                     ],
//                   ),
//                 ),
//                 Tab(
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(feed),
//                       SizedBox(width: 8),
//                     ],
//                   ),
//                 ),
//               ],
//               indicatorColor: themeProvider.isDarkMode ? kWhite : kDarkGrey,
//               labelStyle: const TextStyle(
//                 fontWeight: FontWeight.w600,
//                 fontSize: 15,
//               ),
//               labelColor: themeProvider.isDarkMode ? kWhite : kBlack,
//               unselectedLabelColor: kLightGrey,
//             ),

//             // TabBarView below the TabBar
//             Expanded(
//               child: TabBarView(
//                 controller: _tabController,
//                 children: [
//                   const HomeScreen(),
//                   PostHomeScreen(
//                     themeProvider: themeProvider,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   ImageProvider _getAvatarImage(String? imageUrl) {
//     if (imageUrl != null &&
//         imageUrl.isNotEmpty &&
//         imageUrl.startsWith("http") &&
//         imageUrl != "null") {
//       return NetworkImage(imageUrl);
//     }
//     return const AssetImage(intPlaceholderImage);
//   }
// }
