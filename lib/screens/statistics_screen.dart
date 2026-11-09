import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/statistics/completion_statistics_tab.dart';
import '../widgets/statistics/overview_statistics_tab.dart';
import '../widgets/statistics/time_statistics_tab.dart';
import 'components/app_drawer_menu.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final hasData = appState.books.isNotEmpty ||
            appState.plans.isNotEmpty ||
            appState.historyBox.isNotEmpty;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Статистика'),
              bottom: hasData
                  ? const TabBar(
                      tabs: [
                        Tab(text: 'Выполнение'),
                        Tab(text: 'Обзор'),
                        Tab(text: 'Время'),
                      ],
                    )
                  : null,
            ),
            endDrawer: const AppDrawerMenu(),
            body: hasData
                ? const TabBarView(
                    children: [
                      CompletionStatisticsTab(),
                      OverviewStatisticsTab(),
                      TimeStatisticsTab(),
                    ],
                  )
                : const Center(
                    child: Text('Нет данных для отображения.'),
                  ),
          ),
        );
      },
    );
  }
}
