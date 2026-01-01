import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:intl/intl.dart';
import '../data_models/user_meal.dart';

/// Service for moving meals between dates
class MealMoveService {
  static final MealMoveService instance = MealMoveService._();
  MealMoveService._();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Move a meal from one date to another
  /// Preserves meal type and all meal data
  Future<bool> moveMeal({
    required String userId,
    required String instanceId,
    required DateTime oldDate,
    required DateTime newDate,
    required String mealType,
    UserMeal? mealData,
  }) async {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final oldDateStr = dateFormat.format(oldDate);
      final newDateStr = dateFormat.format(newDate);

      // If same date, no need to move
      if (oldDateStr == newDateStr) {
        debugPrint('Same date, no move needed');
        return true;
      }

      // Get meal data if not provided
      UserMeal mealToMove;
      if (mealData != null) {
        mealToMove = mealData;
      } else {
        final fetchedMeal =
            await _getMealFromDate(userId, oldDateStr, mealType, instanceId);
        if (fetchedMeal == null) {
          debugPrint('Meal not found: $instanceId');
          return false;
        }
        mealToMove = fetchedMeal;
      }

      // Use Firestore transaction to ensure atomicity
      await firestore.runTransaction((transaction) async {
        // Get old date document
        final oldDateRef = firestore
            .collection('userMeals')
            .doc(userId)
            .collection('meals')
            .doc(oldDateStr);

        final oldDateDoc = await transaction.get(oldDateRef);

        if (!oldDateDoc.exists) {
          throw Exception('Old date document does not exist');
        }

        // Get new date document (create if doesn't exist)
        final newDateRef = firestore
            .collection('userMeals')
            .doc(userId)
            .collection('meals')
            .doc(newDateStr);

        final newDateDoc = await transaction.get(newDateRef);

        // Parse meals from old date
        final oldMealsData =
            oldDateDoc.data()?['meals'] as Map<String, dynamic>? ?? {};
        final oldMealList = oldMealsData[mealType] as List<dynamic>? ?? [];

        // Find and remove the meal from old date
        final updatedOldMealList = oldMealList.where((meal) {
          final mealMap = meal as Map<String, dynamic>;
          return mealMap['instanceId'] != instanceId;
        }).toList();

        // Parse meals from new date (or initialize if doesn't exist)
        Map<String, dynamic> newMealsData;
        if (newDateDoc.exists) {
          newMealsData = Map<String, dynamic>.from(
              newDateDoc.data()?['meals'] as Map<String, dynamic>? ?? {});
        } else {
          newMealsData = {
            'Breakfast': [],
            'Lunch': [],
            'Dinner': [],
            'Fruits': [],
          };
        }

        final newMealList = List<dynamic>.from(newMealsData[mealType] ?? []);

        // Add meal to new date (update loggedAt timestamp)
        final updatedMeal = mealToMove.copyWith({
          'loggedAt': DateTime.now(),
        });
        newMealList.add(updatedMeal.toFirestore());

        // Update old date document
        final updatedOldMeals = Map<String, dynamic>.from(oldMealsData);
        updatedOldMeals[mealType] = updatedOldMealList;

        transaction.update(oldDateRef, {
          'meals': updatedOldMeals,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update or create new date document
        final updatedNewMeals = Map<String, dynamic>.from(newMealsData);
        updatedNewMeals[mealType] = newMealList;

        if (newDateDoc.exists) {
          transaction.update(newDateRef, {
            'meals': updatedNewMeals,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(newDateRef, {
            'meals': updatedNewMeals,
            'timestamp': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint(
          'Successfully moved meal $instanceId from $oldDateStr to $newDateStr');
      return true;
    } catch (e) {
      debugPrint('Error moving meal: $e');
      return false;
    }
  }

  /// Get a specific meal from a date
  Future<UserMeal?> _getMealFromDate(
    String userId,
    String dateStr,
    String mealType,
    String instanceId,
  ) async {
    try {
      final mealsDoc = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateStr)
          .get();

      if (!mealsDoc.exists) {
        return null;
      }

      final mealsData =
          mealsDoc.data()?['meals'] as Map<String, dynamic>? ?? {};
      final mealList = mealsData[mealType] as List<dynamic>? ?? [];

      for (var mealData in mealList) {
        final mealMap = mealData as Map<String, dynamic>;
        if (mealMap['instanceId'] == instanceId) {
          return UserMeal.fromMap(mealMap);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting meal from date: $e');
      return null;
    }
  }

  /// Copy a meal from one date to another (without removing from original date)
  /// Creates a new instance with a new instanceId
  Future<bool> copyMeal({
    required String userId,
    required String instanceId,
    required DateTime sourceDate,
    required DateTime targetDate,
    required String mealType,
    UserMeal? mealData,
  }) async {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final sourceDateStr = dateFormat.format(sourceDate);
      final targetDateStr = dateFormat.format(targetDate);

      // If same date, no need to copy
      if (sourceDateStr == targetDateStr) {
        debugPrint('Same date, no copy needed');
        return true;
      }

      // Get meal data if not provided
      UserMeal mealToCopy;
      if (mealData != null) {
        mealToCopy = mealData;
      } else {
        final fetchedMeal =
            await _getMealFromDate(userId, sourceDateStr, mealType, instanceId);
        if (fetchedMeal == null) {
          debugPrint('Meal not found: $instanceId');
          return false;
        }
        mealToCopy = fetchedMeal;
      }

      // Generate new instanceId for the copy
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (DateTime.now().microsecondsSinceEpoch % 10000);
      final newInstanceId = '${timestamp}_${random}';

      // Create a copy with new instanceId and updated loggedAt
      final copiedMeal = mealToCopy.copyWith({
        'originalMealId': mealToCopy.mealId,
        'instanceId': newInstanceId,
        'isInstance': true,
        'loggedAt': DateTime.now(),
      });

      // Use Firestore transaction to add the copy to target date
      await firestore.runTransaction((transaction) async {
        // Get target date document (create if doesn't exist)
        final targetDateRef = firestore
            .collection('userMeals')
            .doc(userId)
            .collection('meals')
            .doc(targetDateStr);

        final targetDateDoc = await transaction.get(targetDateRef);

        // Parse meals from target date (or initialize if doesn't exist)
        Map<String, dynamic> targetMealsData;
        if (targetDateDoc.exists) {
          targetMealsData = Map<String, dynamic>.from(
              targetDateDoc.data()?['meals'] as Map<String, dynamic>? ?? {});
        } else {
          targetMealsData = {
            'Breakfast': [],
            'Lunch': [],
            'Dinner': [],
            'Fruits': [],
            'Snacks': [],
          };
        }

        final targetMealList =
            List<dynamic>.from(targetMealsData[mealType] ?? []);

        // Add copied meal to target date
        targetMealList.add(copiedMeal.toFirestore());

        // Update or create target date document
        final updatedTargetMeals = Map<String, dynamic>.from(targetMealsData);
        updatedTargetMeals[mealType] = targetMealList;

        if (targetDateDoc.exists) {
          transaction.update(targetDateRef, {
            'meals': updatedTargetMeals,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(targetDateRef, {
            'meals': updatedTargetMeals,
            'timestamp': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint(
          'Successfully copied meal $instanceId from $sourceDateStr to $targetDateStr (new instanceId: $newInstanceId)');
      return true;
    } catch (e) {
      debugPrint('Error copying meal: $e');
      return false;
    }
  }

  /// Trigger cloud function to recalculate nutrition for a date
  Future<void> triggerNutritionRecalculation(
      String userId, DateTime date) async {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(date);

      // Note: This is a placeholder - actual implementation depends on your cloud function setup
      // You may need to use HttpsCallable instead
      debugPrint('Triggering nutrition recalculation for $dateStr');

      // If you have an HttpsCallable, use it here:
      // final callable = FirebaseFunctions.instance.httpsCallable('calculateDailyNutrition');
      // await callable.call({'userId': userId, 'date': dateStr});
    } catch (e) {
      debugPrint('Error triggering nutrition recalculation: $e');
    }
  }
}
