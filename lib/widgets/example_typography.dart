import 'package:flutter/material.dart';

class TypographyExample extends StatelessWidget {
  const TypographyExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the text theme from context
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display styles - using Caveat font (accent)
        Text(
          'Welcome to TasteTurner',
          style: textTheme.displayLarge, // 57.0px Caveat
        ),
        Text(
          'Featured Recipes',
          style: textTheme.displayMedium, // 45.0px Caveat
        ),
        Text(
          'Daily Specials',
          style: textTheme.displaySmall, // 36.0px Caveat
        ),
        const SizedBox(height: 20),

        // Headline styles - using Chivo font (base)
        Text(
          'Main Heading',
          style: textTheme.headlineLarge, // 32.0px Chivo
        ),
        Text(
          'Section Heading',
          style: textTheme.headlineMedium, // 28.0px Chivo
        ),
        Text(
          'Subsection',
          style: textTheme.headlineSmall, // 24.0px Chivo
        ),

        // Title styles - using Chivo
        ListTile(
          title: Text(
            'Recipe Title',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ), // 22.0px Chivo
          ),
          subtitle: Text(
            'Recipe description text',
            style: textTheme.bodyMedium, // 14.0px Chivo
          ),
        ),

        // Mixing styles in a card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent font for the feature text
                Text(
                  'Featured Recipe',
                  style: textTheme.displaySmall?.copyWith(
                    color: Colors.purple,
                  ), // 36.0px Caveat
                ),
                // Base theme for content
                Text(
                  'Detailed description',
                  style: textTheme.bodyLarge, // 16.0px Chivo
                ),
                // Base theme for metadata
                Text(
                  '20 minutes • 4 servings',
                  style: textTheme.labelMedium, // 12.0px Chivo
                ),
              ],
            ),
          ),
        ),

        // Button text example
        ElevatedButton(
          onPressed: () {},
          child: Text(
            'Get Started',
            style: textTheme.labelLarge?.copyWith(
              color: Colors.white,
            ), // 14.0px Chivo
          ),
        ),

        // Alert or important text
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Important Note!',
            style: textTheme.displaySmall?.copyWith(
              color: Colors.amber.shade900,
            ), // 36.0px Caveat
          ),
        ),
      ],
    );
  }
} 