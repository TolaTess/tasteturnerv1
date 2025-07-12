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
  final bool isRecipe;
  final bool isTechnique;
  final bool isProgram;
  const OverlappingCardsView({
    Key? key,
    required this.children,
    this.overlap = 0.9,
    this.cardWidth = 200,
    this.cardHeight = 100,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.controller,
    this.isRecipe = false,
    this.isTechnique = false,
    this.isProgram = false,
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

    // Create a list of indices sorted by selection status
    final sortedIndices = List.generate(widget.children.length, (i) => i);
    if (selectedIndex != null) {
      sortedIndices.remove(selectedIndex);
      sortedIndices.add(selectedIndex!);
    }

    // Calculate total width needed for all cards
    // Account for overlap between cards and potential expansion of selected card
    final baseWidth = (widget.children.length - 1) * (widget.cardWidth * 0.2) +
        widget.cardWidth;
    final totalWidth =
        baseWidth + (widget.cardWidth * 0.3); // Extra space for expansion

    return SizedBox(
      height: widget.cardHeight + 30, // Extra height for shadows and elevation
      child: Padding(
        padding: widget.padding.add(EdgeInsets.only(
            top: 15, bottom: 15)), // Extra padding for animations
        child: Scrollbar(
          controller: widget.controller,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: widget.controller,
            clipBehavior: Clip.none, // Allow overflow for shadows
            child: SizedBox(
              width: totalWidth,
              height: widget.cardHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: sortedIndices.map((index) {
                  final child = widget.children[index];
                  final isSelected = selectedIndex == index;
                  final isTopCard = index == sortedIndices.last;

                  // If this is the top card and no card is selected, auto-select it
                  if (isTopCard && selectedIndex == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && selectedIndex == null) {
                        selectCard(index);
                      }
                    });
                  }

                  // Calculate position based on selection state
                  double leftPosition =
                      index * (widget.cardWidth * 0.2); // Default 80% overlap

                  // If there's a selected card, adjust positions
                  if (selectedIndex != null) {
                    if (index == selectedIndex) {
                      // Selected card stays at its position
                      leftPosition = selectedIndex! * (widget.cardWidth * 0.2);
                    } else if (index > selectedIndex!) {
                      // Cards after the selected one should be more visible
                      leftPosition = (selectedIndex! *
                              (widget.cardWidth * 0.2)) +
                          (widget.cardWidth * 0.8) + // Show 20% of next card
                          ((index - selectedIndex! - 1) *
                              (widget.cardWidth * 0.2));
                    }
                  }

                  if (child is OverlappingCard) {
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: leftPosition,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isSelected
                            ? widget.cardWidth * 1.2
                            : widget.cardWidth,
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
                            isSelected: isSelected || isTopCard,
                            isRecipe: widget.isRecipe,
                            isTechnique: widget.isTechnique,
                            onTap: child.onTap,
                            type: child.type,
                            isProgram: widget.isProgram,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OverlappingCard extends StatefulWidget {
  final String title;
  final String? type;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final String? imageUrl;
  final double width;
  final double height;
  final int index;
  final bool isSelected;
  final bool isRecipe;
  final bool isTechnique;
  final bool isProgram;

  const OverlappingCard({
    Key? key,
    required this.title,
    this.type,
    this.subtitle,
    required this.color,
    this.onTap,
    this.imageUrl,
    this.width = 200,
    this.height = 100,
    required this.index,
    this.isSelected = false,
    this.isRecipe = false,
    this.isTechnique = false,
    this.isProgram = false,
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

    final imageUrl = widget.imageUrl?.isNotEmpty == true && !widget.isProgram
        ? widget.imageUrl!
        : widget.isProgram
            ? getAssetImageForItem(widget.type!.toLowerCase())
            : getAssetImageForItem(widget.title.toLowerCase());

    final isLongTitle = widget.title.length > 10;
    final isLongSubtitle = (widget.subtitle?.length ?? 0) > 50;

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
              color:
                  Colors.black.withValues(alpha: widget.isSelected ? 0.3 : 0.1),
              blurRadius: widget.isSelected ? 16 : 8,
              offset: Offset(0, widget.isSelected ? 8 : 4),
              spreadRadius: widget.isSelected ? 3 : 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.startsWith('http')
                      ? buildOptimizedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(16),
                          placeholder: Container(
                            color: widget.color.withValues(alpha: 0.3),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: widget.color,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        )
                      : Image.asset(
                          imageUrl,
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
                    widget.color.withValues(alpha: 0.9),
                    widget.color.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: getPercentageWidth(!widget.isSelected ? 0 : 4, context),
                right: getPercentageWidth(!widget.isSelected ? 0 : 4, context),
                top: getPercentageHeight(!widget.isSelected ? 0 : 2, context),
              ),
              child: Stack(
                children: [
                  if (!widget.isSelected)
                    Positioned(
                      left: getPercentageWidth(1, context),
                      bottom: getPercentageHeight(0, context),
                      child: Transform.rotate(
                        angle: -1.5708, // -90 degrees in radians
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: widget.height * 0.8,
                          child: Text(
                            !widget.isRecipe && !widget.isTechnique
                                ? capitalizeFirstLetter(widget.type ?? '')
                                : capitalizeFirstLetter(widget.title),
                            style: textTheme.displayMedium?.copyWith(
                              fontSize: isLongTitle ? 16 : 20,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? kWhite : kDarkGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  if (widget.isSelected)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(2, context),
                        vertical: getPercentageHeight(
                            isLongSubtitle ? 0 : 1, context),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !widget.isRecipe || !widget.isTechnique
                                ? capitalizeFirstLetter(widget.title)
                                : capitalizeFirstLetter(widget.type ?? ''),
                            style: textTheme.displayMedium?.copyWith(
                              fontSize: isLongTitle
                                  ? getTextScale(4, context)
                                  : getTextScale(5, context),
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? kWhite : kDarkGrey,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                widget.subtitle!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode
                                      ? kWhite.withValues(alpha: 0.7)
                                      : kDarkGrey,
                                  fontSize: getTextScale(4, context),
                                ),
                                maxLines: widget.isRecipe ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedBuilder(
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
                                  backgroundColor:
                                      isDarkMode ? kWhite : kAccent,
                                  foregroundColor:
                                      isDarkMode ? kDarkGrey : kWhite,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: getPercentageWidth(2, context),
                                    vertical: getPercentageHeight(1, context),
                                  ),
                                ),
                                child: Text(
                                  widget.isRecipe
                                      ? 'View'
                                      : widget.isTechnique == true
                                          ? 'View'
                                          : 'Join Program',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: isDarkMode ? kDarkGrey : kWhite,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
