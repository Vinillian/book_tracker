import 'package:flutter/material.dart';

import '../time_analytics_section.dart';

class TimeStatisticsTab extends StatefulWidget {
  const TimeStatisticsTab({super.key});

  @override
  State<TimeStatisticsTab> createState() => _TimeStatisticsTabState();
}

class _TimeStatisticsTabState extends State<TimeStatisticsTab>
    with AutomaticKeepAliveClientMixin<TimeStatisticsTab> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(4),
      children: const [
        TimeAnalyticsSection(),
      ],
    );
  }
}
