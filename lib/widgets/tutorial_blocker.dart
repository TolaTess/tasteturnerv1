import 'package:flutter/material.dart';

/// Simple wrapper widget (no longer blocks scrolling)
/// Kept for backward compatibility but now just passes through the child
class TutorialBlocker extends StatelessWidget {
  final Widget child;
  final ScrollController? scrollController;

  const TutorialBlocker({
    super.key,
    required this.child,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // No longer blocking - just return the child
    return child;
  }
}

/// Wrapper for CustomScrollView (no longer blocks scrolling)
/// Now just a regular CustomScrollView wrapper for backward compatibility
class BlockableCustomScrollView extends StatelessWidget {
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  const BlockableCustomScrollView({
    super.key,
    required this.slivers,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget build(BuildContext context) {
    return TutorialBlocker(
      scrollController: controller,
      child: CustomScrollView(
        controller: controller,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        shrinkWrap: shrinkWrap,
        keyboardDismissBehavior: keyboardDismissBehavior,
        restorationId: restorationId,
        clipBehavior: clipBehavior,
        slivers: slivers,
      ),
    );
  }
}

/// Wrapper for SingleChildScrollView (no longer blocks scrolling)
/// Now just a regular SingleChildScrollView wrapper for backward compatibility
class BlockableSingleChildScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool reverse;
  final bool? primary;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  const BlockableSingleChildScrollView({
    super.key,
    required this.child,
    this.controller,
    this.physics,
    this.padding,
    this.reverse = false,
    this.primary,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  @override
  Widget build(BuildContext context) {
    return TutorialBlocker(
      scrollController: controller,
      child: SingleChildScrollView(
        controller: controller,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        padding: padding,
        reverse: reverse,
        primary: primary,
        clipBehavior: clipBehavior,
        restorationId: restorationId,
        keyboardDismissBehavior: keyboardDismissBehavior,
        child: child,
      ),
    );
  }
}
