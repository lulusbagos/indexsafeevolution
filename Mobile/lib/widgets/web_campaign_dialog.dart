import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api.dart';

class WebCampaignDialog extends StatefulWidget {
  static bool _isShowing = false;
  final int campaignId;
  final String title;
  final String url;
  final bool isDismissible;
  final String nik;
  final String nama;
  final String depart;

  const WebCampaignDialog({
    super.key,
    required this.campaignId,
    required this.title,
    required this.url,
    this.isDismissible = true,
    required this.nik,
    required this.nama,
    required this.depart,
  });

  /// Helper static untuk mengecek ke server apakah ada kampanye aktif yang ditargetkan untuk NIK ini,
  /// serta memvalidasi aturan frekuensi tampilan (misal: 1x sehari).
  static Future<void> checkAndShow(
    BuildContext context, {
    required String nik,
    required String nama,
    required String depart,
  }) async {
    if (nik.isEmpty || _isShowing) return;

    try {
      final api = ApiService();
      final res = await api.getActiveWebCampaign(nik);
      res.fold((_) {}, (data) async {
        final isActive = data['active'] == true;
        if (!isActive) return;

        final campaignId = data['id'] as int? ?? 1;
        final frequency = (data['frequency'] as String? ?? 'once_per_day').toLowerCase();
        final prefs = await SharedPreferences.getInstance();

        // 1. Cek frekuensi sekali seumur hidup
        if (frequency == 'once_forever') {
          final isCompleted = prefs.getBool('web_campaign_done_$campaignId') ?? false;
          if (isCompleted) return;
        }

        // 2. Cek frekuensi sekali per hari
        if (frequency == 'once_per_day') {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final lastShown = prefs.getString('web_campaign_date_$campaignId');
          if (lastShown == today) return;
          // Tandai sudah tampil hari ini
          await prefs.setString('web_campaign_date_$campaignId', today);
        }

        if (!context.mounted) return;

        final isDismissible = data['is_dismissible'] as bool? ?? true;
        final targetUrl = data['url'] as String? ?? '';
        final title = data['title'] as String? ?? 'Kuis & Game K3';

        if (targetUrl.isEmpty) return;

        _isShowing = true;
        try {
          await showDialog(
            context: context,
            barrierDismissible: isDismissible,
            builder: (ctx) => PopScope(
              canPop: isDismissible,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: WebCampaignDialog(
                  campaignId: campaignId,
                  title: title,
                  url: targetUrl,
                  isDismissible: isDismissible,
                  nik: nik,
                  nama: nama,
                  depart: depart,
                ),
              ),
            ),
          );
        } finally {
          _isShowing = false;
        }
      });
    } catch (_) {}
  }

  @override
  State<WebCampaignDialog> createState() => _WebCampaignDialogState();
}

class _WebCampaignDialogState extends State<WebCampaignDialog> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    _hasError = false;

    // 1. Bangun URL dengan query parameters NIK, Nama, dan Departemen
    var rawUrl = widget.url.trim();
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      rawUrl = 'https://$rawUrl';
    }
    final initialUri = Uri.tryParse(rawUrl) ?? Uri.parse('https://google.com');
    final queryParams = Map<String, String>.from(initialUri.queryParameters);
    queryParams['nik'] = widget.nik;
    queryParams['nama'] = widget.nama;
    queryParams['dept'] = widget.depart;
    queryParams['source'] = 'indexsafe_mobile';

    final finalUri = initialUri.replace(queryParameters: queryParams);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _progress = 10;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _progress = 100);
            try {
              _controller.runJavaScript('''
                window.Indexsafe = {
                  close: function() {
                    if (window.IndexsafeBridge) {
                      window.IndexsafeBridge.postMessage(JSON.stringify({action: "close"}));
                    }
                  }
                };
              ''');
            } catch (_) {}
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      // 2. JavaScript Channel untuk menerima sinyal tutup atau selesai dari Web
      ..addJavaScriptChannel(
        'IndexsafeBridge',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final data = json.decode(message.message);
            if (data is Map && data['action'] == 'close') {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('web_campaign_done_${widget.campaignId}', true);
              if (mounted) {
                Navigator.of(context).pop();
              }
            }
          } catch (_) {
            if (message.message.toLowerCase().contains('close')) {
              if (mounted) Navigator.of(context).pop();
            }
          }
        },
      )
      ..loadRequest(finalUri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    color: Color(0xFF14B8A6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'User: ${widget.nik} • ${widget.nama}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isDismissible)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    tooltip: 'Tutup',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),

          // Loading Progress Bar
          if (_progress < 100 && !_hasError)
            LinearProgressIndicator(
              value: _progress / 100.0,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
              minHeight: 3,
            ),

          // WebView Body or Error State
          Expanded(
            child: _hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          const Text(
                            'Gagal Memuat Halaman Web',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _errorMessage.isNotEmpty ? _errorMessage : 'Pastikan koneksi internet stabil.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                            onPressed: () {
                              _initWebViewController();
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
