import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../constants.dart';

//email button widget

class EmailButton extends StatelessWidget {
  const EmailButton({
    super.key,
    required this.text,
    required this.press,
    this.text2 = '',
  });

  final String text, text2;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: kDarkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      onPressed: press,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.email,
          ),
          const SizedBox(
            width: 12,
          ),
          Text(
            "$text ${text2.toUpperCase()}",
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomSuffixIcon extends StatelessWidget {
  const CustomSuffixIcon({
    super.key,
    required this.svgIcon,
  });

  final String svgIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          top: 20,
          left: 0,
          bottom: 20,
          right: 20),
      child: SvgPicture.asset(
        svgIcon,
        height: 18,
        color: kAccent,
      ),
    );
  }
}
