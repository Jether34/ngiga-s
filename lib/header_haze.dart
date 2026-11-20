import 'dart:ui';

import 'package:flutter/material.dart';

class HeaderHaze extends StatelessWidget {
  const HeaderHaze({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xffd9c9fa), Color(0xfff7f5ff), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: -28,
            child: Container(
              width: 110,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0x887b58d8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 19, sigmaY: 19),
            child: Container(color: Colors.white.withValues(alpha: .55)),
          ),
        ],
      ),
    ),
  );
}

Widget pageWithHaze(Widget child) => Column(
  children: [
    const HeaderHaze(height: 30),
    Expanded(child: child),
  ],
);
