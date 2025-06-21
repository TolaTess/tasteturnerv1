import 'package:flutter/material.dart';
import 'package:tasteturner/helper/utils.dart';

class SecondNavWidget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Widget destinationScreen;

  const SecondNavWidget({
    Key? key,
    required this.icon,
    required this.color,
    required this.label,
    required this.destinationScreen,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: getPercentageWidth(10.5, context),
            height: getPercentageWidth(10.5, context),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.4), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: getIconScale(5, context),
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            label,
            style: TextStyle(
              fontSize: getTextScale(3, context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
