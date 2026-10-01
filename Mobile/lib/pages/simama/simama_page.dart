import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/history_page.dart';

class SimamaPage extends StatelessWidget {
  const SimamaPage(this.module, {super.key});

  final Module module;

  @override
  Widget build(BuildContext context) {
    return HistoryPage(module, History.summary);
  }
}
