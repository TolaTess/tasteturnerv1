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
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kAccentLight.withOpacity(0.8),
              kAccentLight.withOpacity(0.4),
            ],
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
                    colors: [
                      kAccentLight.withOpacity(0.8),
                      kAccentLight.withOpacity(0.4),
                    ],
                  ),
                ),
              ),
              // Image with opacity overlay
              Positioned.fill(
                child: Image.asset(
                  getAssetImageForItem(program['image']),
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
                        program['description'],
                        style: textTheme.titleSmall?.copyWith(
                          color: kWhite,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      Text(
                        program['name'],
                        style: textTheme.titleLarge?.copyWith(
                          color: kWhite,
                        ),
                      ),
                      if (program['enrolled'] == true) ...[
                        SizedBox(height: getPercentageHeight(1, context)),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: kWhite,
                              size: getIconScale(4, context),
                            ),
                            SizedBox(width: getPercentageWidth(1, context)),
                            Text(
                              'Enrolled',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kWhite,
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
