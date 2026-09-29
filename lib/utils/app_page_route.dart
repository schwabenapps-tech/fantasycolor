import 'package:flutter/cupertino.dart';

/// Shared push route: soft fade + iOS edge-swipe back + Android system back.
class AppPageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  AppPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    this.title,
    super.fullscreenDialog = false,
  });

  final WidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  final bool maintainState;

  @override
  final String? title;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // CupertinoRouteTransitionMixin still wraps [buildPage] with the iOS
    // back-gesture detector; we only replace the visual transition.
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}
