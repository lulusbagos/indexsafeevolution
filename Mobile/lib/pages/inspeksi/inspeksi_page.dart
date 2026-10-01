import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/option_page.dart';

class InspeksiPage extends StatelessWidget {
  const InspeksiPage(this.module, {super.key});

  final Module module;

  @override
  Widget build(BuildContext context) {
    return OptionPage(module);
  }
}
