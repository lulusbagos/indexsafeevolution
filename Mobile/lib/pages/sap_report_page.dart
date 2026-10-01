import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api.dart';
import '../services/preference.dart';
import '../widgets/top_bar.dart';

class SapReportPage extends StatefulWidget {
  const SapReportPage({super.key});

  @override
  State<SapReportPage> createState() => _SapReportPageState();
}

class _SapReportPageState extends State<SapReportPage> {
  final _api = ApiService();
  final _webViewCtrl = WebViewController();
  final _profile = PreferenceService.getProfile();
  bool? _isConnect;

  @override
  void initState() {
    super.initState();

    _webViewCtrl
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(
          '${_api.baseUrl}/dashboard/${_profile?.id}/${_profile?.userId}'));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var con = await Connectivity().checkConnectivity();
      if (con.contains(ConnectivityResult.wifi) == false &&
          con.contains(ConnectivityResult.mobile) == false) {
        setState(() => _isConnect = false);
      } else {
        setState(() => _isConnect = true);
      }
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBar(title: 'SAP Report'),
      body: (_isConnect == true)
          ? WebViewWidget(controller: _webViewCtrl)
          : (_isConnect == false)
              ? const Center(
                  child: Image(
                    image: AssetImage('assets/images/no-connection.png'),
                    width: 300,
                  ),
                )
              : const Center(
                  child: Image(
                    image: AssetImage('assets/images/progress.gif'),
                    width: 150,
                  ),
                ),
    );
  }
}
