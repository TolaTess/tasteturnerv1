import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../helper/helper_functions.dart';

/// Simple progress bar widget for meal processing status
class MealProcessingProgressBar extends StatefulWidget {
  final List<String> mealIds;
  final VoidCallback? onCompleted;
  final VoidCallback? onRetry;

  const MealProcessingProgressBar({
    super.key,
    required this.mealIds,
    this.onCompleted,
    this.onRetry,
  });

  @override
  State<MealProcessingProgressBar> createState() =>
      _MealProcessingProgressBarState();
}

class _MealProcessingProgressBarState extends State<MealProcessingProgressBar> {
  Timer? _statusTimer;
  int _completedCount = 0;
  int _pendingCount = 0;
  int _totalCount = 0;
  double _progressPercentage = 0.0;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _totalCount = widget.mealIds.length;
    _startStatusMonitoring();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MealProcessingProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mealIds != widget.mealIds) {
      _totalCount = widget.mealIds.length;
      _startStatusMonitoring();
    }
  }

  /// Start monitoring meal processing status
  void _startStatusMonitoring() {
    _statusTimer?.cancel();
    if (widget.mealIds.isNotEmpty) {
      _updateMealStatus();
      _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _updateMealStatus();
      });
    }
  }

  /// Update meal processing status by checking individual meal status
  Future<void> _updateMealStatus() async {
    if (widget.mealIds.isEmpty) return;

    try {
      int pendingCount = 0;
      int completedCount = 0;

      for (final mealId in widget.mealIds) {
        final meal = await mealManager.getMealbyMealID(mealId);
        if (meal != null) {
          final status = meal.status?.toLowerCase() ?? 'pending';
          switch (status) {
            case 'pending':
            case 'processing':
              pendingCount++;
              break;
            case 'completed':
              completedCount++;
              break;
            case 'failed':
              // Count failed as completed for progress calculation
              completedCount++;
              break;
            default:
              pendingCount++;
          }
        } else {
          pendingCount++; // Assume pending if meal not found
        }
      }

      final progressPercentage =
          _totalCount > 0 ? (completedCount / _totalCount * 100) : 0.0;

      if (mounted) {
        setState(() {
          _completedCount = completedCount;
          _pendingCount = pendingCount;
          _progressPercentage = progressPercentage;
        });

        // Auto-hide when all meals are processed
        if (pendingCount == 0 && _isVisible) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() => _isVisible = false);
              widget.onCompleted?.call();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating meal status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mealIds.isEmpty || !_isVisible) return const SizedBox.shrink();

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final isProcessing = _pendingCount > 0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1, context),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(2, context),
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status row
          Row(
            children: [
              Icon(
                isProcessing ? Icons.hourglass_empty : Icons.check_circle,
                color: isProcessing ? kAccent : Colors.green,
                size: getPercentageWidth(5, context),
              ),
              SizedBox(width: getPercentageWidth(3, context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main status text
                    Text(
                      isProcessing
                          ? '$_pendingCount meals processing'
                          : 'All meals completed! 🎉',
                      style: TextStyle(
                        fontSize: getPercentageHeight(2, context),
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(0.5, context)),
                    // Progress info
                    Text(
                      '$_completedCount completed • ${_progressPercentage.toInt()}%',
                      style: TextStyle(
                        fontSize: getPercentageHeight(1.6, context),
                        color: isDarkMode ? kLightGrey : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Close button
              if (isProcessing)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _isVisible = false),
                  iconSize: getPercentageWidth(4, context),
                  color: isDarkMode ? kWhite : kBlack,
                ),
            ],
          ),

          // Progress bar
          if (isProcessing) ...[
            SizedBox(height: getPercentageHeight(1.5, context)),
            LinearProgressIndicator(
              value: _progressPercentage / 100,
              backgroundColor: isDarkMode ? kDarkGrey : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(kAccent),
              minHeight: 4,
            ),
          ],
        ],
      ),
    );
  }
}
