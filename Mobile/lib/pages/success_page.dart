import 'package:flutter/material.dart';

import '../utils/globals.dart' as globals;
import '../widgets/button_app.dart';
import 'home_page.dart';

class SuccessPage extends StatefulWidget {
  const SuccessPage({this.msg, super.key});

  final String? msg;

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> {
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
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        globals.currentPage = 0;
        await Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(top: 150, bottom: 20),
                    alignment: Alignment.center,
                    child: const Image(
                      image: AssetImage('assets/images/success.png'),
                      width: 220,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      widget.msg ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              width: 300,
              child: buttonApp(
                label: 'MENU UTAMA',
                onPressed: () async {
                  globals.currentPage = 0;
                  await Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
