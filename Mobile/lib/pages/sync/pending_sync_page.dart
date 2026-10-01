import 'dart:io';
import 'package:flutter/material.dart';

import '../../services/offline_sync_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/top_bar.dart';

class PendingSyncPage extends StatefulWidget {
  const PendingSyncPage({super.key});

  @override
  State<PendingSyncPage> createState() => _PendingSyncPageState();
}

class _PendingSyncPageState extends State<PendingSyncPage> {
  final OfflineSyncService _syncService = OfflineSyncService();
  List<PendingSyncItem> _items = [];
  bool _isLoading = true;
  bool _isSyncingAll = false;
  int? _syncingItemId;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _syncService.pendingCountNotifier.addListener(_onPendingChanged);
  }

  @override
  void dispose() {
    _syncService.pendingCountNotifier.removeListener(_onPendingChanged);
    super.dispose();
  }

  void _onPendingChanged() {
    if (mounted) {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    final items = await _syncService.getPendingItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _syncSingle(PendingSyncItem item) async {
    setState(() => _syncingItemId = item.id);
    final ok = await _syncService.syncItem(item);
    if (!mounted) return;
    setState(() => _syncingItemId = null);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil sinkron ${item.moduleTitle}'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal sinkron ${item.moduleTitle}. Periksa koneksi internet.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _syncAll() async {
    if (_items.isEmpty || _isSyncingAll) return;
    setState(() => _isSyncingAll = true);

    final res = await _syncService.syncAll();
    if (!mounted) return;
    setState(() => _isSyncingAll = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sinkronisasi selesai: ${res.success} berhasil, ${res.failed} gagal.'),
        backgroundColor: res.failed == 0 ? const Color(0xFF16A34A) : const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _loadItems();
  }

  /// Menampilkan modal BottomSheet untuk melihat (VIEW) detail lengkap data lokal
  void _showDetailBottomSheet(PendingSyncItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final hasImage = item.imagePath != null &&
            item.imagePath!.isNotEmpty &&
            File(item.imagePath!).existsSync();

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Info
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.moduleTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: item.color,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'OFFLINE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tersimpan di memori lokal HP',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Field 1: Judul
                _buildDetailRow(
                  label: 'JUDUL / TEMUAN',
                  value: item.title,
                  isBold: true,
                ),
                const SizedBox(height: 12),

                // Field 2: Waktu & Tanggal
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(
                        label: 'TANGGAL',
                        value: item.date.isNotEmpty ? item.date : '-',
                      ),
                    ),
                    Expanded(
                      child: _buildDetailRow(
                        label: 'JAM / WAKTU',
                        value: item.time.isNotEmpty ? item.time : '-',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Field 3: Lokasi
                if (item.location.isNotEmpty) ...[
                  _buildDetailRow(
                    label: 'LOKASI TEMUAN',
                    value: item.location,
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 12),
                ],

                // Field 4: Catatan / Keterangan
                if (item.detailText != null && item.detailText!.isNotEmpty) ...[
                  _buildDetailRow(
                    label: 'KETERANGAN / TINDAKAN',
                    value: item.detailText!,
                  ),
                  const SizedBox(height: 12),
                ],

                // Field 5: Lampiran Foto (Jika Ada)
                if (hasImage) ...[
                  const Text(
                    'FOTO DOKUMENTASI LOKAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(item.imagePath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 10),

                // Action Buttons inside Dialog
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _syncSingle(item);
                        },
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: const Text(
                          'Singkronkan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isBold = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'Data Belum Sinkron'),
      body: AmbientBackground(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              )
            : RefreshIndicator(
                onRefresh: _loadItems,
                color: const Color(0xFF2563EB),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (_items.isNotEmpty) ...[
                      // Summary Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.cloud_off_rounded,
                                color: Color(0xFFD97706),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_items.length} Data Tersimpan Offline',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Otomatis terkirim ke server saat tersambung internet, atau sinkronkan manual di bawah.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Auto-sync notice banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_rounded, color: Color(0xFF2563EB), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Fitur Auto-Sync Aktif: Begitu HP mendapat sinyal internet, seluruh data otomatis terkirim.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Button Sinkron Semua
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isSyncingAll ? null : _syncAll,
                          icon: _isSyncingAll
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_sync_rounded, size: 20),
                          label: Text(
                            _isSyncingAll ? 'Menyinkronkan...' : 'Sinkronkan Semua Sekarang',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'DAFTAR DATA PENDING (TAP UNTUK VIEW / DETAIL)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._items.map((item) {
                        final isThisSyncing = _syncingItemId == item.id;
                        return InkWell(
                          onTap: () => _showDetailBottomSheet(item),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: item.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(item.icon, color: item.color, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: item.color.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.moduleTitle,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: item.color,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '${item.date} ${item.time}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          if (item.location.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 13,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(width: 3),
                                                Expanded(
                                                  child: Text(
                                                    item.location,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 10),
                                // Dua Tombol: [ View Detail ] & [ Singkron ]
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 38,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _showDetailBottomSheet(item),
                                          icon: const Icon(Icons.visibility_rounded, size: 16),
                                          label: const Text(
                                            'View Detail',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF334155),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SizedBox(
                                        height: 38,
                                        child: ElevatedButton.icon(
                                          onPressed: (_isSyncingAll || isThisSyncing)
                                              ? null
                                              : () => _syncSingle(item),
                                          icon: isThisSyncing
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.cloud_upload_rounded, size: 16),
                                          label: Text(
                                            isThisSyncing ? 'Mengirim...' : 'Singkron',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      // Empty state
                      const SizedBox(height: 60),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cloud_done_rounded,
                                color: Color(0xFF16A34A),
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Semua Data Tersinkron!',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Tidak ada data laporan yang tertinggal di perangkat. Seluruh transaksi telah tersimpan aman di server pusat.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
