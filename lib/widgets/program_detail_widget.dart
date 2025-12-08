import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/program_service.dart';
import 'menu_detail_widget.dart';

class ProgramDetailWidget extends StatefulWidget {
  final Map<String, dynamic> program;
  final VoidCallback? onJoinProgram;
  final bool isEnrolled;

  const ProgramDetailWidget({
    super.key,
    required this.program,
    this.onJoinProgram,
    this.isEnrolled = false,
  });

  @override
  State<ProgramDetailWidget> createState() => _ProgramDetailWidgetState();
}

class _ProgramDetailWidgetState extends State<ProgramDetailWidget> {
  late final ProgramService _programService;
  bool _isJoining = false;
  bool _isEnrolled = false;

  @override
  void initState() {
    super.initState();
    _isEnrolled = widget.isEnrolled;
    // Initialize ProgramService using Get.find() with try-catch fallback
    try {
      _programService = Get.find<ProgramService>();
    } catch (e) {
      // If not found, put it
      _programService = Get.put(ProgramService());
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red,
      colorText: kWhite,
      duration: const Duration(seconds: 3),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    Get.snackbar(
      'Success',
      message,
      backgroundColor: kAccentLight,
      colorText: kWhite,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _handleJoinProgram() async {
    final programId = widget.program['programId'] as String?;
    if (programId == null || programId.isEmpty) {
      _showErrorSnackbar('Invalid menu data, Chef. Please try again.');
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      // Join the program with default option since no options are available
      await _programService.joinProgram(programId, 'default');

      if (mounted) {
        setState(() {
          _isJoining = false;
          _isEnrolled = true;
        });
        _showSuccessSnackbar(
            'You\'ve joined the ${widget.program['name'] ?? 'program'} menu, Chef!');
        // Reload user programs to update the list
        await _programService.loadUserPrograms();
        // Navigate back
        Get.back();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
        final errorMessage = e.toString().contains('already enrolled')
            ? 'You are already enrolled in this menu, Chef'
            : 'Couldn\'t join menu, Chef. Please try again.';
        _showErrorSnackbar(errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: getPercentageHeight(85, context),
          maxWidth: getPercentageWidth(90, context),
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey : kWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with program name and close button
            _buildHeader(context, textTheme, isDarkMode),

            // Enrollment status indicator
            if (_isEnrolled)
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(5, context),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(3, context),
                  vertical: getPercentageHeight(1, context),
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: getIconScale(4, context),
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Expanded(
                      child: Text(
                        'You are enrolled in this menu, Chef',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Scrollable content with new Menu Detail Widget
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(getPercentageWidth(5, context)),
                child: MenuDetailWidget(
                  program: widget.program,
                  isEnrolled: _isEnrolled,
                ),
              ),
            ),

            // Action buttons
            _buildActionButtons(context, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(getPercentageWidth(5, context)),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.program['name'] ?? 'Menu',
              style: textTheme.displayMedium?.copyWith(
                fontSize: getTextScale(5, context),
                color: kAccent,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.close,
                color: kAccent,
                size: getIconScale(5, context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(getPercentageWidth(5, context)),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isJoining ? null : () => Get.back(),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(1.5, context),
                ),
              ),
              child: Text(
                _isEnrolled ? 'Close' : 'Cancel',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (!_isEnrolled) ...[
            SizedBox(width: getPercentageWidth(3, context)),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _handleJoinProgram,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: kWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: getPercentageHeight(1.5, context),
                  ),
                ),
                child: _isJoining
                    ? SizedBox(
                        height: getIconScale(4, context),
                        width: getIconScale(4, context),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(kWhite),
                        ),
                      )
                    : Text(
                        'Join Menu',
                        style: textTheme.bodyMedium?.copyWith(
                          color: kWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
