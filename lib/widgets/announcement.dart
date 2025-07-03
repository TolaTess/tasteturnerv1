import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';

class AnnouncementWidget extends StatefulWidget {
  final String? title;
  final String? description;
  final Map<String, dynamic> announcements;
  final double height;
  final VoidCallback? onTap;

  const AnnouncementWidget({
    Key? key,
    this.title,
    this.description,
    required this.announcements,
    this.height = 40,
    this.onTap,
  }) : super(key: key);

  @override
  State<AnnouncementWidget> createState() => _AnnouncementWidgetState();
}

class _AnnouncementWidgetState extends State<AnnouncementWidget> {
  late ScrollController _scrollController;
  late Timer _timer;
  final double _scrollAmount = 2.0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _startScrolling();
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isHovered && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(
            currentScroll + _scrollAmount,
            duration: const Duration(milliseconds: 50),
            curve: Curves.linear,
          );
        }
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupWinnersByCategory() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final winners = widget.announcements['winners'] as List;

    for (var winner in winners) {
      final category = winner['category'] as String;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(winner);
    }

    // Sort winners within each category by position
    for (var category in grouped.keys) {
      grouped[category]!.sort((a, b) {
        final aPos = a['position'] as String;
        final bPos = b['position'] as String;
        return aPos.compareTo(bPos);
      });
    }

    return grouped;
  }

  @override
  void dispose() {
    _timer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildDivider(bool isDarkMode) {
    return Container(
      height: widget.height * 0.3,
      width: 1,
      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final hasHeaderContent = widget.title != null || widget.description != null;
    final groupedWinners = _groupWinnersByCategory();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: kAccentLight.withValues(alpha: 0.8),   
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (hasHeaderContent) ...[
              Padding(
                padding:
                    EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(1, context),
                        vertical: getPercentageWidth(1, context)),
                child: Center(
                  child: Text(
                    widget.title ?? '',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
              _buildDivider(isDarkMode),
            ],
            ...groupedWinners.entries.map((entry) {
              final category = entry.key;
              final winners = entry.value;
              return Row(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(1, context),
                        vertical: getPercentageWidth(1, context)),
                    child: Row(
                      children: [
                        Text(
                          '${category.toUpperCase()}: ',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        ...winners.map((winner) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${winner['displayName']} (${winner['position']})',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          );
                        }).toList(),
                        SizedBox(width: getPercentageWidth(10, context)),
                      ],
                    ),
                  ),
                  if (entry.key != groupedWinners.keys.last)
                    _buildDivider(isDarkMode),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
