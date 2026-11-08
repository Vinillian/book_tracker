import 'package:flutter/material.dart';

import '../activity_calendar.dart';

class CompletionStatisticsTab extends StatelessWidget {
  const CompletionStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListView(
      padding: EdgeInsets.all(4),
      children: [
        ActivityCalendar(),
      ],
    );
  }
}
