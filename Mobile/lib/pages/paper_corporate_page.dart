import 'package:flutter/material.dart';

import '../widgets/button_app.dart';
import '../widgets/top_bar.dart';

class PaperCorporatePage extends StatefulWidget {
  const PaperCorporatePage({super.key});

  @override
  State<PaperCorporatePage> createState() => _PaperCorporatePageState();
}

class _PaperCorporatePageState extends State<PaperCorporatePage> {
  @override
  void initState() {
    super.initState();

    /** */
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBar(title: 'Paper Corporate'),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Image(
                image: AssetImage('assets/images/coming-soon.gif'),
                width: 300,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            width: 300,
            child: buttonApp(
              label: 'BACK',
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
        ],
      ),
    );
  }
}
