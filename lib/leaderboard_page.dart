import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'skeleton_loading.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key, required this.future});

  final Future<dynamic> future;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 24, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Leaderboard',
                      style: TextStyle(
                        color: AppPalette.deep,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<dynamic>(
                  future: future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData && !snapshot.hasError) {
                      return const LeaderboardSkeleton();
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load leaderboard: ${snapshot.error}',
                        ),
                      );
                    }
                    final people = List<dynamic>.from(snapshot.data as List);
                    if (people.isEmpty) {
                      return const Center(child: Text('No student loans yet.'));
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        const Text(
                          'Top borrowers',
                          style: TextStyle(
                            color: AppPalette.deep,
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Students making the most of E-QUIP',
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 23),
                        for (var index = 0; index < people.length; index++)
                          _LeaderboardCard(
                            person: Map<String, dynamic>.from(
                              people[index] as Map,
                            ),
                            index: index,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.person, required this.index});

  final Map<String, dynamic> person;
  final int index;

  @override
  Widget build(BuildContext context) {
    final first = index == 0;
    final program = '${person['program'] ?? ''}'.trim();
    final year = '${person['year_level'] ?? ''}'.trim();
    final section = '${person['section'] ?? ''}'.trim();
    final details = [
      year,
      section,
    ].where((value) => value.isNotEmpty).join(' · ');
    final count = (person['borrow_count'] as num?)?.toInt() ?? 0;
    final textColor = first ? Colors.white : AppPalette.ink;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: first ? null : Colors.white,
        gradient: first
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff0b3d2e),
                  Color(0xff145a43),
                  Color(0xff2f8f6f),
                  Color(0xff0b3d2e),
                ],
                stops: [0, .4, .7, 1],
              )
            : null,
        borderRadius: BorderRadius.circular(22),
        border: first ? null : Border.all(color: AppPalette.line),
        boxShadow: first
            ? [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: .18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: first
                ? Colors.white.withValues(alpha: .22)
                : AppPalette.mist,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: first ? Colors.white : AppPalette.deep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${person['name'] ?? 'Student'}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                if (program.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    program,
                    style: TextStyle(
                      color: textColor.withValues(alpha: .82),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: TextStyle(
                      color: textColor.withValues(alpha: .82),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '$count ${count == 1 ? 'borrow' : 'borrows'}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (index < 3)
            Icon(
              Icons.emoji_events_rounded,
              color: first ? Colors.white : AppPalette.primary,
              size: 23,
            ),
        ],
      ),
    );
  }
}
