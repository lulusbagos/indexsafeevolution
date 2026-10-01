import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/history_page.dart';

class CoachingPage extends StatelessWidget {
  const CoachingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HistoryPage(Module.coaching, History.summary);
  }
}
