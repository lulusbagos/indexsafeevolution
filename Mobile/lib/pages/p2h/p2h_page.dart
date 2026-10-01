import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/history_page.dart';

class P2HPage extends StatelessWidget {
  const P2HPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HistoryPage(Module.p2h, History.summary);
  }
}
