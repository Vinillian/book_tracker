import 'package:flutter/material.dart';

import '../activity_calendar.dart';

class CompletionStatisticsTab extends StatefulWidget {
  const CompletionStatisticsTab({super.key});

  @override
  State<CompletionStatisticsTab> createState() => _CompletionStatisticsTabState();
}

class _CompletionStatisticsTabState extends State<CompletionStatisticsTab>
    with AutomaticKeepAliveClientMixin<CompletionStatisticsTab> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(4),
      children: const [
        ActivityCalendar(),
      ],
    );
  }
}
