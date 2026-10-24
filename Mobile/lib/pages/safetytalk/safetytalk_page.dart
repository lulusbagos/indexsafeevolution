import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../widgets/top_bar.dart';
import 'safetytalk_form_page.dart';

class SafetyTalkPage extends StatefulWidget {
  const SafetyTalkPage({super.key});

  @override
  State<SafetyTalkPage> createState() => _SafetyTalkPageState();
}

class _SafetyTalkPageState extends State<SafetyTalkPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _talks = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final data = await _api.getSafetyTalkData();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _talks = List<Map<String, dynamic>>.from(data?['talks'] ?? const []);
      _error = data == null ? 'Riwayat Safety Talk belum dapat dimuat. Periksa koneksi lalu tarik untuk mencoba lagi.' : null;
    });
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SafetyTalkFormPage(existingId: item?['id'] as int?)));
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Safety Talk?'),
      content: Text('Laporan “${item['judul']}” akan dihapus dari MBS dan tidak dapat dikembalikan.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton.tonal(style: FilledButton.styleFrom(foregroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus'))],
    ));
    if (ok != true) return;
    final deleted = await _api.deleteSafetyTalk(item['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deleted ? 'Safety Talk berhasil dihapus.' : 'Gagal menghapus Safety Talk.')));
    if (deleted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const TopBar(title: 'Safety Talk', back: 2),
    floatingActionButton: FloatingActionButton.extended(backgroundColor: const Color(0xFFF43F5E), foregroundColor: Colors.white, onPressed: () => _openForm(), icon: const Icon(Icons.add_rounded), label: const Text('Buat Safety Talk')),
    body: RefreshIndicator(onRefresh: _load, child: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 100), children: [
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFBE123C)])), child: const Row(children: [Icon(Icons.campaign_rounded, color: Colors.white, size: 30), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Safety Talk & Briefing', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Dokumentasikan agenda pengarahan K3.', style: TextStyle(color: Colors.white, fontSize: 12))]))])),
      const SizedBox(height: 20), Text('Log Briefing Keselamatan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 10),
      if (_error != null) _ErrorCard(message: _error!, retry: _load),
      if (_error == null && _talks.isEmpty) const Padding(padding: EdgeInsets.only(top: 44), child: Center(child: Text('Belum ada Safety Talk.'))),
      ..._talks.map((item) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(backgroundColor: Color(0x1AF43F5E), child: Icon(Icons.campaign_rounded, color: Color(0xFFF43F5E))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['judul']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5), Text(item['areaLokasi']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            PopupMenuButton<String>(onSelected: (v) => v == 'edit' ? _openForm(item) : _delete(item), itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit laporan')), PopupMenuItem(value: 'delete', child: Text('Hapus laporan'))]),
          ]),
        ),
      )),
    ])),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});
  final String message; final VoidCallback retry;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [const Icon(Icons.cloud_off_rounded, size: 36), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center), TextButton(onPressed: retry, child: const Text('Coba lagi'))])));
}
