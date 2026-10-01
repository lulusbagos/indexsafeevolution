import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/history_page.dart';

class P5MPage extends StatelessWidget {
  const P5MPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HistoryPage(Module.p5m, History.summary);
  }
}
