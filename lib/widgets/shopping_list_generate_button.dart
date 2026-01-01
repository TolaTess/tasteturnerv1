import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../service/macro_manager.dart';
import '../helper/utils.dart';
import '../helper/helper_functions.dart';

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
    final hasPremiumAccess = canUseAI();

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: getPercentageHeight(showInEmptyState ? 3 : 1.5, context),
        horizontal: getPercentageWidth(4, context),
      ),
      child: Obx(() => Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isGenerating || !hasPremiumAccess
                      ? null
                      : () async {
                          // Check premium access before generating
                          if (!canUseAI()) {
                            final isDarkMode =
                                getThemeProvider(context).isDarkMode;
                            showPremiumRequiredDialog(context, isDarkMode);
                            return;
                          }

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
                                  await Future.delayed(
                                      const Duration(milliseconds: 500));
                                  await macroManager.refreshShoppingLists(
                                      userId, getCurrentWeek());
                                  // Wait a bit more for the listener to update, then check for new items
                                  if (!showInEmptyState) {
                                    await Future.delayed(
                                        const Duration(milliseconds: 1000));
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
                                    content:
                                        Text('Failed to generate list: $e')),
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
                          hasPremiumAccess
                              ? (newItemsCount.value > 0
                                  ? Icons.update
                                  : Icons.refresh)
                              : Icons.lock,
                          color: kWhite,
                        ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          isGenerating
                              ? 'Generating...'
                              : (!hasPremiumAccess
                                  ? 'Premium Required'
                                  : (newItemsCount.value > 0
                                      ? 'Update with new ' +
                                          (newItemsCount.value == 1
                                              ? 'dish'
                                              : 'dishes')
                                      : 'Generate from Menu Plan')),
                          style: const TextStyle(color: kWhite),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (newItemsCount.value > 0 && !isGenerating) ...[
                        SizedBox(width: getPercentageWidth(2, context)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(2, context), vertical: getPercentageHeight(0.5, context)),
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
                    backgroundColor: hasPremiumAccess ? kAccent : Colors.grey,
                    padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(3, context),
                      vertical: getPercentageHeight(1, context),
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
