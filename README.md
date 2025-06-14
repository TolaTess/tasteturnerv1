TasteTurner

TasteTurner is a Health & Fitness nutrition app for iOS and Android, designed to make meal planning fun, social, and family-friendly. Targeting health-conscious adults, including parents, TasteTurner simplifies healthy eating with features like randomized recipe discovery, weekly ingredient battles, and kid-focused meal planning. The app offers a free tier (with ads) and a Premium subscription ($9.99/mo or $79.99/yr) for advanced features like unlimited child profiles and ad-free experiences.

Current Version: 1.0 (Pre-Launch, August 2025 Release)
Platforms: iOS (100-150MB installed), Android (67MB AAB)
Category: Health & Fitness
Built With: Flutter, Firebase (Firestore), AdMob, StoreKit (iOS), Google Play Billing (Android)

Table of Contents
Overview (#overview)
Features (#features)
Monetization (#monetization)
Testing (#testing)
Roadmap (#roadmap)
Contact (#contact)

Overview

TasteTurner empowers adults to plan healthy meals with a playful, engaging experience. Key features include a spin-the-wheel recipe discovery, Weekly Ingredients Battle, AI-driven meal advice, and a Family Meal Planning Dashboard for parents managing kids’ meals (ages 2-12). The app supports both individual health goals (e.g., “Lose Weight,” “Healthy Eating”) and family-oriented goals (e.g., “Family Nutrition”) with kid-friendly filters like Low-Sugar and Nut-Free.
The app is in pre-launch development, with a planned release in August 2025 on the App Store and Google Play. It targets health-conscious users, particularly parents (30-40% of Health & Fitness users), aiming for >70% day-7 retention and 5-10% Premium conversion rates.

Features
Spin-the-Wheel Recipe Discovery: Randomly suggests healthy recipes, with kid-friendly filters (e.g., Low-Sugar, Nut-Free, Picky Eater-Friendly) in “Family Nutrition” mode.
Weekly Ingredients Battle: Users vote on ingredients (e.g., Zucchini vs. Sweet Potato), fostering community engagement.
AI Chat: Personalized recipe tips, including a Parent Meal Advisor for kid meal ideas (e.g., picky-eater solutions).
Meal Planning Calendar: Schedule meals, mark special days (e.g., “Family Day”), and assign kid-specific meals.
Calendar Sharing: Share meal plans with family/friends via Firestore (shared_calendars).
Social Features: In-app chat and posting for community interaction.
Grocery List Generation: Auto-creates lists from planned meals, prioritizing kid-friendly items (e.g., whole grains).
Nutrition Tracking: Tracks calories (no macros) with kid-specific guidelines (e.g., 1,400 kcal/day for ages 6-8).
Healthy Kids’ Meals for Parents:
Kid-friendly recipe filters (Low-Sugar, Nut-Free, Picky Eater-Friendly, Quick Prep, Vegetarian, Portion-Controlled).
Family Meal Planning Dashboard showing meal plans (e.g., “Emma’s Breakfast: Banana Oat Pancakes, 200 kcal”).
Age-based nutritional guidance (USDA-based).
Smart grocery lists and meal prep reminders.
Parental diet integration (e.g., vegetarian family meals).

Dependencies
Add to pubspec.yaml:
yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.0
  cloud_firestore: ^4.13.0
  in_app_purchase: ^3.1.0
  google_mobile_ads: ^3.0.0
  flutter_launcher_icons: ^0.13.0

Testing
Local Testing: Run flutter test for unit tests. Use emulators (iOS Simulator, Android Emulator) for UI testing.

iOS Testing (TestFlight):
Upload IPA to App Store Connect.
Test internally (up to 25 testers) or externally (up to 10,000 testers) via TestFlight.
Focus: Meal plans, subscription flows, filter accuracy (e.g., Low-Sugar recipes).

Android Testing (Closed Testing):
Upload AAB to Google Play Console.
Test with up to 100 testers in Closed Testing track.
Use Play Billing Lab app for subscription testing.

Steps:
Register Bundle ID at developer.apple.com.
Create app record in App Store Connect.
Build IPA: flutter build ipa --release.
Upload via Xcode or Transporter app.
Configure metadata: Description, keywords (e.g., “family meal planner,” “healthy kids meals”), subscriptions.
Submit for review (1-5 days).
Notes:
Ensure Privacy Manifest declares Firebase/AdMob data usage.
Test subscriptions in sandbox environment.

Roadmap
Pre-Launch (June-July 2025):
Complete Healthy Kids’ Meals feature (Firestore updates, UI, reminders).
Test in TestFlight (iOS) and Closed Testing (Android).
Finalize App Store/Google Play listings.

Launch (August 2025):
Release version 1.0 with all features.
Promote on X (e.g., “Plan healthy kids’ meals with TasteTurner!”).

Post-Launch:
Add integrations (e.g., Apple Health).
Monitor DAU/retention (>70% day 7).
Optimize Premium conversions (5-10%).

Contact
Support: support@tasteturner.com (mailto:support@tasteturner.com)
Website: tasteturner.com
