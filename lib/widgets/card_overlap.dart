import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

class OverlappingCardsView extends StatefulWidget {
  final List<Widget> children;
  final double overlap;
  final double cardWidth;
  final double cardHeight;
  final EdgeInsets padding;
  final ScrollController? controller;

  const OverlappingCardsView({
    Key? key,
    required this.children,
    this.overlap = 0.9,
    this.cardWidth = 200,
    this.cardHeight = 100,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.controller,
  }) : super(key: key);

  @override
  State<OverlappingCardsView> createState() => _OverlappingCardsViewState();
}

class _OverlappingCardsViewState extends State<OverlappingCardsView> {
  int? selectedIndex;

  void selectCard(int index) {
    setState(() {
      selectedIndex = selectedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox();

    return SizedBox(
      height: widget.cardHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sortedIndices = List.generate(widget.children.length, (i) => i);
          if (selectedIndex != null) {
            sortedIndices.remove(selectedIndex);
            sortedIndices.add(selectedIndex!);
          }

          return Stack(
            clipBehavior: Clip.none,
            children: sortedIndices.map((index) {
              final child = widget.children[index];
              final isSelected = selectedIndex == index;

              // Calculate position based on selection state
              double leftPosition =
                  index * (widget.cardWidth * 0.2); // Default 80% overlap

              // If there's a selected card, adjust positions
              if (selectedIndex != null) {
                if (index == selectedIndex) {
                  // Selected card stays at its position
                  leftPosition = selectedIndex! * (widget.cardWidth * 0.1);
                } else if (index > selectedIndex!) {
                  // Cards after the selected one should be more visible
                  leftPosition = (selectedIndex! * (widget.cardWidth * 0.1)) +
                      (widget.cardWidth * 0.8) + // Show 20% of next card
                      ((index - selectedIndex! - 1) * (widget.cardWidth * 0.1));
                }
              }

              if (child is OverlappingCard) {
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: leftPosition,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width:
                        isSelected ? widget.cardWidth * 1.2 : widget.cardWidth,
                    child: GestureDetector(
                      onTap: () => selectCard(index),
                      child: OverlappingCard(
                        title: child.title,
                        subtitle: child.subtitle,
                        color: child.color,
                        imageUrl: child.imageUrl,
                        width: isSelected
                            ? widget.cardWidth * 1.2
                            : widget.cardWidth,
                        height: widget.cardHeight,
                        index: index,
                        isSelected: isSelected,
                        onTap: child.onTap,
                      ),
                    ),
                  ),
                );
              }
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: leftPosition,
                child: SizedBox(
                  width: widget.cardWidth,
                  child: child,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class OverlappingCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final String? imageUrl;
  final double width;
  final double height;
  final int index;
  final bool isSelected;

  const OverlappingCard({
    Key? key,
    required this.title,
    this.subtitle,
    required this.color,
    this.onTap,
    this.imageUrl,
    this.width = 200,
    this.height = 100,
    required this.index,
    this.isSelected = false,
  }) : super(key: key);

  @override
  State<OverlappingCard> createState() => _OverlappingCardState();
}

class _OverlappingCardState extends State<OverlappingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _buttonOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _buttonOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
    ));
  }

  @override
  void didUpdateWidget(OverlappingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.identity()
        ..translate(
          0.0,
          widget.isSelected ? -10.0 : 0.0,
          widget.isSelected ? 10.0 : 0.0,
        ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isSelected ? 0.3 : 0.1),
              blurRadius: widget.isSelected ? 16 : 8,
              offset: Offset(0, widget.isSelected ? 8 : 4),
              spreadRadius: widget.isSelected ? 3 : 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            if (widget.imageUrl != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    widget.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    widget.color.withOpacity(0.9),
                    widget.color.withOpacity(0.6),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    getPercentageWidth(!widget.isSelected ? 0 : 4, context),
                vertical:
                    getPercentageHeight(!widget.isSelected ? 10 : 2, context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isSelected)
                    Flexible(
                      child: Transform.rotate(
                        angle: -1.5708,
                        child: Text(
                          capitalizeFirstLetter(widget.title),
                          style: textTheme.displayMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: isDarkMode ? kWhite : kDarkGrey,
                          ),
                        ),
                      ),
                    ),
                  if (widget.isSelected) ...[
                    Text(
                      capitalizeFirstLetter(widget.title),
                      style: textTheme.displayMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          widget.subtitle!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDarkMode
                                ? kWhite.withOpacity(0.7)
                                : kDarkGrey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _buttonOpacityAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _buttonOpacityAnimation.value,
                          child: child,
                        );
                      },
                      child: ElevatedButton(
                        onPressed: widget.onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? kWhite : kAccent,
                          foregroundColor: isDarkMode ? kDarkGrey : kWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(4, context),
                            vertical: getPercentageHeight(1, context),
                          ),
                        ),
                        child: Text(
                          'Join Program',
                          style: textTheme.labelLarge?.copyWith(
                            color: isDarkMode ? kDarkGrey : kWhite,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
