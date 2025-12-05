import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../service/macro_manager.dart';
import '../helper/utils.dart';

/// Reusable widget for generating/updating shopping list from meal plan
/// Shows a badge with new items count when there are new meals
class ShoppingListGenerateButton extends StatelessWidget {
  final bool isGenerating;
  final RxInt newItemsCount;
  final MacroManager macroManager;
  final VoidCallback? onSuccess;
  final Function(bool) onGeneratingStateChanged;
  final bool showInEmptyState;

  const ShoppingListGenerateButton({
    super.key,
    required this.isGenerating,
    required this.newItemsCount,
    required this.macroManager,
    required this.onGeneratingStateChanged,
    this.onSuccess,
    this.showInEmptyState = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: getPercentageHeight(showInEmptyState ? 3 : 2, context),
        horizontal: getPercentageWidth(4, context),
      ),
      child: Obx(() => Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: isGenerating
                  ? null
                  : () async {
                      onGeneratingStateChanged(true);
                      try {
                        final status = await macroManager
                            .generateAndFetchShoppingList();

                        if (context.mounted) {
                          if (status == 'success') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Shopping list updated from meal plan!'),
                                backgroundColor: kGreen,
                              ),
                            );
                            // Refresh the shopping list to update UI
                            final userId = userService.userId;
                            if (userId != null) {
                              await Future.delayed(const Duration(milliseconds: 500));
                              await macroManager.refreshShoppingLists(userId, getCurrentWeek());
                              // Wait a bit more for the listener to update, then check for new items
                              if (!showInEmptyState) {
                                await Future.delayed(const Duration(milliseconds: 1000));
                              }
                              // Trigger callback if provided
                              onSuccess?.call();
                            }
                          } else if (status == 'no_meals') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'No meals found in this week\'s plan.'),
                                backgroundColor: kOrange,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Failed to generate list. Please try again.'),
                                backgroundColor: kRed,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Failed to generate list: $e')),
                          );
                        }
                      } finally {
                        // Always reset the generating state, regardless of context.mounted
                        onGeneratingStateChanged(false);
                      }
                    },
              icon: isGenerating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kWhite,
                      ),
                    )
                  : Icon(
                      newItemsCount.value > 0
                          ? Icons.update
                          : Icons.refresh,
                      color: kWhite,
                    ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      isGenerating
                          ? 'Generating...'
                          : (newItemsCount.value > 0
                              ? 'Update with new ' +
                                  (newItemsCount.value == 1 ? 'menu' : 'menus')
                              : 'Generate from Menu Plan'),
                      style: const TextStyle(color: kWhite),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (newItemsCount.value > 0 && !isGenerating) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kRed,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode ? kDarkGrey : kWhite,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        newItemsCount.value > 99
                            ? '99+'
                            : newItemsCount.value.toString(),
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(6, context),
                  vertical: getPercentageHeight(1.5, context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}

