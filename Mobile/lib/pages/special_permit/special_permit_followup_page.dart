import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/preference.dart';

class SpecialPermitFollowupPage extends StatefulWidget {
  final Map<String, dynamic> permit;

  const SpecialPermitFollowupPage({
    super.key,
    required this.permit,
  });

  @override
  State<SpecialPermitFollowupPage> createState() => _SpecialPermitFollowupPageState();
}

class _SpecialPermitFollowupPageState extends State<SpecialPermitFollowupPage> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  final _notesCtrl = TextEditingController();
  final _correctiveCtrl = TextEditingController();

  String _inspectionStatus = 'AMAN'; // AMAN, TEMUAN, DIHENTIKAN
  String _inspectorRole = 'INSPECTOR'; // INSPECTOR, PJO, SUPERVISOR
  int _conditionRating = 5;
  bool _isSafe = true;

  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;

  final List<File> _capturedPhotos = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _determineRole();
    _getCurrentCoordinates();
  }

  void _determineRole() {
    final profile = PreferenceService.getProfile();
    final userNik = PreferenceService.getUser() ?? profile?.noNik ?? '';
    final pjoNik = widget.permit['pjoNik']?.toString().trim() ?? '';
    final inspectorNik = widget.permit['inspectorNik']?.toString().trim() ?? '';

    if (userNik.isNotEmpty && pjoNik.isNotEmpty && (userNik == pjoNik || userNik.endsWith(pjoNik) || pjoNik.endsWith(userNik))) {
      _inspectorRole = 'PJO';
    } else if (userNik.isNotEmpty && inspectorNik.isNotEmpty && (userNik == inspectorNik || userNik.endsWith(inspectorNik) || inspectorNik.endsWith(userNik))) {
      _inspectorRole = 'INSPECTOR';
    } else {
      _inspectorRole = 'SUPERVISOR';
    }
  }

  Future<void> _getCurrentCoordinates() async {
    setState(() => _isGettingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _isGettingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked != null) {
        setState(() {
          _capturedPhotos.add(File(picked.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _capturedPhotos.removeAt(index);
    });
  }

  Future<void> _submitFollowup() async {
    if (_notesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajib mengisi Catatan / Hasil Pemeriksaan Lapangan'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_inspectionStatus != 'AMAN' && _correctiveCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajib mengisi Rekomendasi / Tindakan Perbaikan karena terdapat temuan/catatan'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final profile = PreferenceService.getProfile();
      final userNik = PreferenceService.getUser() ?? profile?.noNik ?? '';
      final userName = profile?.namaLengkap ?? '';

      // Convert captured photos to base64
      final base64Photos = <String>[];
      for (final f in _capturedPhotos) {
        try {
          final bytes = await f.readAsBytes();
          base64Photos.add(base64Encode(bytes));
        } catch (_) {}
      }

      final payload = {
        'specialPermitId': widget.permit['id']?.toString() ?? '',
        'reqId': widget.permit['reqId']?.toString() ?? '',
        'activityType': widget.permit['activityType']?.toString() ?? '',
        'workLocation': widget.permit['workLocation']?.toString() ?? '',
        'inspectorNik': userNik,
        'inspectorName': userName,
        'inspectorRole': _inspectorRole,
        'inspectionStatus': _inspectionStatus,
        'inspectionNotes': _notesCtrl.text.trim(),
        'correctiveAction': _correctiveCtrl.text.trim(),
        'isSafe': _isSafe,
        'workConditionRating': _conditionRating,
        'latitude': _latitude,
        'longitude': _longitude,
        'photosBase64': base64Photos,
      };

      final res = await _api.createSpecialPermitFollowup(payload);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      res.fold(
        (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err['message']?.toString() ?? 'Gagal menyimpan verifikasi'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        },
        (data) async {
          await HapticFeedback.heavyImpact();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verifikasi Follow-up Special Permit berhasil disimpan!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
          Navigator.pop(context, true);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getActivityColor(String type) {
    final t = type.toUpperCase();
    if (t.contains('KETINGGIAN')) return const Color(0xFFDC2626); // Merah
    if (t.contains('AIR')) return const Color(0xFF0284C7); // Biru
    if (t.contains('TERBATAS') || t.contains('CONFINED')) return const Color(0xFFD97706); // Amber
    if (t.contains('PANAS') || t.contains('HOT')) return const Color(0xFFEA580C); // Orange
    return const Color(0xFF7C3AED); // Ungu
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0F2628);
    final activityType = (widget.permit['activityType'] ?? 'SPECIAL PERMIT').toString().replaceAll('_', ' ');
    final actColor = _getActivityColor(activityType);
    final reqId = widget.permit['reqId']?.toString() ?? '-';
    final location = widget.permit['workLocation']?.toString() ?? '-';
    final contractor = widget.permit['implementingContractor']?.toString() ?? '-';
    final pjoName = widget.permit['pjoName']?.toString() ?? '-';
    final inspectorName = widget.permit['inspectorName']?.toString() ?? '-';
    final hazards = widget.permit['workRelatedHazard']?.toString();
    final equipment = widget.permit['specialEquipment']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F7),
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Inspeksi Special Permit',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Detail Kegiatan High Risk
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: actColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: actColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: actColor),
                            const SizedBox(width: 5),
                            Text(
                              activityType,
                              style: TextStyle(color: actColor, fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        reqId,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.location_on_rounded, 'Lokasi Kerja', location),
                  _buildDetailRow(Icons.business_rounded, 'Kontraktor', contractor),
                  _buildDetailRow(Icons.person_pin_rounded, 'PJO Lapangan', pjoName),
                  _buildDetailRow(Icons.verified_user_rounded, 'Inspector', inspectorName),
                  if (hazards != null && hazards.isNotEmpty)
                    _buildDetailRow(Icons.report_problem_rounded, 'Potensi Bahaya', hazards),
                  if (equipment != null && equipment.isNotEmpty)
                    _buildDetailRow(Icons.build_circle_rounded, 'Peralatan Khusus', equipment),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Bagian Form Follow-Up & Verifikasi
            const Text(
              'Form Hasil Verifikasi & Inspeksi',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F2628)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pastikan inspeksi dilakukan langsung di lokasi kerja sebelum pekerjaan dimulai.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // Status Verifikasi (3 Pilihan Utama)
            _buildStatusSelector(),
            const SizedBox(height: 16),

            // Rating Kesiapan Kondisi Kerja (1-5)
            _buildRatingCard(),
            const SizedBox(height: 16),

            // Peran Verifikator (PJO / Inspector / Supervisor)
            _buildRoleSelector(),
            const SizedBox(height: 16),

            // Input Catatan / Hasil Pemeriksaan
            _buildNotesInput(),
            const SizedBox(height: 16),

            // Input Tindakan Perbaikan (jika ada temuan)
            if (_inspectionStatus != 'AMAN') ...[
              _buildCorrectiveInput(),
              const SizedBox(height: 16),
            ],

            // Dokumentasi Foto Bukti Lapangan
            _buildPhotoSection(),
            const SizedBox(height: 16),

            // Koordinat GPS & Info Pemeriksa
            _buildInspectorMetaCard(),
          ],
        ),
      ),
      bottomSheet: _buildBottomSubmitButton(),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ),
          const Text(': ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Kondisi Lapangan',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
        ),
        const SizedBox(height: 8),
        _buildStatusOption(
          statusKey: 'AMAN',
          title: 'Aman & Sesuai SOP',
          subtitle: 'Kondisi aman, APD & peralatan lengkap, pekerjaan boleh dimulai.',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF059669),
        ),
        const SizedBox(height: 8),
        _buildStatusOption(
          statusKey: 'TEMUAN',
          title: 'Ada Catatan / Temuan Minor',
          subtitle: 'Terdapat kekurangan yang wajib diperbaiki sebelum atau saat pekerjaan berlangsung.',
          icon: Icons.warning_rounded,
          color: const Color(0xFFD97706),
        ),
        const SizedBox(height: 8),
        _buildStatusOption(
          statusKey: 'DIHENTIKAN',
          title: 'Bahaya Kritis (Pekerjaan Dihentikan)',
          subtitle: 'Kondisi tidak aman / melanggar Golden Rules. Pekerjaan dilarang dimulai!',
          icon: Icons.cancel_rounded,
          color: const Color(0xFFDC2626),
        ),
      ],
    );
  }

  Widget _buildStatusOption({
    required String statusKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _inspectionStatus == statusKey;

    return Material(
      color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _inspectionStatus = statusKey;
            _isSafe = statusKey == 'AMAN';
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? color : const Color(0xFF94A3B8), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? color : const Color(0xFF0F2628),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rating Kesiapan Tempat Kerja',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_conditionRating / 5 Bintang',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                icon: Icon(
                  star <= _conditionRating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: star <= _conditionRating ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                  size: 34,
                ),
                onPressed: () => setState(() => _conditionRating = star),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peran Anda Dalam Inspeksi Ini',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRoleChip('INSPECTOR', 'Inspector'),
              const SizedBox(width: 8),
              _buildRoleChip('PJO', 'PJO'),
              const SizedBox(width: 8),
              _buildRoleChip('SUPERVISOR', 'Pengawas'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String roleKey, String label) {
    final isSelected = _inspectorRole == roleKey;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _inspectorRole = roleKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F2628) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F2628) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesInput() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catatan / Hasil Pemeriksaan Kondisi Lapangan *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tuliskan kelayakan APD khusus, barikade area, permit pendukung, safety harness/gas detector, dll.',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Contoh: Pemeriksaan dilakukan pukul 08:30. APD full body harness layak, lifeline terpasang kuat, area bawah sudah dibarikade...',
              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectiveInput() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_late_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 6),
              Text(
                'Rekomendasi / Tindakan Perbaikan Diperlukan *',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Wajib diisi karena terdapat temuan / bahaya pada inspeksi.',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _correctiveCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tindakan yang harus diselesaikan pelaksana pekerjaan...',
              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFFFFBEB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dokumentasi Foto Lapangan',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
              ),
              Text(
                '${_capturedPhotos.length} foto terpilih',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Lampirkan foto kondisi aktual area kerja, APD, dan peralatan berisiko tinggi.',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          // Action buttons: Kamera & Galeri
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F2628),
                    side: const BorderSide(color: Color(0xFF0F2628)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text('Kamera Langsung', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                  label: const Text('Dari Galeri', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          if (_capturedPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _capturedPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _capturedPhotos[idx],
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _removePhoto(idx),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInspectorMetaCard() {
    final profile = PreferenceService.getProfile();
    final userNik = PreferenceService.getUser() ?? profile?.noNik ?? '-';
    final userName = profile?.namaLengkap ?? '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: Color(0xFF0F2628)),
              SizedBox(width: 6),
              Text(
                'Identitas Verifikator Lapangan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Nama: $userName ($userNik)',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                _latitude != null && _longitude != null
                    ? 'GPS: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                    : (_isGettingLocation ? 'Mencari lokasi GPS...' : 'GPS belum terdeteksi'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              if (_isGettingLocation)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF0F2628)),
                )
              else
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF0F2628)),
                  onPressed: _getCurrentCoordinates,
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Waktu: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())} WITA',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSubmitButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2628),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isSubmitting ? null : _submitFollowup,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _isSubmitting ? 'Menyimpan ke Database...' : 'Simpan Hasil Verifikasi Inspeksi',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}
