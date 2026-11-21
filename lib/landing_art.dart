import 'package:flutter/material.dart';

import 'app_palette.dart';

class LandingArt extends StatelessWidget {
  const LandingArt({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 306,
      height: 232,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 43,
            right: 43,
            top: 15,
            bottom: 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.mist,
                border: Border.all(color: AppPalette.pearl, width: 1.5),
              ),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 14,
            child: Container(height: 1, color: AppPalette.pearl),
          ),
          Positioned(
            left: 89,
            top: 10,
            child: Container(
              width: 132,
              height: 206,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppPalette.metallic,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3a145a43),
                    blurRadius: 22,
                    offset: Offset(0, 11),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: AppPalette.metallic,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'STOCKROOM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 7.5,
                              letterSpacing: .3,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.deep,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        color: AppPalette.mist,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 51,
                        color: AppPalette.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 13,
                      decoration: BoxDecoration(
                        gradient: AppPalette.metallic,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 5,
                      width: 65,
                      decoration: BoxDecoration(
                        color: AppPalette.pearl,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 1,
            top: 68,
            child: _floating(
              Icons.qr_code_scanner_rounded,
              'SCAN',
              'Ready to borrow',
            ),
          ),
          Positioned(
            right: 0,
            top: 124,
            child: _floating(Icons.inventory_2_outlined, 'TRACK', 'Every item'),
          ),
          const Positioned(
            left: 39,
            top: 34,
            child: Icon(Icons.auto_awesome, color: AppPalette.bright, size: 18),
          ),
          const Positioned(
            right: 30,
            top: 32,
            child: Icon(Icons.circle, color: AppPalette.pearl, size: 13),
          ),
        ],
      ),
    ),
  );

  Widget _floating(IconData icon, String title, String subtitle) => Container(
    width: 99,
    height: 61,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppPalette.line),
      borderRadius: BorderRadius.circular(13),
      boxShadow: const [
        BoxShadow(
          color: Color(0x15145a43),
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppPalette.primary),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppPalette.deep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 8, color: AppPalette.muted),
        ),
      ],
    ),
  );
}
