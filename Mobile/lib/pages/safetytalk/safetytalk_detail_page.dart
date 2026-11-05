import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../widgets/top_bar.dart';
import 'safetytalk_form_page.dart';

const _stRed = Color(0xFFE11D48);
const _stDark = Color(0xFF0F172A);
const _stBackground = Color(0xFFF8FAFC);

String _decodeHtml(String? text) {
  if (text == null) return '';
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .trim();
}

String _cleanLocation(dynamic areaRaw, dynamic lokasiRaw, [dynamic detilRaw]) {
  final seen = <String>{};
  final result = <String>[];

  void add(dynamic val) {
    if (val == null) return;
    final text = _decodeHtml(val.toString()).trim();
    if (text.isEmpty) return;

    final parts = text.contains('•') ? text.split('•') : [text];
    for (var p in parts) {
      final clean = p.trim();
      final lower = clean.toLowerCase();
      if (clean.isNotEmpty && !seen.contains(lower)) {
        seen.add(lower);
        result.add(clean);
      }
    }
  }

  add(areaRaw);
  add(lokasiRaw);
  add(detilRaw);

  if (result.isEmpty) return 'Lokasi Kerja Lapangan';
  return result.join(' • ');
}

class SafetyTalkDetailPage extends StatefulWidget {
  const SafetyTalkDetailPage({
    required this.item,
    super.key,
  });

  final Map<String, dynamic> item;

  @override
  State<SafetyTalkDetailPage> createState() => _SafetyTalkDetailPageState();
}

class _SafetyTalkDetailPageState extends State<SafetyTalkDetailPage> {
  final _api = ApiService();
  final _db = DatabaseService();

  late Map<String, dynamic> _data;
  bool _loading = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.item);
    _loadFullDetail();
  }

  Future<void> _loadFullDetail() async {
    final localId = _data['local_id'] ?? (_data['is_local'] == true ? _data['id'] : null);
    final syncId = _data['sync_id'] ?? (_data['is_local'] != true ? _data['id'] : null);

    // 1. If local, query SQLite safety_trans for all columns
    if (localId != null) {
      try {
        final rows = await _db.rawQuery(
          'SELECT * FROM safety_trans WHERE id = ? LIMIT 1',
          [localId],
        );
        if (rows.isNotEmpty && mounted) {
          setState(() {
            final r = Map<String, dynamic>.from(rows.first);
            _data['judul'] ??= r['judul'] ?? r['title'];
            _data['title'] ??= r['title'] ?? r['judul'];
            _data['tanggal'] ??= r['tanggal'] ?? r['date'];
            _data['date'] ??= r['date'] ?? r['tanggal'];
            _data['waktu'] ??= r['waktu'] ?? r['time'];
            _data['time'] ??= r['time'] ?? r['waktu'];
            _data['keterangan'] ??= r['keterangan'] ?? r['remark'];
            _data['remark'] ??= r['remark'] ?? r['keterangan'];
            _data['area'] ??= r['area'];
            _data['lokasi'] ??= r['lokasi'] ?? r['detil_lokasi'];
            _data['detil_lokasi'] ??= r['detil_lokasi'] ?? r['lokasi'];
            _data['foto_diri'] ??= r['foto_diri'] ?? r['self_image'] ?? r['image'];
            _data['foto_kegiatan'] ??= r['foto_kegiatan'] ?? r['event_image'] ?? r['repair_image'];
            _data['nama'] ??= r['nama'];
            _data['nik'] ??= r['nik'];
            _data['sync_id'] ??= r['sync_id'];
          });
        }
      } catch (_) {}
    }

    // 2. If syncId exists and server detail is needed (missing date or photos)
    final targetId = syncId is int ? syncId : int.tryParse(syncId?.toString() ?? '');
    final needsRemoteFetch = targetId != null &&
        targetId > 0 &&
        (_data['tanggal'] == null ||
            _data['keterangan'] == null ||
            _data['foto_diri'] == null ||
            _data['fotoDiri'] == null);

    if (needsRemoteFetch) {
      if (mounted) setState(() => _loading = true);
      try {
        final remote = await _api.getSafetyTalk(targetId);
        if (remote != null && mounted) {
          setState(() {
            _data['judul'] = remote['judul'] ?? _data['judul'];
            _data['title'] = remote['judul'] ?? _data['title'];
            _data['tanggal'] = remote['tanggal'] ?? _data['tanggal'];
            _data['date'] = remote['tanggal'] ?? _data['date'];
            _data['waktu'] = remote['waktu'] ?? _data['waktu'];
            _data['time'] = remote['waktu'] ?? _data['time'];
            _data['keterangan'] = remote['keterangan'] ?? _data['keterangan'];
            _data['remark'] = remote['keterangan'] ?? _data['remark'];
            _data['area'] = remote['area'] ?? _data['area'];
            _data['lokasi'] = remote['lokasi'] ?? _data['lokasi'];
            _data['detil_lokasi'] = remote['detilLokasi'] ?? _data['detil_lokasi'];
            _data['foto_diri'] = remote['fotoDiri'] ?? _data['foto_diri'];
            _data['foto_kegiatan'] = remote['fotoKegiatan'] ?? _data['foto_kegiatan'];
            _data['nama'] = remote['nama'] ?? _data['nama'];
            _data['nik'] = remote['nik'] ?? _data['nik'];
            _data['departemen'] = remote['departemen'] ?? _data['departemen'];
          });
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editReport() async {
    final int? existingId = (_data['local_id'] ?? _data['id']) as int?;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SafetyTalkFormPage(existingId: existingId),
      ),
    );
    if (saved == true) {
      _loadFullDetail();
    }
  }

  Future<void> _triggerSync() async {
    final localId = _data['local_id'] as int?;
    if (localId == null) return;

    setState(() => _syncing = true);
    final ok = await syncTran(_db, _api, 'safety', localId);
    if (!mounted) return;
    setState(() => _syncing = false);

    OfflineSyncService.instance.refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Berhasil disinkronkan ke server.' : 'Gagal sinkron. Cek koneksi Anda.'),
        backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );

    if (ok) {
      _data['sync_id'] = localId;
      _loadFullDetail();
    }
  }

  Future<void> _deleteReport() async {
    final title = _decodeHtml((_data['judul'] ?? _data['title'] ?? 'Safety Talk').toString());
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
                'Laporan "$title" akan dihapus secara permanen.',
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

    final int? localId = _data['local_id'] as int?;
    final int? syncId = _data['sync_id'] as int?;

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
    } else if (localId == null && _data['id'] != null) {
      try {
        await _api.deleteSafetyTalk(_data['id'] as int);
      } catch (_) {}
    }

    if (!mounted) return;
    OfflineSyncService.instance.refresh();
    Navigator.pop(context, true);
  }

  void _openImageViewer(String imagePath, String title) {
    if (imagePath.trim().isEmpty) return;

    final isHttp = imagePath.startsWith('http://') || imagePath.startsWith('https://');
    final isFile = !isHttp && File(imagePath).existsSync();
    final isRelative = !isHttp && !isFile;
    final apiBase = _api.dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final fullUrl = isRelative
        ? (imagePath.toLowerCase().contains('uploads/')
            ? '$apiBase/${imagePath.replaceFirst(RegExp(r'^/+'), '')}'
            : 'https://mbssap.indexim.id/${imagePath.replaceFirst(RegExp(r'^/+'), '')}')
        : imagePath;

    final cookie = PreferenceService.getMbsSessionCookie();
    final token = _api.getToken;
    final headers = <String, String>{
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              // Interactive pinch-to-zoom image
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: isFile
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          fullUrl,
                          headers: headers.isNotEmpty ? headers : null,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 56),
                              SizedBox(height: 12),
                              Text(
                                'Foto tidak dapat dimuat',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              // Top Bar with title and Close Button
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTile({
    required String title,
    required String subtitle,
    required String? imageSrc,
    required IconData icon,
  }) {
    final hasImage = imageSrc != null && imageSrc.trim().isNotEmpty && imageSrc.trim() != 'null';
    final isHttp = hasImage && (imageSrc.startsWith('http://') || imageSrc.startsWith('https://'));
    final isFile = hasImage && !isHttp && File(imageSrc).existsSync();
    final isRelative = hasImage && !isHttp && !isFile;
    final apiBase = _api.dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final fullUrl = isRelative
        ? (imageSrc.toLowerCase().contains('uploads/')
            ? '$apiBase/${imageSrc.replaceFirst(RegExp(r'^/+'), '')}'
            : 'https://mbssap.indexim.id/${imageSrc.replaceFirst(RegExp(r'^/+'), '')}')
        : (imageSrc ?? '');

    final cookie = PreferenceService.getMbsSessionCookie();
    final token = _api.getToken;
    final headers = <String, String>{
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFFFF1F2),
                  child: Icon(icon, color: _stRed, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _stDark,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (hasImage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, size: 12, color: Color(0xFF475569)),
                        SizedBox(width: 3),
                        Text(
                          'Ketuk Zoom',
                          style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Photo Preview / Placeholder
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: InkWell(
                onTap: () => _openImageViewer(imageSrc, title),
                child: SizedBox(
                  width: double.infinity,
                  height: 190,
                  child: isFile
                      ? Image.file(
                          File(imageSrc),
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          fullUrl,
                          headers: headers.isNotEmpty ? headers : null,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Center(
                                child: CircularProgressIndicator(color: _stRed, strokeWidth: 2.5),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF8FAFC),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 36),
                                SizedBox(height: 6),
                                Text(
                                  'Gambar belum tersinkron atau tidak tersedia',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.image_not_supported_outlined, color: Color(0xFFCBD5E1), size: 32),
                  SizedBox(height: 6),
                  Text(
                    'Tidak ada dokumentasi foto',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _stRed, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _stDark,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildKeyValue(String key, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(' : ', style: TextStyle(color: Color(0xFF94A3B8))),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(
                color: _stDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (copyable && value.isNotEmpty)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$key berhasil disalin.'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _decodeHtml((_data['judul'] ?? _data['title'] ?? 'Safety Talk').toString());
    final isSynced = _data['sync_id'] != null && _data['sync_id'] != 0;
    final idText = _data['sync_id'] != null && _data['sync_id'] != 0
        ? '#ST-${_data['sync_id']}'
        : (_data['local_id'] != null ? '#LOC-${_data['local_id']}' : '#ST-${_data['id'] ?? '-'}');

    // Date & Time formatting
    final dateRaw = _data['date'] ?? _data['tanggal'];
    final timeRaw = _data['time'] ?? _data['waktu'];
    String dateFormatted = '';
    String dayFormatted = '';
    if (dateRaw != null && dateRaw.toString().isNotEmpty) {
      final dt = DateTime.tryParse(dateRaw.toString());
      if (dt != null) {
        final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
        dayFormatted = days[dt.weekday - 1];
        dateFormatted = DateFormat('dd MMMM yyyy').format(dt);
      } else {
        dateFormatted = dateRaw.toString();
      }
    }

    String timeFormatted = '';
    if (timeRaw != null && timeRaw.toString().isNotEmpty) {
      final tStr = timeRaw.toString();
      timeFormatted = '${tStr.length >= 5 ? tStr.substring(0, 5) : tStr} WITA';
    }

    // Speaker Profile
    final myProfile = PreferenceService.getProfile();
    final speakerName = (_data['nama'] ?? _data['speaker'] ?? myProfile?.namaLengkap ?? 'Pemateri Lapangan').toString();
    final speakerNik = (_data['nik'] ?? myProfile?.noNik ?? '-').toString();
    final speakerDept = (_data['departemen'] ?? myProfile?.depart ?? myProfile?.posisi ?? 'HSE / Operasional').toString();

    // Location
    final areaStr = (_data['area'] ?? '').toString();
    final locStr = (_data['lokasi'] ?? _data['detil_lokasi'] ?? _data['location_detail'] ?? '').toString();
    final cleanLoc = _cleanLocation(areaStr, locStr);

    // Keterangan / Notulen
    final remarkStr = (_data['keterangan'] ?? _data['remark'] ?? '').toString().trim();

    // Photos
    final fotoDiri = _data['foto_diri'] ?? _data['self_image'] ?? _data['fotoDiri'] ?? _data['image'];
    final fotoKegiatan = _data['foto_kegiatan'] ?? _data['event_image'] ?? _data['fotoKegiatan'] ?? _data['repair_image'];

    return Scaffold(
      backgroundColor: _stBackground,
      appBar: const TopBar(title: 'Detail Safety Talk', back: 1),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleteReport,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              if (!isSynced && _data['local_id'] != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _syncing ? null : _triggerSync,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFD97706)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Sinkron', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _editReport,
                  style: FilledButton.styleFrom(
                    backgroundColor: _stRed,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _stRed))
          : RefreshIndicator(
              onRefresh: _loadFullDetail,
              color: _stRed,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HERO CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF881337), Color(0xFFBE123C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x28BE123C),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  idText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSynced ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSynced ? 'Tersinkron ke Server' : 'Pending Offline',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOPIK SAFETY TALK',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (dateFormatted.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule_rounded, color: Colors.white70, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$dayFormatted, $dateFormatted ${timeFormatted.isNotEmpty ? '• $timeFormatted' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SECTION 1: WAKTU & JADWAL PELAKSANAAN
                    _buildInfoSection(
                      title: 'Waktu Pelaksanaan',
                      icon: Icons.calendar_today_rounded,
                      children: [
                        _buildKeyValue('Hari / Tanggal', dayFormatted.isNotEmpty ? '$dayFormatted, $dateFormatted' : dateFormatted),
                        _buildKeyValue('Jam Sesi', timeFormatted.isNotEmpty ? timeFormatted : '-'),
                        _buildKeyValue('Status Pelaksanaan', 'Selesai Dilaksanakan'),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // SECTION 2: PEMATERI & FASILITATOR K3
                    _buildInfoSection(
                      title: 'Fasilitator / Pemateri K3',
                      icon: Icons.badge_rounded,
                      children: [
                        _buildKeyValue('Nama Pemateri', speakerName),
                        _buildKeyValue('Nomor Induk (NIK)', speakerNik, copyable: true),
                        _buildKeyValue('Departemen', speakerDept),
                        _buildKeyValue('Perusahaan', 'PT Indexim Coalindo'),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // SECTION 3: LOKASI PENGARAHAN
                    _buildInfoSection(
                      title: 'Lokasi Pengarahan',
                      icon: Icons.place_rounded,
                      children: [
                        _buildKeyValue('Area Kerja', areaStr.isNotEmpty ? areaStr : '-'),
                        _buildKeyValue('Titik / Lokasi', cleanLoc, copyable: true),
                        if (locStr.isNotEmpty && locStr != areaStr)
                          _buildKeyValue('Detail Lokasi', locStr),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // SECTION 4: ISI MATERI & NOTULEN
                    _buildInfoSection(
                      title: 'Notulen & Pembahasan K3',
                      icon: Icons.description_rounded,
                      children: [
                        if (remarkStr.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              remarkStr,
                              style: const TextStyle(
                                color: _stDark,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          )
                        else
                          const Text(
                            'Tidak ada catatan notulen tambahan yang dicatat untuk pengarahan ini.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // SECTION 5: DOKUMENTASI FOTO BUKTI
                    _buildInfoSection(
                      title: 'Dokumentasi Foto Lapangan',
                      icon: Icons.photo_library_rounded,
                      children: [
                        _buildPhotoTile(
                          title: 'Foto Pemateri',
                          subtitle: 'Dokumentasi kehadiran fasilitator pengarah',
                          imageSrc: fotoDiri?.toString(),
                          icon: Icons.person_pin_circle_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildPhotoTile(
                          title: 'Foto Kegiatan Lapangan',
                          subtitle: 'Dokumentasi interaksi peserta safety briefing',
                          imageSrc: fotoKegiatan?.toString(),
                          icon: Icons.groups_rounded,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
