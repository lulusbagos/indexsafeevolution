import 'package:flutter/material.dart';

import '../pages/history/history_page.dart';
import '../utils/enums.dart';
import '../utils/globals.dart' as globals;
import '../utils/helpers.dart';

void alertSuccess(BuildContext ctx, Module module,
    {String msg = 'disimpan', int? lastId}) {
  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      content: Container(
        width: MediaQuery.of(context).size.width,
        height: 350,
        alignment: Alignment.center,
        child: Column(
          children: [
            const Image(
              image: AssetImage('assets/images/success.gif'),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                'Data ${pageTitle(module)} berhasil $msg!',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () async {
                globals.goHome = true;
                await Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HistoryPage(
                            module,
                            (msg == 'disimpan')
                                ? History.summary
                                : History.monitoring,
                            lastId: lastId,
                          )),
                  (route) => false,
                );
              },
            )
          ],
        ),
      ),
      contentPadding: const EdgeInsets.all(15),
    ),
  );
  return;
}

void alertFailed(BuildContext ctx, Module module, {String msg = 'disimpan'}) {
  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      content: Container(
        width: MediaQuery.of(context).size.width,
        height: 350,
        alignment: Alignment.center,
        child: Column(
          children: [
            const Image(
              image: AssetImage('assets/images/error.gif'),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                'Data ${pageTitle(module)} gagal $msg!',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
      ),
      contentPadding: const EdgeInsets.all(15),
    ),
  );
  return;
}
