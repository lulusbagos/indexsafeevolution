import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/sync.dart';
import '../../widgets/top_bar.dart';
import 'coaching_form_page.dart';

const _coachPurple = Color(0xFF9333EA);
const _coachDark = Color(0xFF0F172A);
const _coachBackground = Color(0xFFF8FAFC);

class CoachingPage extends StatefulWidget {
  const CoachingPage({super.key});

  @override
  State<CoachingPage> createState() => _CoachingPageState();
}

class _CoachingPageState extends State<CoachingPage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String _filter = 'Semua';
  String _searchQuery = '';
  List<Map<String, dynamic>> _coachings = [];

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
        '''SELECT id, code, title, tema, purpose, remark, feedback, komitmen, 
                  area, lokasi, detil_lokasi, location_detail, date, time, 
                  image, foto, participants_json, sync_id 
           FROM coaching_trans 
           WHERE deleted_at IS NULL 
           ORDER BY id DESC''',
      );
      localItems = rows.map((r) {
        final map = Map<String, dynamic>.from(r);
        map['is_local'] = true;
        map['local_id'] = r['id'];
        return map;
      }).toList();

      // Attach participants from coaching_details if available
      final sqldb = await _db.database;
      for (final item in localItems) {
        final localId = item['local_id'] as int;
        final details = await sqldb.rawQuery(
          'SELECT * FROM coaching_details WHERE tran_id = ? AND deleted_at IS NULL ORDER BY id ASC',
          [localId],
        );
        if (details.isNotEmpty) {
          item['details'] = details;
        }
      }
    } catch (_) {}

    // 2. Fetch server items if online
    List<Map<String, dynamic>> serverItems = [];
    try {
      final res = await _api.dio.get('/tran/coaching');
      if (res.data is Map && res.data['data'] is List) {
        serverItems = List<Map<String, dynamic>>.from(res.data['data'] as List).map((item) {
          return {
            'id': item['id'],
            'code': item['code'] ?? 'COACH-${item['id']}',
            'tema': item['tema'] ?? item['title'] ?? 'Safety Coaching',
            'title': item['tema'] ?? item['title'] ?? 'Safety Coaching',
            'area': item['area'] ?? item['area_name'] ?? '',
            'lokasi': item['lokasi'] ?? item['location_name'] ?? '',
            'detil_lokasi': item['detil_lokasi'] ?? item['location_detail'] ?? '',
            'date': item['date'] ?? '',
            'time': item['time'] ?? '',
            'nik': item['nik'] ?? item['coach_nik'] ?? '',
            'nama': item['nama'] ?? item['coach_name'] ?? '',
            'coach_name': item['coach_name'] ?? item['nama'] ?? '',
            'feedback': item['feedback'] ?? item['remark'] ?? '',
            'komitmen': item['komitmen'] ?? '',
            'foto': item['foto'] ?? item['image'] ?? '',
            'participants': item['participants'] is List ? item['participants'] : [],
            'sync_id': item['id'],
            'is_local': false,
          };
        }).toList();
      }
    } catch (_) {}

    // Deduplicate: local items take priority over server items with same sync_id
    final localSyncIds = localItems
        .map((e) => e['sync_id'])
        .where((id) => id != null && id != 0)
        .toSet();

    final nonDuplicateServer = serverItems.where((s) => !localSyncIds.contains(s['id'])).toList();

    if (!mounted) return;
    setState(() {
      _coachings = [...localItems, ...nonDuplicateServer];
      _loading = false;
    });
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final int? existingId = item != null ? (item['local_id'] ?? item['id']) as int? : null;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CoachingFormPage(existingId: existingId),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _triggerItemSync(Map<String, dynamic> item) async {
    final localId = item['local_id'] as int?;
    if (localId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menyinkronkan sesi coaching ke server...'),
        duration: Duration(seconds: 1),
      ),
    );

    final ok = await syncTran(_db, _api, 'coaching', localId);
    if (!mounted) return;

    OfflineSyncService.instance.refresh();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sesi Coaching berhasil disinkronkan ke server!'
              : 'Gagal sinkron. Cek koneksi internet.',
        ),
        backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );

    _load();
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Hapus Sesi Coaching?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Laporan coaching ini akan dihapus dari perangkat dan server. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final isLocal = item['is_local'] == true;
    final localId = item['local_id'] as int?;
    final syncId = item['sync_id'] as int?;
    final serverId = item['id'] as int?;

    if (isLocal && localId != null) {
      final sqldb = await _db.database;
      await sqldb.rawUpdate(
        'UPDATE coaching_trans SET deleted_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), localId],
      );
      await sqldb.rawUpdate(
        'UPDATE coaching_details SET deleted_at = ? WHERE tran_id = ?',
        [DateTime.now().toIso8601String(), localId],
      );
      try {
        await OfflineSyncService.instance.discard(feature: 'coaching', localId: localId.toString());
      } catch (_) {}
    }

    final targetServerId = syncId ?? (!isLocal ? serverId : null);
    if (targetServerId != null && targetServerId > 0) {
      try {
        await _api.dio.delete('/tran/coaching/$targetServerId');
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesi Coaching berhasil dihapus.'),
        backgroundColor: Color(0xFF475569),
      ),
    );
    _load();
  }

  void _showDetailModal(Map<String, dynamic> item) {
    final tema = item['tema'] ?? item['title'] ?? item['purpose'] ?? 'Safety Coaching';
    final area = item['area'] ?? '-';
    final lokasi = item['lokasi'] ?? '-';
    final detilLokasi = item['detil_lokasi'] ?? item['location_detail'] ?? '';
    final date = item['date'] ?? '';
    final time = item['time'] ?? '';
    final feedback = item['feedback'] ?? item['remark'] ?? '-';
    final komitmen = item['komitmen'] ?? '-';
    final coach = item['nama'] ?? item['coach_name'] ?? item['nik'] ?? 'Pemateri';
    final isSynced = item['sync_id'] != null && item['sync_id'] != 0;

    // Participants list
    List<String> participantNames = [];
    if (item['details'] is List) {
      for (var d in item['details']) {
        final n = d['name'] ?? d['nama_lengkap'] ?? '';
        if (n.toString().isNotEmpty) participantNames.add(n.toString());
      }
    } else if (item['participants'] is List) {
      for (var p in item['participants']) {
        final n = p['nama_lengkap'] ?? p['nama'] ?? p['nik'] ?? '';
        if (n.toString().isNotEmpty) participantNames.add(n.toString());
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _coachPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups_rounded, size: 14, color: _coachPurple),
                        SizedBox(width: 5),
                        Text(
                          'DETAIL COACHING',
                          style: TextStyle(
                            color: _coachPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSynced ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isSynced ? '✓ Tersinkron' : '⏳ Pending Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSynced ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tema.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _coachDark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              // Info Waktu & Coach
              _buildDetailInfoTile(
                icon: Icons.calendar_today_rounded,
                title: 'Waktu Pelaksanaan',
                content: '$date • $time',
              ),
              const SizedBox(height: 10),
              _buildDetailInfoTile(
                icon: Icons.badge_rounded,
                title: 'Pembina / Coach',
                content: coach.toString(),
              ),
              const SizedBox(height: 10),
              _buildDetailInfoTile(
                icon: Icons.place_rounded,
                title: 'Area & Titik Lokasi',
                content: '$area • $lokasi${detilLokasi.isNotEmpty ? ' ($detilLokasi)' : ''}',
              ),
              const SizedBox(height: 16),

              // Peserta Coaching
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, size: 16, color: _coachPurple),
                        const SizedBox(width: 8),
                        Text(
                          'Peserta Bimbingan (${participantNames.length} Orang)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _coachPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (participantNames.isEmpty)
                      const Text(
                        'Tidak ada rincian peserta lokal.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: participantNames.map((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD8B4FE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_pin_rounded, size: 14, color: _coachPurple),
                              const SizedBox(width: 6),
                              Text(
                                p,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _coachDark,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Komitmen
              _buildDetailInfoTile(
                icon: Icons.handshake_rounded,
                title: 'Komitmen Bersama',
                content: komitmen.toString(),
              ),
              const SizedBox(height: 10),

              // Feedback
              _buildDetailInfoTile(
                icon: Icons.notes_rounded,
                title: 'Catatan & Feedback',
                content: feedback.toString(),
              ),
              const SizedBox(height: 24),

              // Tombol Tutup
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailInfoTile({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: const TextStyle(fontSize: 13, color: _coachDark, fontWeight: FontWeight.bold, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _coachings.where((item) {
      final isSynced = item['sync_id'] != null && item['sync_id'] != 0;
      if (_filter == 'Tersinkron' && !isSynced) return false;
      if (_filter == 'Pending Offline' && isSynced) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final tema = (item['tema'] ?? item['title'] ?? '').toString().toLowerCase();
        final area = (item['area'] ?? '').toString().toLowerCase();
        final lokasi = (item['lokasi'] ?? '').toString().toLowerCase();
        final coach = (item['nama'] ?? item['coach_name'] ?? '').toString().toLowerCase();
        return tema.contains(q) || area.contains(q) || lokasi.contains(q) || coach.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _coachBackground,
      appBar: const TopBar(title: 'Coaching & Pembinaan'),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search Input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13.5, color: _coachDark),
                    decoration: InputDecoration(
                      hintText: 'Cari tema, coach, area, atau peserta...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Segmented Filter Tabs
                Row(
                  children: [
                    _buildFilterChip('Semua', _coachings.length),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Tersinkron',
                      _coachings.where((e) => e['sync_id'] != null && e['sync_id'] != 0).length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Pending Offline',
                      _coachings.where((e) => e['sync_id'] == null || e['sync_id'] == 0).length,
                      alertColor: const Color(0xFFD97706),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _coachPurple),
                        SizedBox(height: 12),
                        Text('Memuat sesi coaching...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: _coachPurple,
                    onRefresh: _load,
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: _coachPurple.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.groups_outlined, size: 48, color: _coachPurple),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Belum Ada Sesi Coaching',
                                      style: TextStyle(
                                        color: _coachDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 40),
                                      child: Text(
                                        'Gunakan tombol di bawah untuk membuat sesi coaching dan bimbingan baru.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildCoachingCard(item);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _coachPurple,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Buat Coaching',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, {Color? alertColor}) {
    final active = _filter == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? _coachPurple : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? _coachPurple : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.bold : FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.25)
                          : (alertColor ?? const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: active
                            ? Colors.white
                            : (alertColor != null ? Colors.white : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoachingCard(Map<String, dynamic> item) {
    final isSynced = item['sync_id'] != null && item['sync_id'] != 0;
    final isLocal = item['is_local'] == true;
    final tema = item['tema'] ?? item['title'] ?? item['purpose'] ?? 'Safety Coaching';
    final area = item['area'] ?? '-';
    final lokasi = item['lokasi'] ?? '-';
    final date = item['date'] ?? '';
    final time = item['time'] ?? '';
    final coach = item['nama'] ?? item['coach_name'] ?? item['nik'] ?? 'Pemateri';

    // Count participants
    int pCount = 0;
    if (item['details'] is List) {
      pCount = (item['details'] as List).length;
    } else if (item['participants'] is List) {
      pCount = (item['participants'] as List).length;
    }

    return InkWell(
      onTap: () => _showDetailModal(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Waktu & Status Badge & Popup Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _coachPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.groups_rounded, size: 16, color: _coachPurple),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        date.isNotEmpty ? '$date • $time' : 'Coaching',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSynced ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSynced ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Text(
                          isSynced ? '✓ Tersinkron' : '⏳ Pending',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSynced ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                        padding: EdgeInsets.zero,
                        onSelected: (val) {
                          if (val == 'detail') _showDetailModal(item);
                          if (val == 'edit') _openForm(item);
                          if (val == 'sync') _triggerItemSync(item);
                          if (val == 'delete') _deleteItem(item);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'detail',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                                SizedBox(width: 8),
                                Text('Lihat Detail', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          if (isLocal)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                                  SizedBox(width: 8),
                                  Text('Edit Laporan', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          if (isLocal && !isSynced)
                            const PopupMenuItem(
                              value: 'sync',
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_upload_outlined, size: 18, color: Color(0xFF16A34A)),
                                  SizedBox(width: 8),
                                  Text('Sinkronkan Sekarang', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                SizedBox(width: 8),
                                Text('Hapus', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title / Tema
              Text(
                tema.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _coachDark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),

              // Lokasi & Area
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$area • $lokasi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Footer: Coach info + Peserta Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 14, color: _coachPurple),
                        const SizedBox(width: 6),
                        Text(
                          'Coach: $coach',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _coachPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 12, color: _coachPurple),
                          const SizedBox(width: 4),
                          Text(
                            '$pCount Peserta',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: _coachPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
