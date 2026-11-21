import 'package:flutter/material.dart';

/// Forest, emerald, beige, and cream from Avelino's webpage.
abstract final class AppPalette {
  static const deep = Color(0xff0b3d2e);
  static const primary = Color(0xff145a43);
  static const bright = Color(0xff2f8f6f);
  static const pearl = Color(0xffd7c7a1);
  static const mist = Color(0xffedf5ef);
  static const ink = Color(0xff0f0f0f);
  static const muted = Color(0xff617168);
  static const line = Color(0xffdce7df);

  static const metallic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xff0b3d2e),
      Color(0xff145a43),
      Color(0xffd7c7a1),
      Color(0xff2f8f6f),
    ],
    stops: [0, .39, .67, 1],
  );
  static const topGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xffd7c7a1), Color(0xffedf5ef), Colors.white],
    stops: [0, .5, 1],
  );

  static const pageGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xffd7c7a1), Color(0xffedf5ef), Colors.white],
    stops: [0, .48, 1],
  );
}
