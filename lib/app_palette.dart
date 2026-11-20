import 'package:flutter/material.dart';

/// Violet, pearl, and indigo accents on a white canvas.
abstract final class AppPalette {
  static const deep = Color(0xff32245f);
  static const primary = Color(0xff6c4cce);
  static const bright = Color(0xff9d77f5);
  static const pearl = Color(0xffe8dcff);
  static const mist = Color(0xfff6f2ff);
  static const ink = Color(0xff262038);
  static const muted = Color(0xff777083);
  static const line = Color(0xffe6dff1);

  static const metallic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xff493580),
      Color(0xff9b73e8),
      Color(0xffe6d7ff),
      Color(0xff7860c6),
    ],
    stops: [0, .39, .67, 1],
  );
  static const topGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xffd7c6f5), Color(0xffefe7ff), Colors.white],
    stops: [0, .5, 1],
  );

  static const pageGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xffd9c8f9), Color(0xffeee8fc), Colors.white],
    stops: [0, .48, 1],
  );
}
