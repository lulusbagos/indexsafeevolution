import 'package:flutter/material.dart';

import '../widgets/button_app.dart';
import '../widgets/top_bar.dart';

class ComingSoonPage extends StatefulWidget {
  const ComingSoonPage(this.title, {super.key});

  final String? title;

  @override
  State<ComingSoonPage> createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends State<ComingSoonPage> {
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
      appBar: TopBar(title: widget.title?.replaceAll('\n', ' ')),
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
