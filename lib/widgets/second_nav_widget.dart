import 'package:flutter/material.dart';
import 'package:tasteturner/helper/utils.dart';

class SecondNavWidget extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Widget destinationScreen;
  final Color iconColor;

  const SecondNavWidget({
    Key? key,
    required this.icon,
    required this.backgroundColor,
    required this.destinationScreen,
    this.iconColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationScreen),
        );
      },
      child: Container(
        width: getPercentageWidth(20, context),
        height: getPercentageHeight(7, context),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: getIconScale(10, context),
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
