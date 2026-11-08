import 'package:flutter/material.dart';

import '../time_analytics_section.dart';

class TimeStatisticsTab extends StatelessWidget {
  const TimeStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListView(
      padding: EdgeInsets.all(4),
      children: [
        TimeAnalyticsSection(),
      ],
    );
  }
}
