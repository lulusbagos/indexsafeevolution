import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/observation_detail_model.dart';
import '../../models/observation_tran_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/sync.dart';
import '../../utils/helpers.dart';
import '../../widgets/professional_success_sheet.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import '../home_page.dart';
import '../../utils/globals.dart' as globals;

class ObservationDetailPage extends StatefulWidget {
  const ObservationDetailPage({
    this.observationTrnModel,
    this.observationPoints = const [],
    this.observationResults = const [],
    this.editServerId,
    this.initialDetails = const [],
    this.initialDetail,
    super.key,
  });

  final ObservationTrnModel? observationTrnModel;
  final List<MapEntry<int, dynamic>> observationPoints;
  final List<MapEntry<int, dynamic>> observationResults;
  final int? editServerId;
  final List<ObservationDetailModel> initialDetails;
  final ObservationDetailModel? initialDetail;

  @override
  State<ObservationDetailPage> createState() => _ObservationDetailPageState();
}

class _ObservationDetailPageState extends State<ObservationDetailPage> {
  static const Color primaryBlue = Color(0xFF0284C7); // Sapphire / Sky Blue
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _remark = TextEditingController();
  final List<ObservationDetailModel> _itemList = [];
  final List<MapEntry<int, dynamic>> _perihalList = [];
  final List<MapEntry<int, dynamic>> _hasilList = [];
  int? _perihalId;
  int? _hasilId;
  int _pointId = 0;
  String? _image;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDetails.isNotEmpty) {
        setState(() {
          _itemList.addAll(widget.initialDetails.map(
              (detail) => ObservationDetailModel.fromJson(detail.toJson())));
        });
      } else if (widget.initialDetail != null) {
        setState(() => _itemList.add(widget.initialDetail!));
      }

      if (widget.observationPoints.isNotEmpty ||
          widget.observationResults.isNotEmpty) {
        setState(() {
          _perihalList.addAll(widget.observationPoints);
          _hasilList.addAll(widget.observationResults);
        });
        return;
      }

      _db.rawQuery('''select
        id id_perihal_yang_diobservasi,
        "name" perihal_yang_diobservasi
      from observation_masters om 
      where om.deleted_at is null and type = 'point'
      order by om."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _perihalList.addAll({
              for (var row in val.toList())
                row['id_perihal_yang_diobservasi'] as int:
                    row['perihal_yang_diobservasi']
            }.entries.toList());
            _perihalList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

      _db.rawQuery('''select
        id id_hasil_observasi,
        "name" hasil_observasi
      from observation_masters om 
      where om.deleted_at is null and type = 'result'
      order by om."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _hasilList.addAll({
              for (var row in val.toList())
                row['id_hasil_observasi'] as int: row['hasil_observasi']
            }.entries.toList());
            _hasilList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _remark.dispose();
    super.dispose();
  }

  void _prepareNewDetail() {
    _pointId++;
    _perihalId = null;
    _hasilId = null;
    _remark.clear();
    _image = null;
  }

  int? _findPointId(String? point) => _perihalList
      .where((item) => item.value.toString() == (point ?? ''))
      .firstOrNull
      ?.key;

  int? _findResultId(String? result) {
    final value = (result ?? '').trim().toUpperCase();
    return _hasilList
        .where((item) {
          final candidate = item.value.toString().trim().toUpperCase();
          return candidate == value ||
              (value.isNotEmpty && candidate.startsWith(value.substring(0, 1)));
        })
        .firstOrNull
        ?.key;
  }

  Widget _observationImagePreview(String path, {double? height, BoxFit fit = BoxFit.cover}) {
    final source = path.trim();
    final remote = source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('/uploads/') ||
        source.startsWith('uploads/') ||
        source.startsWith('~/uploads/');
    final remoteUrl =
        source.startsWith('http://') || source.startsWith('https://')
            ? source
            : '${_api.mbsWebUrl}/${source.replaceFirst(RegExp(r'^~?/+'), '')}';
    final image = remote
        ? Image.network(
            remoteUrl,
            width: double.infinity,
            height: height ?? double.infinity,
            fit: fit,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 28),
              ),
            ),
          )
        : Image.file(
            File(source),
            width: double.infinity,
            height: height ?? double.infinity,
            fit: fit,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 28),
              ),
            ),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: image);
  }

  void _showImageSourcePicker(void Function(void Function()) setStateModal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ambil foto temuan perilaku atau kondisi kerja yang diamati',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        pickImage(source: ImageSource.camera).then((file) {
                          if (file != null) {
                            setStateModal(() => _image = file.path);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera_rounded, color: Color(0xFF16A34A), size: 30),
                            SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        pickImage(source: ImageSource.gallery).then((file) {
                          if (file != null) {
                            setStateModal(() => _image = file.path);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB), size: 30),
                            SizedBox(height: 8),
                            Text(
                              'Galeri',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E40AF),
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
            ],
          ),
        ),
      ),
    );
  }

  Color _getResultBadgeColor(String? typeStr) {
    final t = (typeStr ?? '').toUpperCase();
    if (t.contains('P') || t.contains('SAFE') || t.contains('POSITIF') || t.contains('POSITIVE')) {
      return const Color(0xFF16A34A); // Green
    } else if (t.contains('I') || t.contains('IMPROVE') || t.contains('PERBAIKAN')) {
      return const Color(0xFFD97706); // Amber
    } else {
      return const Color(0xFFDC2626); // Red
    }
  }

  String _getResultLabel(String? typeStr) {
    final t = (typeStr ?? '').toUpperCase();
    if (t.contains('P') || t.contains('SAFE') || t.contains('POSITIF') || t.contains('POSITIVE')) {
      return 'AMAN (SAFE)';
    } else if (t.contains('I') || t.contains('IMPROVE') || t.contains('PERBAIKAN')) {
      return 'PERBAIKAN';
    } else {
      return 'BERISIKO (AT-RISK)';
    }
  }

  Future<dynamic> _showBottomSheet({int? editIndex}) {
    final editing = editIndex != null;
    final oldDetail = editing ? _itemList[editIndex] : null;
    if (editing) {
      _perihalId = _findPointId(oldDetail?.point);
      _hasilId = _findResultId(oldDetail?.type);
      _remark.text = oldDetail?.remark ?? '';
      _image = oldDetail?.image;
      _pointId = oldDetail?.pointId ?? _pointId;
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setState_) {
          final isFormValid = _perihalId != null &&
              _hasilId != null &&
              _remark.text.trim().isNotEmpty;

          return FractionallySizedBox(
            heightFactor: 0.92,
            child: SafeArea(
              child: Column(
                children: [
                  // Modern Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.visibility_rounded,
                                color: primaryBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    editing ? 'Edit Temuan Observasi' : 'Tambah Temuan Observasi',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Text(
                                    'Pilih perihal perilaku, hasil observasi, dan dokumentasi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Form Body
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        24 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERIHAL YANG DIOBSERVASI *',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownSearch<MapEntry<int, dynamic>>(
                            selectedItem: _perihalList
                                .where((item) => item.key == _perihalId)
                                .firstOrNull,
                            items: _perihalList,
                            itemAsString: (item) => item.value.toString(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                hintText: 'Pilih perihal yang diamati...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(Icons.visibility_outlined, color: primaryBlue, size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                            popupProps: const PopupProps.menu(
                              fit: FlexFit.loose,
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Cari perihal yang diobservasi...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                              ),
                            ),
                            onChanged: (item) {
                              if (item == null) return;
                              setState_(() => _perihalId = item.key);
                            },
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'HASIL OBSERVASI *',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownSearch<MapEntry<int, dynamic>>(
                            selectedItem: _hasilList
                                .where((item) => item.key == _hasilId)
                                .firstOrNull,
                            items: _hasilList,
                            itemAsString: (item) => item.value.toString(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                hintText: 'Pilih hasil evaluasi observasi...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(Icons.fact_check_outlined, color: primaryBlue, size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                            popupProps: const PopupProps.menu(
                              fit: FlexFit.loose,
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Cari hasil observasi...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                              ),
                            ),
                            onChanged: (item) {
                              if (item == null) return;
                              setState_(() => _hasilId = item.key);
                            },
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'KETERANGAN / TINDAKAN *',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _remark,
                            minLines: 3,
                            maxLines: 4,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Tuliskan detail pengamatan perilaku atau tindakan koreksi yang dilakukan...',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                              ),
                            ),
                            onChanged: (_) => setState_(() {}),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'DOKUMENTASI FOTO (OPSIONAL)',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _showImageSourcePicker(setState_),
                            borderRadius: BorderRadius.circular(14),
                            child: _image == null || _image == ''
                                ? Container(
                                    width: double.infinity,
                                    height: 115,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2FE),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFBAE6FD)),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: primaryBlue,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Ambil atau Unggah Foto Temuan',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Ketuk untuk membuka Kamera atau Galeri ponsel',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    width: double.infinity,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _observationImagePreview(_image!, height: 160),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: InkWell(
                                            onTap: () => setState_(() => _image = null),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.65),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.65),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.cached_rounded, color: Colors.white, size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Ganti Foto',
                                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 22),

                          // Submit Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              icon: Icon(editing ? Icons.check_rounded : Icons.add_rounded),
                              label: Text(
                                editing ? 'Simpan Perubahan' : 'Tambahkan Temuan',
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: isFormValid ? primaryBlue : const Color(0xFFCBD5E1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: !isFormValid
                                  ? null
                                  : () {
                                      var point = _perihalList
                                          .where((i) => i.key == _perihalId)
                                          .first
                                          .value;
                                      var type = _hasilList
                                          .where((i) => i.key == _hasilId)
                                          .first
                                          .value;

                                      final detail = ObservationDetailModel(
                                        name: '$point - $type',
                                        point: point,
                                        type: type.toString().substring(0, 1),
                                        image: _image,
                                        remark: _remark.text.trim(),
                                        pointId: _pointId,
                                        id: oldDetail?.id,
                                        tranId: oldDetail?.tranId,
                                        refId: oldDetail?.refId,
                                        syncId: oldDetail?.syncId,
                                      );

                                      setState(() {
                                        if (editing) {
                                          _itemList[editIndex] = detail;
                                        } else {
                                          _itemList.add(detail);
                                        }
                                        _perihalId = null;
                                        _hasilId = null;
                                        _image = null;
                                        _remark.clear();
                                        Navigator.pop(context);
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: const TopBar(title: 'Detail Observasi', back: 1),
        body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Intro Card
              const SapHeaderCard(
                title: 'Temuan Safety Observation',
                subtitle: 'Evaluasi perilaku kerja aman atau berisiko beserta dokumentasi temuan lapangan.',
                icon: Icons.visibility_rounded,
                accentColor: primaryBlue,
                badgeBgColor: Color(0xFFF0F9FF),
                badgeBorderColor: Color(0xFFBAE6FD),
              ),

              // Summary Context Card
              if (widget.observationTrnModel != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: primaryBlue),
                          const SizedBox(width: 6),
                          const Text(
                            'INFORMASI OBSERVASI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          if ((widget.observationTrnModel?.riskLevel ?? '').isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: _getRiskColor(widget.observationTrnModel!.riskLevel!).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _getRiskColor(widget.observationTrnModel!.riskLevel!).withOpacity(0.3)),
                              ),
                              child: Text(
                                widget.observationTrnModel!.riskLevel!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: _getRiskColor(widget.observationTrnModel!.riskLevel!),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 16),
                      Text(
                        widget.observationTrnModel?.subject ?? '-',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.corporate_fare_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${widget.observationTrnModel?.companyName ?? "-"} (${widget.observationTrnModel?.deptName ?? "-"})',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${widget.observationTrnModel?.area ?? "-"} • ${widget.observationTrnModel?.lokasi ?? "-"}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Section Title with Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'DAFTAR TEMUAN OBSERVASI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_itemList.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Findings List / Empty State
              if (_itemList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Icon(
                          Icons.playlist_add_check_rounded,
                          color: primaryBlue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Belum Ada Temuan Observasi',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tambahkan temuan perilaku aman (Safe) atau perilaku berisiko (At-Risk) yang Anda amati di lapangan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Tambah Temuan Pertama'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBlue,
                          side: const BorderSide(color: primaryBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          setState(_prepareNewDetail);
                          _showBottomSheet();
                        },
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _itemList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _itemList[index];
                    final badgeColor = _getResultBadgeColor(item.type);
                    final badgeLabel = _getResultLabel(item.type);
                    final hasImage = (item.image ?? '').trim().isNotEmpty;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Accent Color Bar
                              Container(
                                width: 5,
                                color: badgeColor,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image Thumbnail or Icon Indicator
                                      if (hasImage)
                                        Container(
                                          width: 52,
                                          height: 52,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: _observationImagePreview(item.image!, height: 52),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 44,
                                          height: 44,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            badgeLabel.contains('AMAN')
                                                ? Icons.check_circle_outline_rounded
                                                : Icons.warning_amber_rounded,
                                            color: badgeColor,
                                            size: 22,
                                          ),
                                        ),

                                      // Main Text Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: badgeColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: badgeColor.withOpacity(0.25)),
                                                  ),
                                                  child: Text(
                                                    badgeLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: badgeColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              (item.point ?? item.name ?? 'Temuan Lapangan').trim(),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            if ((item.remark ?? '').trim().isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                item.remark!.trim(),
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF64748B),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Action Buttons
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit hasil',
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.edit_outlined, color: primaryBlue, size: 19),
                                            onPressed: () => _showBottomSheet(editIndex: index),
                                          ),
                                          IconButton(
                                            tooltip: 'Hapus hasil',
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 19),
                                            onPressed: () {
                                              setState(() => _itemList.removeAt(index));
                                            },
                                          ),
                                        ],
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
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // Bottom Action Bar
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Tambah',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBlue,
                        side: const BorderSide(color: primaryBlue, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(_prepareNewDetail);
                        _showBottomSheet();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        _isSaving ? 'Menyimpan...' : 'Simpan Observasi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: (_itemList.isEmpty || _isSaving)
                            ? const Color(0xFFCBD5E1)
                            : primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (_itemList.isEmpty || _isSaving) ? null : _saveObservation,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRiskColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('critical') || lower.contains('ekstrim') || lower.contains('extreme')) {
      return const Color(0xFFDC2626);
    } else if (lower.contains('high') || lower.contains('tinggi')) {
      return const Color(0xFFEA580C);
    } else if (lower.contains('medium') || lower.contains('sedang')) {
      return const Color(0xFFD97706);
    } else {
      return const Color(0xFF16A34A);
    }
  }

  Future<void> _saveObservation() async {
    if (_isSaving || _itemList.isEmpty) return;
    setState(() => _isSaving = true);
    SnackBarMsg.loader(context, true);

    try {
      widget.observationTrnModel?.createdAt = DateTime.now().toString();
      widget.observationTrnModel?.updatedAt = DateTime.now().toString();

      if (widget.editServerId != null) {
        final updated = await _saveEditedObservation();
        if (!mounted) return;
        SnackBarMsg.loader(context, false);
        if (updated) {
          await showProfessionalSuccessSheet(
            context: context,
            title: 'Observasi Diperbarui',
            subtitle: 'Perubahan data observasi perilaku telah berhasil disimpan ke sistem.',
            accentColor: primaryBlue,
            icon: Icons.check_circle_rounded,
            statusBadgeText: 'TERCATAT & TERSIMPAN',
            primaryButtonText: 'Selesai & Ke Beranda',
            receiptItems: [
              const SuccessReceiptItem(
                label: 'Program SAP',
                value: 'Safety Observation (BBS)',
                icon: Icons.visibility_rounded,
              ),
              SuccessReceiptItem(
                label: 'Jumlah Temuan',
                value: '${_itemList.length} Poin Temuan',
                icon: Icons.fact_check_rounded,
                isHighlight: true,
                highlightColor: primaryBlue,
              ),
            ],
            onPrimaryAction: () => _goHome(),
          );
          _goHome();
        } else {
          SnackBarMsg.danger(context, 'Pembaruan belum berhasil. Periksa koneksi internet lalu coba lagi.');
        }
        return;
      }

      final observation = widget.observationTrnModel;
      if (observation == null) {
        throw StateError('Data observasi tidak tersedia.');
      }
      final tranId = await _db.insert('observation_trans', observation.toJson());
      if (tranId <= 0) {
        if (mounted) {
          SnackBarMsg.loader(context, false);
          SnackBarMsg.danger(context, 'Data observasi gagal disimpan ke database lokal.');
        }
        return;
      }

      for (final row in _itemList) {
        row.tranId = tranId;
        row.status = 0;
        await _db.insert('observation_details', row.toJson());
      }

      final synced = await syncTran(_db, _api, 'observation', tranId);
      if (!mounted) return;
      SnackBarMsg.loader(context, false);

      await showProfessionalSuccessSheet(
        context: context,
        title: synced ? 'Observasi Berhasil Disimpan' : 'Data Tersimpan Offline',
        subtitle: synced
            ? 'Seluruh hasil observasi dan bukti foto telah tercatat di server.'
            : 'Data tersimpan aman di perangkat dan akan disinkronkan otomatis saat ada jaringan.',
        accentColor: primaryBlue,
        icon: Icons.check_circle_rounded,
        statusBadgeText: synced ? 'TERCATAT & TERSINKRON' : 'TERSIMPAN OFFLINE',
        isOffline: !synced,
        primaryButtonText: 'Selesai & Ke Beranda',
        receiptItems: [
          const SuccessReceiptItem(
            label: 'Program SAP',
            value: 'Safety Observation (BBS)',
            icon: Icons.visibility_rounded,
          ),
          SuccessReceiptItem(
            label: 'Waktu Observasi',
            value: '${widget.observationTrnModel?.date ?? "-"} ${widget.observationTrnModel?.time ?? ""}',
            icon: Icons.access_time_rounded,
          ),
          SuccessReceiptItem(
            label: 'Perusahaan',
            value: widget.observationTrnModel?.companyName ?? '-',
            icon: Icons.business_rounded,
          ),
          SuccessReceiptItem(
            label: 'Area / Lokasi',
            value: '${widget.observationTrnModel?.area ?? "-"} • ${widget.observationTrnModel?.lokasi ?? "-"}',
            icon: Icons.place_rounded,
          ),
          SuccessReceiptItem(
            label: 'Jumlah Temuan',
            value: '${_itemList.length} Poin Temuan',
            icon: Icons.fact_check_rounded,
            isHighlight: true,
            highlightColor: primaryBlue,
          ),
          SuccessReceiptItem(
            label: 'Tingkat Risiko',
            value: widget.observationTrnModel?.riskLevel ?? '-',
            icon: Icons.shield_rounded,
          ),
        ],
        onPrimaryAction: () => _goHome(),
      );
      if (!mounted) return;
      _goHome();
    } catch (e) {
      debugPrint('Observation save failed: $e');
      if (mounted) {
        SnackBarMsg.loader(context, false);
        SnackBarMsg.danger(context, 'Terjadi kendala saat menyimpan observasi: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _goHome() {
    if (!mounted) return;
    SnackBarMsg.loader(context, false);
    globals.currentPage = 0;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<bool> _saveEditedObservation() async {
    for (var index = 0; index < _itemList.length; index++) {
      final detail = _itemList[index];
      final serverId = detail.syncId ??
          detail.refId ??
          (index == 0 ? widget.editServerId : null);
      if (serverId == null) return false;

      final payload = <String, dynamic>{
        'kegiatan_yang_diamati': widget.observationTrnModel?.subject ?? '',
        'area': widget.observationTrnModel?.area ?? '',
        'lokasi': widget.observationTrnModel?.lokasi ?? '',
        'detil_lokasi': widget.observationTrnModel?.locationDetail ?? '',
        'tanggal': widget.observationTrnModel?.date ?? '',
        'waktu': widget.observationTrnModel?.time ?? '',
        'perusahaan_id':
            widget.observationTrnModel?.companyId?.toString() ?? '',
        'perusahaan_yang_diamati':
            widget.observationTrnModel?.companyName ?? '',
        'departemen_yang_diamati': widget.observationTrnModel?.deptName ?? '',
        'dokumen_pendukung': widget.observationTrnModel?.docName ?? '',
        'resiko_kritis': widget.observationTrnModel?.riskName ?? '',
        'tingkat_resiko': widget.observationTrnModel?.riskLevel ?? '',
        'perihal_yang_diamati': detail.point ?? detail.name ?? '',
        'hasil_observasi': detail.type ?? '',
        'keterangan': detail.remark ?? '',
      };
      final imagePath = detail.image;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          await File(imagePath).exists()) {
        payload['image'] = await MultipartFile.fromFile(imagePath);
      }
      final updated = await _api.updateObservation(serverId, payload);
      if (!updated) return false;

      if (detail.id != null) {
        await _db.update('observation_details', detail.toJson(), detail.id!);
      }
    }
    final localObservationId = widget.observationTrnModel?.id;
    if (localObservationId != null) {
      await _db.update('observation_trans',
          widget.observationTrnModel!.toJson(), localObservationId);
    }
    return true;
  }
}
