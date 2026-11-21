import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_palette.dart';

class HeaderHaze extends StatelessWidget {
  const HeaderHaze({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 19, sigmaY: 19),
        child: ColoredBox(color: Colors.white.withValues(alpha: .08)),
      ),
    ),
  );
}

class PageGradientBackground extends StatelessWidget {
  const PageGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: RepaintBoundary(
          child: ColoredBox(
            color: Colors.white,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 390,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppPalette.pageGlow),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(child: child),
    ],
  );
}

Widget pageWithHaze(Widget child) => Column(
  children: [
    const HeaderHaze(height: 30),
    Expanded(child: child),
  ],
);
