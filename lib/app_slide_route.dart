import 'package:flutter/material.dart';

import 'header_haze.dart';

/// Slides a complete opaque page over the current page in either direction.
Route<T> appSlideRoute<T>({required WidgetBuilder builder}) =>
    PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          PageGradientBackground(child: builder(context)),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          ClipRect(
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    ),
                  ),
              child: child,
            ),
          ),
    );
