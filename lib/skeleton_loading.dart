import 'package:flutter/material.dart';

import 'app_palette.dart';

class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) =>
        Opacity(opacity: .48 + controller.value * .42, child: child),
    child: widget.child,
  );
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppPalette.mist,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class LeaderboardSkeleton extends StatelessWidget {
  const LeaderboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const SkeletonBlock(width: 190, height: 33),
        const SizedBox(height: 9),
        const SkeletonBlock(width: 245, height: 15),
        const SizedBox(height: 25),
        for (var index = 0; index < 5; index++) ...[
          Container(
            height: 116,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppPalette.line),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                SkeletonBlock(width: 44, height: 44, radius: 22),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonBlock(width: 145, height: 17),
                      SizedBox(height: 10),
                      SkeletonBlock(width: 185, height: 12),
                      SizedBox(height: 9),
                      SkeletonBlock(width: 88, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      children: [
        const Row(
          children: [
            SkeletonBlock(width: 46, height: 46, radius: 23),
            SizedBox(width: 12),
            Expanded(child: SkeletonBlock(height: 27)),
            SizedBox(width: 12),
            SkeletonBlock(width: 32, height: 32),
          ],
        ),
        const SizedBox(height: 19),
        const SkeletonBlock(width: 155, height: 14),
        const SizedBox(height: 9),
        const SkeletonBlock(width: 240, height: 14),
        const SizedBox(height: 18),
        const SkeletonBlock(width: 220, height: 30),
        const SizedBox(height: 22),
        const SkeletonBlock(height: 42, radius: 21),
        const SizedBox(height: 20),
        Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              const Expanded(child: SkeletonBlock(height: 92, radius: 16)),
            ],
          ],
        ),
        const SizedBox(height: 31),
        const SkeletonBlock(width: 150, height: 25),
        const SizedBox(height: 16),
        for (var index = 0; index < 3; index++) ...[
          const SkeletonBlock(height: 68, radius: 17),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
}
