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
import '../../widgets/button_app.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import '../home_page.dart';
import '../../utils/globals.dart' as globals;

class ObservationDetailPage extends StatefulWidget {
  const ObservationDetailPage(
      {this.observationTrnModel,
      this.observationPoints = const [],
      this.observationResults = const [],
      this.editServerId,
      this.initialDetails = const [],
      this.initialDetail,
      super.key});

  final ObservationTrnModel? observationTrnModel;
  final List<MapEntry<int, dynamic>> observationPoints;
  final List<MapEntry<int, dynamic>> observationResults;
  final int? editServerId;
  final List<ObservationDetailModel> initialDetails;
  // Kept while older navigation callers are migrated to initialDetails.
  final ObservationDetailModel? initialDetail;

  @override
  State<ObservationDetailPage> createState() => _ObservationDetailPageState();
}

class _ObservationDetailPageState extends State<ObservationDetailPage> {
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
    /** */

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

  Widget _observationImagePreview(String path, {double? height}) {
    final source = path.trim();
    // Foto dari image_picker disimpan sebagai path absolut Android
    // (`/data/user/...`). Jangan anggap seluruh path yang diawali slash
    // sebagai URL MBS; hanya folder publik web yang merupakan foto remote.
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
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
          )
        : Image.file(
            File(source),
            width: double.infinity,
            height: height ?? double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(9), child: image);
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
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(builder: (context, setState_) {
          return FractionallySizedBox(
            // Foto tambahan membuat form lebih tinggi dari layar. Jangan
            // biarkan Column statis mengunci tombol Tambah/Simpan di bawah.
            heightFactor: 0.92,
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Perihal yang Diobservasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownSearch<MapEntry<int, dynamic>>(
                      selectedItem: _perihalList
                          .where((item) => item.key == _perihalId)
                          .firstOrNull,
                      items: _perihalList,
                      itemAsString: (item) => item.value.toString(),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          hintText: 'Pilih perihal yang diamati',
                          prefixIcon: Icon(Icons.visibility_outlined),
                        ),
                      ),
                      popupProps: const PopupProps.menu(
                        fit: FlexFit.loose,
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'Cari perihal...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      onChanged: (item) {
                        if (item == null) return;
                        setState_(() => _perihalId = item.key);
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Hasil Observasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownSearch<MapEntry<int, dynamic>>(
                      selectedItem: _hasilList
                          .where((item) => item.key == _hasilId)
                          .firstOrNull,
                      items: _hasilList,
                      itemAsString: (item) => item.value.toString(),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          hintText: 'Pilih hasil observasi',
                          prefixIcon: Icon(Icons.fact_check_outlined),
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
                    const SizedBox(height: 15),
                    const Text(
                      'Keterangan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _remark,
                      minLines: 3,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 16),
                      onChanged: (String val) => setState_(() {}),
                    ),
                    const SizedBox(height: 15),
                    InkWell(
                      onTap: () async {
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt,
                                      color: Colors.grey),
                                  title: const Text('Camera'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Future<File?> imageFile =
                                        pickImage(source: ImageSource.camera);
                                    imageFile.then((value) {
                                      if (value != null) {
                                        setState_(() => _image = value.path);
                                      }
                                    });
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.image,
                                      color: Colors.grey),
                                  title: const Text('Gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Future<File?> imageFile =
                                        pickImage(source: ImageSource.gallery);
                                    imageFile.then((value) {
                                      if (value != null) {
                                        setState_(() => _image = value.path);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _image == null || _image == ''
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Upload Foto',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              )
                            : _observationImagePreview(_image!),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: buttonApp(
                        label: editing ? 'Simpan Perubahan' : 'Tambah',
                        onPressed: (_perihalId == null ||
                                _hasilId == null ||
                                _remark.text == '')
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
                                  type: type.substring(0, 1),
                                  image: _image,
                                  remark: _remark.text,
                                  pointId: _pointId,
                                  // Pertahankan identitas detail yang sudah
                                  // tersinkron ketika pengguna mengeditnya.
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
                                  _remark.text = '';
                                  Navigator.pop(context);
                                });
                              },
                      ),
                    ),
                  ],
                ),
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
      canPop: false,
      child: Scaffold(
        appBar: const TopBar(title: 'Detail Observation', back: 2),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.builder(
            controller: _scrollCtrl,
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _itemList.length,
            itemBuilder: (context, index) {
              return Card(
                color: Colors.white,
                shadowColor: Colors.indigo,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _showBottomSheet(editIndex: index),
                  leading: (_itemList[index].image ?? '').trim().isEmpty
                      ? null
                      : SizedBox(
                          width: 48,
                          height: 48,
                          child: _observationImagePreview(
                              _itemList[index].image!,
                              height: 48),
                        ),
                  title: Text(
                    (_itemList[index].name ?? '').trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo,
                    ),
                  ),
                  subtitle: Text(
                    (_itemList[index].remark ?? '').trim(),
                  ),
                  trailing: SizedBox(
                    width: 76,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit hasil',
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.edit_rounded,
                              color: Colors.indigo, size: 20),
                          onPressed: () => _showBottomSheet(editIndex: index),
                        ),
                        IconButton(
                          tooltip: 'Hapus hasil',
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.cancel,
                              color: Colors.red.shade400, size: 20),
                          onPressed: () {
                            setState(() => _itemList.removeAt(index));
                          },
                        ),
                      ],
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          height: 150,
          child: Column(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: buttonApp(
                  label: 'Tambah Hasil Observasi',
                  bgColor: Colors.green,
                  onPressed: () {
                    setState(_prepareNewDetail);
                    _showBottomSheet();
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: buttonApp(
                  label: _isSaving ? 'Menyimpan...' : 'Simpan',
                  onPressed: (_itemList.isEmpty || _isSaving)
                      ? null
                      : _saveObservation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          await _showSaveResult(
            success: true,
            title: 'Observasi diperbarui',
            message: 'Perubahan berhasil disimpan ke sistem.',
            goHome: true,
          );
          _goHome();
        } else {
          await _showSaveResult(
            success: false,
            title: 'Pembaruan belum berhasil',
            message: 'Periksa koneksi internet lalu coba simpan kembali.',
          );
        }
        return;
      }

      final observation = widget.observationTrnModel;
      if (observation == null) {
        throw StateError('Data observasi tidak tersedia.');
      }
      final tranId =
          await _db.insert('observation_trans', observation.toJson());
      if (tranId <= 0) {
        if (mounted) {
          SnackBarMsg.loader(context, false);
          await _showSaveResult(
            success: false,
            title: 'Penyimpanan gagal',
            message: 'Data belum dapat disimpan. Silakan coba lagi.',
          );
        }
        return;
      }

      for (final row in _itemList) {
        row.tranId = tranId;
        row.status = 0;
        await _db.insert('observation_details', row.toJson());
      }

      // Tunggu semua detail (termasuk foto) selesai dikirim sebelum kembali
      // ke Beranda. Tombol tetap terkunci selama proses ini berjalan.
      final synced = await syncTran(_db, _api, 'observation', tranId);
      if (!mounted) return;
      SnackBarMsg.loader(context, false);
      await _showSaveResult(
        success: synced,
        title:
            synced ? 'Observasi berhasil disimpan' : 'Data tersimpan offline',
        message: synced
            ? 'Semua hasil observasi dan foto telah diproses.'
            : 'Data aman di perangkat dan akan disinkronkan otomatis saat ada jaringan.',
        goHome: true,
      );
      if (!mounted) return;
      _goHome();
    } catch (e) {
      debugPrint('Observation save failed: $e');
      if (mounted) {
        SnackBarMsg.loader(context, false);
        await _showSaveResult(
          success: false,
          title: 'Penyimpanan gagal',
          message: 'Terjadi kendala. Periksa data dan koneksi lalu coba lagi.',
        );
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

  Future<void> _showSaveResult({
    required bool success,
    required String title,
    required String message,
    bool goHome = false,
  }) async {
    final color = success ? const Color(0xFF169B62) : const Color(0xFFE05252);
    final icon = success ? Icons.check_rounded : Icons.error_outline_rounded;
    final dialog = showGeneralDialog<void>(
      context: context,
      barrierDismissible: !goHome,
      barrierLabel: 'Status penyimpanan observasi',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 30,
                    offset: Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: .12),
                  ),
                  child: Icon(icon, color: color, size: 42),
                ),
                const SizedBox(height: 18),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172033))),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: Color(0xFF667085))),
                const SizedBox(height: 20),
                if (goHome)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Mengarahkan ke Beranda...',
                          style: TextStyle(color: Color(0xFF667085))),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Mengerti'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
    );
    if (goHome) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    await dialog;
  }

  Future<bool> _saveEditedObservation() async {
    for (var index = 0; index < _itemList.length; index++) {
      final detail = _itemList[index];
      // Observasi MBS menyimpan setiap hasil sebagai baris tersendiri. Gunakan
      // ID sinkron per-detail supaya mengganti foto item kedua/ketiga tidak
      // salah menimpa foto pada item pertama.
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

      // Simpan path foto yang baru ke cache lokal juga. Ketika form dibuka
      // ulang, preview mengambil data ini sehingga tidak kembali ke foto lama.
      if (detail.id != null) {
        await _db.update('observation_details', detail.toJson(), detail.id!);
      }
    }
    // PDF observasi dibentuk dari cache History. Perbarui header lokal juga
    // supaya perubahan form awal (tanggal, lokasi, risiko, dsb.) ikut tampil
    // bersama foto detail yang baru saat PDF dibuka lagi.
    final localObservationId = widget.observationTrnModel?.id;
    if (localObservationId != null) {
      await _db.update('observation_trans',
          widget.observationTrnModel!.toJson(), localObservationId);
    }
    return true;
  }
}
