import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/database.dart';
import '../services/offline_sync_service.dart';
import '../services/violation_receipt_pdf_service.dart';

class ViolationQueuePage extends StatefulWidget {
  const ViolationQueuePage({super.key});

  @override
  State<ViolationQueuePage> createState() => _ViolationQueuePageState();
}

class _ViolationQueuePageState extends State<ViolationQueuePage> {
  final _db = DatabaseService();
  bool _loading = true;
  bool _syncing = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _db.getOfflineViolationHistory();
    if (mounted)
      setState(() {
        _items = items;
        _loading = false;
      });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await OfflineSyncService.instance.syncPermitViolationQueue();
    await _load();
    if (mounted) setState(() => _syncing = false);
  }

  Map<String, dynamic> _payload(Map<String, dynamic> row) {
    try {
      final data = jsonDecode(row['payload']?.toString() ?? '{}');
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((e) => e['is_synced'] != 1).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Antrean Pelanggaran',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pending > 0
                          ? const Color(0xFFFFF7ED)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: pending > 0
                            ? const Color(0xFFFED7AA)
                            : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                          pending > 0
                              ? Icons.cloud_upload_outlined
                              : Icons.verified_rounded,
                          color: pending > 0
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF059669)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                        pending > 0
                            ? '$pending laporan menunggu jaringan'
                            : 'Semua laporan sudah tersinkron',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A)),
                      )),
                    ]),
                  ),
                  if (pending > 0) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _syncing ? null : _sync,
                        icon: _syncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.sync_rounded),
                        label: Text(_syncing
                            ? 'Mengirim laporan...'
                            : 'Coba kirim sekarang'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 72),
                      child: Center(
                          child: Text(
                              'Belum ada laporan pelanggaran dari perangkat ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B)))),
                    ),
                  ..._items.map((row) {
                    final data = _payload(row);
                    final synced = row['is_synced'] == 1;
                    final name = data['violatorName']?.toString() ?? 'Karyawan';
                    final type =
                        data['kriteriaNama']?.toString() ?? 'Pelanggaran K3';
                    final created = row['created_at']
                            ?.toString()
                            .replaceFirst('T', ' ')
                            .split('.')
                            .first ??
                        '-';
                    final pdfPath = data['localReceiptPath']?.toString() ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                      color: synced
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Icon(
                                      synced
                                          ? Icons.check_circle_rounded
                                          : Icons.schedule_send_rounded,
                                      color: synced
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFEA580C))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15)),
                                    Text(type,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12)),
                                  ])),
                              _statusPill(synced),
                            ]),
                            const SizedBox(height: 10),
                            Text('Dibuat $created',
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 11)),
                            if (pdfPath.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    ViolationReceiptPdfService.share(pdfPath),
                                icon: const Icon(Icons.picture_as_pdf_outlined,
                                    size: 18),
                                label: const Text('Bagikan bukti PDF'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB45309)),
                              ),
                            ],
                          ]),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _statusPill(bool synced) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: synced ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
            borderRadius: BorderRadius.circular(20)),
        child: Text(synced ? 'TERKIRIM' : 'MENUNGGU',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: synced
                    ? const Color(0xFF047857)
                    : const Color(0xFFC2410C))),
      );
}
