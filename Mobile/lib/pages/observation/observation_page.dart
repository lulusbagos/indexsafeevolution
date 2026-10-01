import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/history_page.dart';

class ObservationPage extends StatelessWidget {
  const ObservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HistoryPage(Module.observation, History.summary);
  }
}
