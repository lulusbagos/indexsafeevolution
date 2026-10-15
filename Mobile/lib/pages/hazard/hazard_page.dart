import 'package:flutter/material.dart';

import '../../utils/enums.dart';
import '../history/option_page.dart';

class HazardPage extends StatelessWidget {
  const HazardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OptionPage(Module.hazard);
  }
}
