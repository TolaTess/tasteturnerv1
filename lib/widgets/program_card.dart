import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

class ProgramCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final VoidCallback onTap;

  const ProgramCard({
    super.key,
    required this.program,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: List<Color>.from(program['gradient']),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background gradient
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: List<Color>.from(program['gradient']),
                  ),
                ),
              ),
              // Image with opacity overlay
              Positioned.fill(
                child: Image.asset(
                  program['image'],
                  fit: BoxFit.cover,
                ),
              ),
              // Gradient overlay for better text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // // New/Popular Tag
              // if (program['isNew'] == true || program['isPopular'] == true)
              //   Positioned(
              //     top: 12,
              //     right: 12,
              //     child: Container(
              //       padding: EdgeInsets.symmetric(
              //         horizontal: getPercentageWidth(2, context),
              //         vertical: getPercentageHeight(0.5, context),
              //       ),
              //       decoration: BoxDecoration(
              //         color: program['isNew'] == true
              //             ? Colors.green
              //             : kAccentLight,
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //       child: Text(
              //         program['isNew'] == true ? 'NEW' : 'POPULAR',
              //         style: TextStyle(
              //           color: kWhite,
              //           fontSize: getTextScale(2, context),
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //     ),
              //   ),
              // Content
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.all(getPercentageWidth(4, context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        program['subtitle'],
                        style: TextStyle(
                          color: kWhite,
                          fontSize: getTextScale(2.5, context),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      Text(
                        program['name'],
                        style: TextStyle(
                          color: kWhite,
                          fontSize: getTextScale(4, context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (program['enrolled'] == true) ...[
                        SizedBox(height: getPercentageHeight(1, context)),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: kWhite,
                              size: getIconScale(3, context),
                            ),
                            SizedBox(width: getPercentageWidth(1, context)),
                            Text(
                              'Enrolled',
                              style: TextStyle(
                                color: kWhite,
                                fontSize: getTextScale(2.5, context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
