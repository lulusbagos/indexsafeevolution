import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/history_page.dart';

class DailyPage extends StatelessWidget {
  const DailyPage(this.module, {super.key});

  final Module module;

  @override
  Widget build(BuildContext context) {
    return HistoryPage(module, History.summary);
  }
}
