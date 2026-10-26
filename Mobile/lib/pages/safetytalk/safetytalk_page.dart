import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/sync.dart';
import '../../widgets/top_bar.dart';
import 'safetytalk_form_page.dart';

const _stRed = Color(0xFFE11D48);
const _stDark = Color(0xFF0F172A);
const _stBackground = Color(0xFFF8FAFC);

class SafetyTalkPage extends StatefulWidget {
  const SafetyTalkPage({super.key});

  @override
  State<SafetyTalkPage> createState() => _SafetyTalkPageState();
}

class _SafetyTalkPageState extends State<SafetyTalkPage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String _filter = 'Semua';
  String _searchQuery = '';
  List<Map<String, dynamic>> _talks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // 1. Load Local items from SQLite
    List<Map<String, dynamic>> localItems = [];
    try {
      final rows = await _db.rawQuery(
        'SELECT id, title, judul, remark, keterangan, area, lokasi, detil_lokasi, location_detail, date, time, sync_id FROM safety_trans WHERE deleted_at IS NULL ORDER BY id DESC',
      );
      localItems = rows.map((r) {
        final map = Map<String, dynamic>.from(r);
        map['is_local'] = true;
        map['local_id'] = r['id'];
        return map;
      }).toList();
    } catch (_) {}

    // 2. Fetch server items if available
    List<Map<String, dynamic>> serverItems = [];
    try {
      final data = await _api.getSafetyTalkData();
      if (data != null && data['talks'] is List) {
        serverItems = List<Map<String, dynamic>>.from(data['talks'] as List).map((item) {
          return {
            'id': item['id'],
            'judul': item['judul'] ?? item['title'] ?? 'Safety Talk',
            'title': item['judul'] ?? item['title'] ?? 'Safety Talk',
            'lokasi': item['areaLokasi'] ?? '',
            'area': item['areaLokasi'] ?? '',
            'sync_id': item['id'],
            'is_local': false,
          };
        }).toList();
      }
    } catch (_) {}

    // Deduplicate / merge: local items take priority
    final localSyncIds = localItems
        .map((e) => e['sync_id'])
        .where((id) => id != null && id != 0)
        .toSet();

    final nonDuplicateServer = serverItems.where((s) => !localSyncIds.contains(s['id'])).toList();

    if (!mounted) return;
    setState(() {
      _talks = [...localItems, ...nonDuplicateServer];
      _loading = false;
    });
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final int? existingId = item != null ? (item['local_id'] ?? item['id']) as int? : null;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SafetyTalkFormPage(existingId: existingId),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _triggerItemSync(Map<String, dynamic> item) async {
    final localId = item['local_id'] as int?;
    if (localId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menghubungkan & menyinkronkan ke server...'),
        duration: Duration(seconds: 1),
      ),
    );

    final ok = await syncTran(_db, _api, 'safety', localId);
    if (!mounted) return;

    OfflineSyncService.instance.refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Berhasil disinkronkan ke server.' : 'Gagal sinkron. Cek koneksi Anda.'),
        backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );
    if (ok) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final title = item['judul'] ?? item['title'] ?? 'Safety Talk';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Hapus Safety Talk?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Laporan "$title" akan dihapus. Jika tersimpan di perangkat, antrean sinkronisasi akan dibatalkan.',
                style: const TextStyle(color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Hapus'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    final int? localId = item['local_id'] as int?;
    final int? syncId = item['sync_id'] as int?;

    if (localId != null) {
      try {
        await _db.update('safety_trans', {'deleted_at': DateTime.now().toIso8601String()}, localId);
      } catch (_) {}
      await OfflineSyncService.instance.discard(feature: 'safety', localId: localId.toString());
    }

    if (syncId != null && syncId > 0) {
      try {
        await _api.deleteSafetyTalk(syncId);
      } catch (_) {}
    } else if (localId == null && item['id'] != null) {
      try {
        await _api.deleteSafetyTalk(item['id'] as int);
      } catch (_) {}
    }

    if (!mounted) return;
    OfflineSyncService.instance.refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safety Talk berhasil dihapus.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // Filter by segmented pill
    var filtered = _talks;
    final totalCount = _talks.length;
    final syncedCount = _talks.where((e) => e['sync_id'] != null && e['sync_id'] != 0).length;
    final pendingCount = _talks.where((e) => e['sync_id'] == null || e['sync_id'] == 0).length;

    if (_filter == 'Tersinkron') {
      filtered = filtered.where((e) => e['sync_id'] != null && e['sync_id'] != 0).toList();
    } else if (_filter == 'Pending') {
      filtered = filtered.where((e) => e['sync_id'] == null || e['sync_id'] == 0).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        final t = (e['judul'] ?? e['title'] ?? '').toString().toLowerCase();
        final a = (e['area'] ?? '').toString().toLowerCase();
        final l = (e['lokasi'] ?? e['location_detail'] ?? '').toString().toLowerCase();
        final r = (e['keterangan'] ?? e['remark'] ?? '').toString().toLowerCase();
        return t.contains(q) || a.contains(q) || l.contains(q) || r.contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: _stBackground,
      appBar: const TopBar(title: 'Safety Talk', back: 2),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _stRed,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Buat Safety Talk',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _stRed,
        child: Column(
          children: [
            // Top Search & Filter Segment
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  // Search box
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari topik, area, lokasi...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),

                  // Filter Segment Pills
                  Row(
                    children: [
                      _FilterPill(
                        label: 'Semua',
                        count: totalCount,
                        isSelected: _filter == 'Semua',
                        activeColor: _stRed,
                        onTap: () => setState(() => _filter = 'Semua'),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Tersinkron',
                        count: syncedCount,
                        isSelected: _filter == 'Tersinkron',
                        activeColor: const Color(0xFF16A34A),
                        onTap: () => setState(() => _filter = 'Tersinkron'),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Pending Offline',
                        count: pendingCount,
                        isSelected: _filter == 'Pending',
                        activeColor: const Color(0xFFD97706),
                        onTap: () => setState(() => _filter = 'Pending'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Content List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _stRed),
                    )
                  : filtered.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 80),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.campaign_outlined, size: 44, color: _stRed),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Belum ada Safety Talk',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _stDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tekan tombol + Buat Safety Talk untuk mencatat pengarahan K3.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isSynced = item['sync_id'] != null && item['sync_id'] != 0;
                            final title = (item['judul'] ?? item['title'] ?? 'Safety Talk').toString();
                            final area = (item['area'] ?? '').toString();
                            final lokasi = (item['lokasi'] ?? item['location_detail'] ?? '').toString();
                            final fullLoc = area.isNotEmpty && lokasi.isNotEmpty
                                ? '$area • $lokasi'
                                : (area.isNotEmpty ? area : (lokasi.isNotEmpty ? lokasi : 'Lokasi Kerja'));
                            final dateRaw = item['date'] ?? item['tanggal'];
                            final timeRaw = item['time'] ?? item['waktu'];
                            final remark = (item['keterangan'] ?? item['remark'] ?? '').toString();

                            String dateText = '';
                            if (dateRaw != null) {
                              final dt = DateTime.tryParse(dateRaw.toString());
                              if (dt != null) {
                                dateText = DateFormat('dd MMM yyyy').format(dt);
                              } else {
                                dateText = dateRaw.toString();
                              }
                            }
                            if (timeRaw != null) {
                              final tStr = timeRaw.toString();
                              dateText += ' • ${tStr.length >= 5 ? tStr.substring(0, 5) : tStr}';
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () => _openForm(item),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Row: Megaphone + Title + Popup Menu
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF1F2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.campaign_rounded, color: _stRed, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _stDark,
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.place_rounded, size: 14, color: Color(0xFF64748B)),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        fullLoc,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: Color(0xFF64748B),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                                            padding: EdgeInsets.zero,
                                            onSelected: (v) {
                                              if (v == 'edit') _openForm(item);
                                              if (v == 'delete') _delete(item);
                                              if (v == 'sync') _triggerItemSync(item);
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                                    SizedBox(width: 10),
                                                    Text('Edit Laporan'),
                                                  ],
                                                ),
                                              ),
                                              if (!isSynced && item['is_local'] == true)
                                                const PopupMenuItem(
                                                  value: 'sync',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.sync_rounded, size: 18, color: _stRed),
                                                      SizedBox(width: 10),
                                                      Text('Sinkronkan Sekarang'),
                                                    ],
                                                  ),
                                                ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                    SizedBox(width: 10),
                                                    Text('Hapus Laporan', style: TextStyle(color: Color(0xFFDC2626))),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // Remark / Notulen preview (if exists)
                                      if (remark.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          remark,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontSize: 12,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 10),
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      const SizedBox(height: 8),

                                      // Bottom Row: Date & Sync Status
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (dateText.isNotEmpty)
                                            Row(
                                              children: [
                                                const Icon(Icons.event_note_rounded, size: 13, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 5),
                                                Text(
                                                  dateText,
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            const SizedBox.shrink(),

                                          // Status Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isSynced ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSynced ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                                  size: 13,
                                                  color: isSynced ? const Color(0xFF059669) : const Color(0xFFD97706),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  isSynced ? 'Tersinkron' : 'Pending Offline',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSynced ? const Color(0xFF059669) : const Color(0xFFD97706),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
