// import 'package:flutter/material.dart';

// import '../constants.dart';
// import '../helper/utils.dart';
// import '../widgets/date_widget.dart';
// import 'helper_widget.dart';

// class StatusWidgetBox extends StatelessWidget {
//   final ValueNotifier<double> currentNotifier = ValueNotifier<double>(0);
//   final String title;
//   final double total;
//   final double current;
//   final bool isLarge, isSquare, isWater;
//   final String sym;
//   final Color upperColor;
//   final VoidCallback press;

//   StatusWidgetBox({
//     super.key,
//     this.title = '',
//     this.total = 0,
//     this.current = 0,
//     this.isLarge = false,
//     this.sym = '',
//     this.isSquare = false,
//     this.upperColor = kWhite,
//     this.isWater = false,
//     required this.press,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isDarkMode = getThemeProvider(context).isDarkMode;
//     ValueNotifier<double> valueNotifier;
//     if (currentNotifier.value >= current) {
//       valueNotifier = ValueNotifier<double>(currentNotifier.value);
//     } else {
//       valueNotifier = ValueNotifier<double>(current);
//     }

//     return InkWell(
//       onTap: press,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           isSquare
//               ? const SizedBox.shrink()
//               : Text(
//                   title,
//                   style: TextStyle(
//                       fontSize: 14, color: isDarkMode ? kLightGrey : kDarkGrey),
//                 ),
//           isSquare ? const SizedBox.shrink() : const SizedBox(height: 10),
//           isSquare
//               ? FillingSquare(
//                   current: valueNotifier,
//                   upperColor: upperColor,
//                   isWater: isWater,
//                   widgetName: title,
//                   total: total,
//                   sym: sym,
//                 )
//               : StatusWidget(
//                   total: total,
//                   current: current,
//                   isLarge: isLarge,
//                   sym: sym,
//                 ),
//         ],
//       ),
//     );
//   }
// }
