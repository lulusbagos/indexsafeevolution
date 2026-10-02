import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/hazard_hub_model.dart';
import '../../services/api.dart';
import '../../services/hazard_pdf_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import 'hazard_create_page.dart';

class HazardHubPage extends StatefulWidget {
  const HazardHubPage({super.key});

  @override
  State<HazardHubPage> createState() => _HazardHubPageState();
}

class _HazardHubPageState extends State<HazardHubPage> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  HazardSummary _summary = HazardSummary();
  List<HazardReportItem> _items = [];
  bool _isLoading = true;
  String _activeFilter = 'all'; // all, open, closed, assigned

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final res = await _api.getHazardHub(
      filter: _activeFilter,
      search: _searchCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    res.fold(
      (err) {
        final msg = err['message']?.toString() ?? 'Gagal memuat daftar hazard.';
        SnackBarMsg.danger(context, msg);
      },
      (data) {
        if (data['summary'] is Map) {
          _summary = HazardSummary.fromJson(Map<String, dynamic>.from(data['summary'] as Map));
        }
        if (data['data'] is List) {
          final list = (data['data'] as List)
              .map((e) => HazardReportItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          setState(() => _items = list);
        }
      },
    );
  }

  void _openCreateHazard([HazardReportItem? editItem]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HazardCreatePage(editItem: editItem)),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _showImagePreview(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl.startsWith('http') ? imageUrl : '${ApiService().baseUrl}$imageUrl',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: const Text('Foto tidak dapat dimuat', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseModal(HazardReportItem item) {
    final tindakanCtrl = TextEditingController();
    File? fotoPerbaikan;
    final picker = ImagePicker();
    bool isSaving = false;
    String closeMode = item.isAssignedToMe ? 'self' : 'pja';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isPjaMode = closeMode == 'pja';
          final showModeSelector = item.isMyReport && !item.isAssignedToMe;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.isAssignedToMe ? 'Tuntaskan Tugas PJA' : 'Close Temuan Hazard',
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              item.isAssignedToMe
                                  ? 'Selesaikan temuan dan unggah bukti perbaikan.'
                                  : 'Pilih cara penutupan: kirim ke PJA atau selesaikan sendiri.',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (showModeSelector) ...[
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => closeMode = 'pja'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isPjaMode ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isPjaMode ? const Color(0xFFF97316) : const Color(0xFFE2E8F0),
                                  width: isPjaMode ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isPjaMode ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: isPjaMode ? const Color(0xFFF97316) : const Color(0xFF94A3B8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kirim ke PJA',
                                    style: TextStyle(
                                      color: isPjaMode ? const Color(0xFFC2410C) : const Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => closeMode = 'self'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isPjaMode ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isPjaMode ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                  width: !isPjaMode ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    !isPjaMode ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: !isPjaMode ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Selesaikan Sendiri',
                                    style: TextStyle(
                                      color: !isPjaMode ? const Color(0xFF047857) : const Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isPjaMode ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isPjaMode ? const Color(0xFFFFEDD5) : const Color(0xFFA7F3D0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPjaMode ? Icons.forward_to_inbox_rounded : Icons.task_alt_rounded,
                            color: isPjaMode ? const Color(0xFFEA580C) : const Color(0xFF059669),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isPjaMode
                                  ? 'Temuan di-close di pelaporan Anda dan otomatis diteruskan ke PJA (${item.pja ?? "Penanggung Jawab"}) sebagai Action Plan.'
                                  : 'Temuan diselesaikan langsung oleh Anda sebagai pelapor dan langsung berstatus Closed permanen.',
                              style: TextStyle(
                                color: isPjaMode ? const Color(0xFF9A3412) : const Color(0xFF065F46),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  Text(
                    'Temuan: ${item.temuan}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isPjaMode ? 'Catatan Penutupan / Tindak Lanjut untuk PJA *' : 'Tindakan Koreksi / Perbaikan yang Dilakukan *',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: tindakanCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: isPjaMode
                            ? 'Tulis catatan penutupan / instruksi rencana tindak lanjut...'
                            : 'Jelaskan tindakan perbaikan yang telah dituntaskan...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!isPjaMode) ...[
                    const Text('Foto Bukti Perbaikan (After)',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (fotoPerbaikan != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              fotoPerbaikan!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: InkWell(
                              onTap: () => setModalState(() => fotoPerbaikan = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      InkWell(
                        onTap: () async {
                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                          if (picked != null) {
                            setModalState(() => fotoPerbaikan = File(picked.path));
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 68,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt_rounded, color: Color(0xFF059669), size: 20),
                              SizedBox(width: 8),
                              Text('Ambil Foto Bukti Perbaikan', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                  ] else ...[
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPjaMode ? const Color(0xFFEA580C) : const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final text = tindakanCtrl.text.trim();
                              if (text.isEmpty) {
                                SnackBarMsg.danger(
                                  context,
                                  isPjaMode
                                      ? 'Catatan penutupan / instruksi untuk PJA wajib diisi.'
                                      : 'Uraian tindakan perbaikan wajib diisi.',
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);
                              final res = await _api.closeHazardDirect(
                                item.id,
                                text,
                                closeMode: closeMode,
                                fotoPerbaikan: fotoPerbaikan,
                              );

                              if (!mounted) return;
                              setModalState(() => isSaving = false);

                              res.fold(
                                (err) => SnackBarMsg.danger(context, err['message']?.toString() ?? 'Gagal menutup hazard.'),
                                (_) {
                                  Navigator.pop(ctx);
                                  SnackBarMsg.success(
                                    context,
                                    isPjaMode
                                        ? 'Hazard berhasil di-close dan diteruskan ke PJA!'
                                        : 'Temuan Hazard berhasil ditutup (Closed)!',
                                  );
                                  _loadData();
                                },
                              );
                            },
                      icon: isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(isPjaMode ? Icons.send_rounded : Icons.check_circle_rounded, size: 20),
                      label: Text(
                        isSaving
                            ? 'MEMPROSES...'
                            : isPjaMode
                                ? 'KIRIM KE PJA (ACTION PLAN)'
                                : 'TUTUP TEMUAN (CLOSE)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReassignModal(HazardReportItem item) {
    final reasonCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    PjaSearchResult? selectedNewPja;
    List<PjaSearchResult> searchResults = [];
    bool isSearching = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFFD97706), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alihkan PJA (Salah Sasaran)',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Arahkan tanggung jawab ke personil PJA yang berwenang.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PJA Saat Ini: ${item.pja ?? "Belum Ditunjuk"} (${item.nikPja ?? "-"})',
                            style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Pilih PJA Baru yang Dituju *',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (selectedNewPja == null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                        onChanged: (q) async {
                          if (q.trim().isEmpty) {
                            setModalState(() => searchResults.clear());
                            return;
                          }
                          setModalState(() => isSearching = true);
                          final res = await _api.searchPja(q);
                          if (!mounted) return;
                          res.fold(
                            (_) => setModalState(() => isSearching = false),
                            (data) {
                              setModalState(() {
                                isSearching = false;
                                searchResults = data.map((e) => PjaSearchResult.fromJson(e)).toList();
                              });
                            },
                          );
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                          hintText: 'Ketik NIK atau Nama PJA...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)))),
                      ),
                    if (searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                          itemBuilder: (ctx, i) {
                            final p = searchResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(p.nama, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('${p.nik} • ${p.departemen}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 12),
                              onTap: () {
                                setModalState(() {
                                  selectedNewPja = p;
                                  searchResults.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF16A34A),
                            child: Text(
                              selectedNewPja!.nama.isNotEmpty ? selectedNewPja!.nama[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedNewPja!.nama,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${selectedNewPja!.nik} • ${selectedNewPja!.departemen}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 18),
                            onPressed: () => setModalState(() => selectedNewPja = null),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text('Alasan / Keterangan Pengalihan *',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Bukan area wewenang saya, mohon tindak lanjut tim terkait...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (selectedNewPja == null) {
                                SnackBarMsg.danger(context, 'PJA baru wajib dipilih dari hasil pencarian.');
                                return;
                              }
                              final reason = reasonCtrl.text.trim();
                              if (reason.isEmpty) {
                                SnackBarMsg.danger(context, 'Alasan pengalihan wajib diisi.');
                                return;
                              }
                              setModalState(() => isSaving = true);
                              final res = await _api.reassignHazardPja(
                                item.id,
                                selectedNewPja!.nik,
                                selectedNewPja!.nama,
                                selectedNewPja!.departemen,
                                reason,
                              );
                              if (!mounted) return;
                              setModalState(() => isSaving = false);
                              res.fold(
                                (err) => SnackBarMsg.danger(context, err['message']?.toString() ?? 'Gagal mengalihkan PJA.'),
                                (_) {
                                  Navigator.pop(ctx);
                                  SnackBarMsg.success(context, 'PJA berhasil dialihkan kepada ${selectedNewPja!.nama}!');
                                  _loadData();
                                },
                              );
                            },
                      icon: isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.swap_horiz_rounded, size: 20),
                      label: Text(isSaving ? 'MENGALIHKAN...' : 'SIMPAN PENGALIHAN PJA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(HazardReportItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Temuan Hazard?', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Laporan #${item.id} (${item.lokasi}) akan dihapus secara permanen dari server.',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.deleteHazardDirect(item.id);
              if (!mounted) return;
              res.fold(
                (err) => SnackBarMsg.danger(context, err['message']?.toString() ?? 'Gagal menghapus laporan.'),
                (_) {
                  SnackBarMsg.success(context, 'Laporan Hazard berhasil dihapus.');
                  _loadData();
                },
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'Hazard Hub'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Lapor Hazard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: () => _openCreateHazard(),
      ),
      body: AmbientBackground(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFFEA580C),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Clean Summary Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF64748B).withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.shield_rounded, color: Color(0xFFEA580C), size: 22),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hazard Safety Hub',
                                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Monitoring temuan bahaya & kepatuhan K3',
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFFEDD5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.workspace_premium_rounded, color: Color(0xFFEA580C), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_summary.score} Poin',
                                        style: const TextStyle(color: Color(0xFFC2410C), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 3 Metric Badges
                            Row(
                              children: [
                                _buildMetricBadge('Open', _summary.totalOpen, const Color(0xFFD97706), const Color(0xFFFFFBEB), const Color(0xFFFDE68A), Icons.access_time_rounded),
                                const SizedBox(width: 8),
                                _buildMetricBadge('Closed', _summary.totalClosed, const Color(0xFF059669), const Color(0xFFECFDF5), const Color(0xFFA7F3D0), Icons.check_circle_rounded),
                                const SizedBox(width: 8),
                                _buildMetricBadge('Tugas PJA', _summary.totalAssigned, const Color(0xFF0284C7), const Color(0xFFF0F9FF), const Color(0xFFBAE6FD), Icons.assignment_ind_rounded),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Clean Search Box
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                          onSubmitted: (_) => _loadData(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _loadData();
                                    },
                                  )
                                : null,
                            hintText: 'Cari lokasi, area, temuan, atau pelapor...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'Semua (${_summary.totalInput})'),
                            const SizedBox(width: 6),
                            _buildFilterChip('open', 'Open (${_summary.totalOpen})'),
                            const SizedBox(width: 6),
                            _buildFilterChip('closed', 'Closed (${_summary.totalClosed})'),
                            const SizedBox(width: 6),
                            _buildFilterChip('assigned', 'Tugas PJA (${_summary.totalAssigned})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Hazard List
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFFEA580C))),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.assignment_turned_in_rounded, size: 50, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 10),
                        Text(
                          'Tidak ada temuan hazard ditemukan.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tekan tombol Lapor Hazard di bawah untuk membuat laporan baru.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 84),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final item = _items[idx];
                        return _buildSimpleHazardCard(item);
                      },
                      childCount: _items.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge(String label, int count, Color color, Color bg, Color border, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _activeFilter == key;
    return InkWell(
      onTap: () {
        setState(() => _activeFilter = key);
        _loadData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleHazardCard(HazardReportItem item) {
    final isClosed = item.statusTemuan.toLowerCase() == 'closed';
    final hasBeforePhoto = item.fotoTemuan != null && item.fotoTemuan!.isNotEmpty;
    final hasAfterPhoto = item.fotoPerbaikan != null && item.fotoPerbaikan!.isNotEmpty;

    // Risk level styling
    final isExtreme = item.tingkatResiko.toLowerCase().contains('ekstrim');
    final isHigh = item.tingkatResiko.toLowerCase().contains('tinggi');
    final isMedium = item.tingkatResiko.toLowerCase().contains('sedang');

    final riskColor = isExtreme
        ? const Color(0xFFDC2626)
        : isHigh
            ? const Color(0xFFEA580C)
            : isMedium
                ? const Color(0xFFD97706)
                : const Color(0xFF059669);

    final riskBg = isExtreme
        ? const Color(0xFFFEF2F2)
        : isHigh
            ? const Color(0xFFFFF7ED)
            : isMedium
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFECFDF5);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isAssignedToMe && !isClosed ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          width: item.isAssignedToMe && !isClosed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Penugasan PJA (jika ditugaskan ke user login)
          if (item.isAssignedToMe && !isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.assignment_ind_rounded, color: Color(0xFF0284C7), size: 13),
                  SizedBox(width: 6),
                  Text(
                    'TUGAS PJA UNTUK ANDA (HARAP DITINDAKLANJUTI)',
                    style: TextStyle(color: Color(0xFF0369A1), fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row: Status, Risk, Date, Popup
                Row(
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isClosed ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isClosed ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        item.statusTemuan.toUpperCase(),
                        style: TextStyle(
                          color: isClosed ? const Color(0xFF059669) : const Color(0xFFD97706),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Risk Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: riskBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.tingkatResiko,
                        style: TextStyle(color: riskColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Category
                    Flexible(
                      child: Text(
                        item.kategoriBahaya ?? 'Hazard',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      ),
                    ),
                    const Spacer(),
                    // Date
                    Text(
                      item.tanggal,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                    ),
                    const SizedBox(width: 2),
                    // 3-dot Popup Menu
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 18),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        switch (val) {
                          case 'pdf_share':
                            HazardPdfService.shareHazardPdf(item);
                            break;
                          case 'pdf_print':
                            HazardPdfService.printHazardPdf(item);
                            break;
                          case 'close':
                            _showCloseModal(item);
                            break;
                          case 'reassign':
                            _showReassignModal(item);
                            break;
                          case 'edit':
                            _openCreateHazard(item);
                            break;
                          case 'delete':
                            _confirmDelete(item);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'pdf_share',
                          child: Row(
                            children: [
                              Icon(Icons.share_rounded, color: Color(0xFF0284C7), size: 16),
                              SizedBox(width: 8),
                              Text('Bagikan PDF', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'pdf_print',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 16),
                              SizedBox(width: 8),
                              Text('Cetak PDF', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                            ],
                          ),
                        ),
                        if (!isClosed && (item.canClose || item.isAssignedToMe || item.isMyReport))
                          const PopupMenuItem(
                            value: 'close',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 16),
                                SizedBox(width: 8),
                                Text('Close Hazard', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                              ],
                            ),
                          ),
                        if (!isClosed)
                          const PopupMenuItem(
                            value: 'reassign',
                            child: Row(
                              children: [
                                Icon(Icons.person_pin_circle_rounded, color: Color(0xFFD97706), size: 16),
                                SizedBox(width: 8),
                                Text('Alihkan PJA', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                              ],
                            ),
                          ),
                        if (item.canDelete && !isClosed)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 16),
                                SizedBox(width: 8),
                                Text('Hapus Laporan', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Location Line
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFFEA580C), size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${item.area ?? "-"} • ${item.lokasi ?? "-"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Finding Description
                Text(
                  item.temuan,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF334155), fontSize: 12, height: 1.35),
                ),

                // Compact Photo Badges (Simple & Clean)
                if (hasBeforePhoto || hasAfterPhoto) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (hasBeforePhoto)
                        _buildPhotoBadge(
                          url: item.fotoTemuan!,
                          title: 'Foto Temuan (Before)',
                          label: 'Foto Temuan',
                          color: const Color(0xFF475569),
                          bg: const Color(0xFFF1F5F9),
                          border: const Color(0xFFCBD5E1),
                        ),
                      if (hasAfterPhoto)
                        _buildPhotoBadge(
                          url: item.fotoPerbaikan!,
                          title: 'Foto Perbaikan (After)',
                          label: 'Bukti Perbaikan',
                          color: const Color(0xFF059669),
                          bg: const Color(0xFFECFDF5),
                          border: const Color(0xFFA7F3D0),
                        ),
                    ],
                  ),
                ],

                // Subtle Perbaikan Callout (Hanya jika ada)
                if (item.perbaikan != null && item.perbaikan!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 13),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.perbaikan!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF065F46), fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 6),

                // Footer Metadata & Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pelapor: ${item.nama}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                          Text('PJA: ${item.pja ?? "Belum Ditunjuk"}', style: const TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.share_rounded, color: Color(0xFF64748B), size: 18),
                          tooltip: 'Bagikan PDF',
                          onPressed: () => HazardPdfService.shareHazardPdf(item),
                        ),
                        if (!isClosed && (item.isAssignedToMe || item.isMyReport)) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: item.isAssignedToMe ? const Color(0xFF0284C7) : const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              minimumSize: const Size(54, 28),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showCloseModal(item),
                            child: Text(
                              item.isAssignedToMe ? 'Tuntaskan' : 'Close',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBadge({
    required String url,
    required String title,
    required String label,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return InkWell(
      onTap: () => _showImagePreview(url, title),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
