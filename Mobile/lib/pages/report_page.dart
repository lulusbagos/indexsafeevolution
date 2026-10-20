import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api.dart';
import '../widgets/top_bar.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    super.key,
    this.title = 'Global Report',
    this.url,
  });

  final String? title;
  final String? url;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _api = ApiService();
  late final WebViewController _webViewCtrl;
  bool? _isConnect;
  bool _isLoading = true;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();

    _webViewCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF050811))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[ReportWebView] Error: ${error.description}');
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    _initUrlAndCheckConnection();
  }

  Future<void> _initUrlAndCheckConnection() async {
    final con = await Connectivity().checkConnectivity();
    final hasNet = con.contains(ConnectivityResult.wifi) ||
        con.contains(ConnectivityResult.mobile) ||
        con.contains(ConnectivityResult.ethernet);

    if (mounted) {
      setState(() => _isConnect = hasNet);
    }

    if (hasNet) {
      String targetUrl = widget.url ?? '';
      if (targetUrl.isEmpty) {
        targetUrl = await _api.getEmbedWebUrl(type: 'global_report');
      }
      _currentUrl = targetUrl;
      if (mounted) {
        _webViewCtrl.loadRequest(Uri.parse(targetUrl));
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050811),
      appBar: TopBar(
        title: widget.title ?? 'Global Report',
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          if (_currentUrl.isNotEmpty) {
            _webViewCtrl.loadRequest(Uri.parse(_currentUrl));
          } else {
            _initUrlAndCheckConnection();
          }
        },
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        tooltip: 'Muat Ulang',
        child: const Icon(Icons.refresh_rounded, size: 20),
      ),
      body: Stack(
        children: [
          if (_isConnect == true)
            WebViewWidget(controller: _webViewCtrl)
          else if (_isConnect == false)
            const Center(
              child: Image(
                image: AssetImage('assets/images/no-connection.png'),
                width: 300,
              ),
            )
          else
            const Center(
              child: Image(
                image: AssetImage('assets/images/progress.gif'),
                width: 150,
              ),
            ),
          if (_isLoading && _isConnect == true)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFF0F172A),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }
}
