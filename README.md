# TasteTurner

TasteTurner is a **Health & Fitness nutrition app for iOS and Android**, designed to make meal planning fun, social, and family-friendly. Targeting health-conscious adults, including parents, TasteTurner simplifies healthy eating with features like randomized recipe discovery and kid-focused meal planning. The app offers a **free tier (with ads)** and a **Premium subscription ($9.99/mo or $79.99/yr)** for advanced features like unlimited child profiles and ad-free experiences.

**Current Version**: 1.0 (Pre-Launch, August 2025 Release)
**Platforms**: iOS (~60MB installed), Android (~60MB AAB)
**Category**: Health & Fitness
**Built With**: Flutter, Firebase (Firestore), AdMob, StoreKit (iOS), Google Play Billing (Android)

-----

### Table of Contents

* Overview
* Features
* Monetization
* Testing 
* Roadmap
* Contact

-----

### Overview

TasteTurner empowers adults to plan healthy meals with a playful, engaging experience. Key features include a **spin-the-wheel recipe discovery**, **AI-driven meal advice**, and a **Family Meal Planning Dashboard** for parents managing kids' meals (ages 2-12). The app supports both individual health goals (e.g., "Lose Weight," "Healthy Eating") and family-oriented goals (e.g., "Family Nutrition") with kid-friendly filters like Low-Sugar and Nut-Free.

Beyond meal planning, TasteTurner offers comprehensive health tracking including **symptom analysis** to identify food triggers, **Rainbow Tracker** for plant diversity monitoring (supporting gut health), **cycle syncing** for menstrual cycle-aware nutrition, and a **Health Journal** for water and steps tracking.

The app is in pre-launch development, with a planned release in **August 2025** on the App Store and Google Play. It targets health-conscious users, particularly **parents (30-40% of Health & Fitness users)**, aiming for \>70% day-7 retention and 5-10% Premium conversion rates.

-----

### Features

  * **Spin-the-Wheel Recipe Discovery**: Randomly suggests healthy recipes, with kid-friendly filters (e.g., Low-Sugar, Nut-Free, Picky Eater-Friendly) in "Family Nutrition" mode.
  * **AI Chat**: Personalized recipe tips, including a Parent Meal Advisor for kid meal ideas (e.g., picky-eater solutions).
  * **Meal Planning Calendar**: Schedule meals, mark special days (e.g., "Family Day"), and assign kid-specific meals.
  * **Calendar Sharing**: Share meal plans with family/friends via Firestore (shared\_calendars).
  * **Social Features**: In-app chat and posting for community interaction.
  * **Grocery List Generation**: Auto-creates lists from planned meals, prioritizing kid-friendly items (e.g., whole grains).
  * **Nutrition Tracking**: Tracks calories (no macros) with kid-specific guidelines (e.g., 1,400 kcal/day for ages 6-8).
  * **Healthy Kids' Meals for Parents**:
      * Kid-friendly recipe filters (Low-Sugar, Nut-Free, Picky Eater-Friendly, Quick Prep, Vegetarian, Portion-Controlled).
      * Family Meal Planning Dashboard showing meal plans (e.g., "Emma's Breakfast: Banana Oat Pancakes, 200 kcal").
      * Age-based nutritional guidance (USDA-based).
      * Smart grocery lists and meal prep reminders.
      * Parental diet integration (e.g., vegetarian family meals).
  * **Symptom Tracking & Analysis**:
      * Log symptoms (bloating, headache, fatigue, nausea, energy, good) with severity ratings (1-5).
      * AI-powered symptom pattern analysis over 30-day periods.
      * Ingredient trigger detection: Identifies food ingredients correlated with symptoms (requires 2+ occurrences to reduce false positives).
      * Symptom insights dashboard: View trends, frequency, and severity patterns.
      * Meal context tracking: Links symptoms to specific meals eaten 2-4 hours prior.
      * Ingredient correlation analysis: Discover which ingredients may trigger specific symptoms.
      * Weekly symptom trends: Track symptom patterns over time.
  * **Rainbow Tracker (Plant Diversity)**:
      * Automatic plant detection from meal ingredients across 6 categories: vegetables, fruits, grains, legumes, nuts/seeds, and herbs/spices.
      * Weekly plant diversity tracking with milestone levels:
          * **Beginner**: 10+ unique plants
          * **Healthy**: 20+ unique plants
          * **Gut Hero**: 30+ unique plants
      * Category breakdown: See distribution across plant categories.
      * Real-time progress tracking with visual progress bars.
      * Milestone notifications when reaching new levels.
      * Smart ingredient normalization: Handles variations like "fresh parsley" vs "parsley" as the same plant.
      * Historical tracking: View plant diversity from previous weeks.
  * **Cycle Syncing (Menstrual Cycle Tracking)**:
      * Optional menstrual cycle tracking with customizable cycle length (default: 28 days).
      * Phase-based nutrition goal adjustments:
          * **Luteal Phase** (Days 17-28): +200 calories, +20g carbs
          * **Menstrual Phase** (Days 1-5): +100 calories
          * **Follicular & Ovulation Phases**: Baseline goals
      * Cycle-aware food recommendations: Phase-specific suggestions (e.g., magnesium-rich foods during luteal phase, iron-rich foods during menstrual phase).
      * Phase tracking: Automatically calculates current cycle phase (Menstrual, Follicular, Ovulation, Luteal).
      * Cravings insights: Expected cravings for each cycle phase.
      * Enhanced recommendations: Tips and macro adjustments based on current phase.
  * **Health Journal**:
      * Water intake tracking: Log daily water consumption with customizable goals.
      * Steps tracking: Monitor daily step count with goal setting.
      * Daily metrics dashboard: View water and steps progress in one place.
      * Goal achievement badges: Earn badges for reaching water and steps goals.

-----

### Monetization

TasteTurner operates on a **freemium model** with two tiers:

  * **Free Tier**: Includes ads and access to core features.
  * **Premium Subscription**: Offers an ad-free experience, unlimited child profiles, and advanced features.
      * **Monthly**: $9.99/month
      * **Annual**: $79.99/year (approximately $6.67/month)

-----

### Dependencies

To include the necessary dependencies in your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.0
  cloud_firestore: ^4.13.0
  in_app_purchase: ^3.1.0
  google_mobile_ads: ^3.0.0
  flutter_launcher_icons: ^0.13.0
```

-----

### Testing

#### Local Testing

  * Run `flutter test` for unit tests.
  * Use emulators (iOS Simulator, Android Emulator) for UI testing.

#### iOS Testing (TestFlight)

  * Upload IPA to App Store Connect.
  * Test internally (up to 25 testers) or externally (up to 10,000 testers) via TestFlight.
  * **Focus**: Meal plans, subscription flows, filter accuracy (e.g., Low-Sugar recipes), symptom tracking, Rainbow Tracker plant detection, cycle syncing adjustments, and health journal metrics.

#### Android Testing (Closed Testing)

  * Upload AAB to Google Play Console.
  * Test with up to 100 testers in Closed Testing track.
  * Use Play Billing Lab app for subscription testing.
  * **Focus**: Symptom pattern analysis accuracy, plant diversity tracking, cycle phase calculations, and water/steps goal tracking.

#### Steps for App Store Submission

1.  Register Bundle ID at developer.apple.com.
2.  Create app record in App Store Connect.
3.  Build IPA: `flutter build ipa --release`.
4.  Upload via Xcode or Transporter app.
5.  Configure metadata: Description, keywords (e.g., “family meal planner,” “healthy kids meals”), subscriptions.
6.  Submit for review (1-5 days).

-----

### Roadmap

#### Pre-Launch (June-July 2025)

  * Complete Healthy Kids’ Meals feature (Firestore updates, UI, reminders).
  * Test in TestFlight (iOS) and Closed Testing (Android).
  * Finalize App Store/Google Play listings.

#### Launch (August 2025)

  * Release version 1.0 with all features.
  * Promote on X (e.g., “Plan healthy kids’ meals with TasteTurner\!”).

#### Post-Launch

  * Add integrations (e.g., Apple Health).
  * Monitor DAU/retention (\>70% day 7).
  * Optimize Premium conversions (5-10%).

-----

### Contact

**Support**: [support@tasteturner.com](mailto:support@tasteturner.com)
**Website**: [tasteturner.com](www.tasteturner.com)
