import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page transitions for award-winning navigation feel.
/// Uses spring physics and fade/scale combinations for a premium experience.

/// Slide + fade transition for forward navigation (push).
class SlideFadeTransition<T> extends PageRouteBuilder<T> {
  SlideFadeTransition({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurveTween(curve: Curves.easeOutCubic);
            final offset = Tween<Offset>(
              begin: const Offset(0.0, 0.08),
              end: Offset.zero,
            ).chain(curve);
            final fade = Tween<double>(begin: 0.0, end: 1.0).chain(curve);
            return FadeTransition(
              opacity: fade.animate(animation),
              child: SlideTransition(
                position: offset.animate(animation),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
        );
}

/// Scale + fade transition for modal-like screens (detail pages).
class ScaleFadeTransition<T> extends PageRouteBuilder<T> {
  ScaleFadeTransition({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurveTween(curve: Curves.easeOutBack);
            final scale = Tween<double>(begin: 0.92, end: 1.0).chain(curve);
            final fade = Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: Curves.easeOut),
            );
            return FadeTransition(
              opacity: fade.animate(animation),
              child: ScaleTransition(
                scale: scale.animate(animation),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}

/// Fade transition for tab switches (subtle, no movement).
class FadePageTransition<T> extends PageRouteBuilder<T> {
  FadePageTransition({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

/// Helper to wrap a screen in a slide-fade transition via GoRouter.
/// Usage: GoRoute(pageBuilder: (state) => slideFadePage(child: MyScreen()))
CustomTransitionPage<T> slideFadePage<T>({
  required Widget child,
  String? name,
  Object? arguments,
}) {
  return CustomTransitionPage<T>(
    child: child,
    name: name,
    arguments: arguments,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurveTween(curve: Curves.easeOutCubic);
      final offset = Tween<Offset>(
        begin: const Offset(0.0, 0.08),
        end: Offset.zero,
      ).chain(curve);
      final fade = Tween<double>(begin: 0.0, end: 1.0).chain(curve);
      return FadeTransition(
        opacity: fade.animate(animation),
        child: SlideTransition(
          position: offset.animate(animation),
          child: child,
        ),
      );
    },
  );
}

/// Helper to wrap a screen in a scale-fade transition via GoRouter.
CustomTransitionPage<T> scaleFadePage<T>({
  required Widget child,
  String? name,
  Object? arguments,
}) {
  return CustomTransitionPage<T>(
    child: child,
    name: name,
    arguments: arguments,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurveTween(curve: Curves.easeOutBack);
      final scale = Tween<double>(begin: 0.92, end: 1.0).chain(curve);
      final fade = Tween<double>(begin: 0.0, end: 1.0).chain(
        CurveTween(curve: Curves.easeOut),
      );
      return FadeTransition(
        opacity: fade.animate(animation),
        child: ScaleTransition(
          scale: scale.animate(animation),
          child: child,
        ),
      );
    },
  );
}
