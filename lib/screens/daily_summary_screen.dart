import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/daily_summary_widget.dart';

class DailySummaryScreen extends StatefulWidget {
  final DateTime? date;

  const DailySummaryScreen({
    super.key,
    this.date,
  });

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.date ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isToday = DateFormat('yyyy-MM-dd').format(selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: kAccent,
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        title: Text(
          'Daily Summary',
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
            color: kWhite,
          ),
        ),
        actions: [
          if (!isToday)
            IconButton(
              onPressed: () {
                setState(() {
                  selectedDate = DateTime.now();
                });
              },
              icon: Icon(
                Icons.today,
                color: kWhite,
                size: getIconScale(6, context),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Selector
            Container(
              padding: EdgeInsets.all(getPercentageWidth(3, context)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        selectedDate =
                            selectedDate.subtract(const Duration(days: 1));
                      });
                    },
                    icon: Icon(
                      Icons.chevron_left,
                      color: kAccent,
                      size: getIconScale(6, context),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: getDatePickerTheme(context, isDarkMode),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(4, context),
                        vertical: getPercentageHeight(1, context),
                      ),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: kAccent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: kAccent,
                            size: getIconScale(4, context),
                          ),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate),
                            style: textTheme.titleMedium?.copyWith(
                              color: kAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: selectedDate.isBefore(
                            DateTime.now().subtract(const Duration(days: 1)))
                        ? () {
                            setState(() {
                              selectedDate =
                                  selectedDate.add(const Duration(days: 1));
                            });
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: selectedDate.isBefore(
                              DateTime.now().subtract(const Duration(days: 1)))
                          ? kAccent
                          : kAccent.withValues(alpha: 0.3),
                      size: getIconScale(6, context),
                    ),
                  ),
                ],
              ),
            ),

            // Daily Summary Widget
            Expanded(
              child: SingleChildScrollView(
                child: DailySummaryWidget(
                  key: ValueKey(DateFormat('yyyy-MM-dd')
                      .format(selectedDate)), // Force rebuild when date changes
                  date: selectedDate,
                  showPreviousDay: !isToday,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
