import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/history_page.dart';

class SafetyTalkPage extends StatelessWidget {
  const SafetyTalkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HistoryPage(Module.safety, History.summary);
  }
}
