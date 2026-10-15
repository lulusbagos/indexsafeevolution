import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/preference.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'ci_model.dart';
import 'ci_page.dart';

const _navy = Color(0xFF123B63);
const _cyan = Color(0xFF0EA5A8);
const _surface = Color(0xFFF4F7FA);

class CiFormPage extends StatefulWidget {
  const CiFormPage(this.type, {super.key});
  final String type;

  @override
  State<CiFormPage> createState() => _CiFormPageState();
}

class _CiFormPageState extends State<CiFormPage> {
  static const _steps = ['Konteks', 'Penilaian', 'Tindakan', 'Review'];
  final _profile = PreferenceService.getProfile();
  final _location = TextEditingController();
  final _coordinate = TextEditingController();
  final _areaOwner = TextEditingController();
  final _context = TextEditingController();
  final _mainArea = TextEditingController();
  final _locationDetail = TextEditingController();
  final _pitSector = TextEditingController();
  final _frontName = TextEditingController();
  final _benchmark = TextEditingController();
  final _roadName = TextEditingController();
  final _roadSegment = TextEditingController();
  final _segmentLength = TextEditingController(text: '100');
  final _disposalName = TextEditingController();
  final _dumpPad = TextEditingController();
  final _pondName = TextEditingController();
  final _environmentPoint = TextEditingController();
  final _sidakTeam = TextEditingController();
  final _approver = TextEditingController();
  final _ruleVersion =
      TextEditingController(text: 'Condition Index Rule Set v1.0');
  final _temporaryControls = TextEditingController();
  final _action = TextEditingController();
  final _actionOwner = TextEditingController();
  late final List<CiAnswer> _answers;
  late final Map<String, TextEditingController> _rciDeficitControllers;
  late final Map<String, GlobalKey> _parameterKeys;
  late final Map<String, ExpansibleController> _groupControllers;
  final _companyKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _areaOwnerKey = GlobalKey();
  final _contextKey = GlobalKey();
  final _approverKey = GlobalKey();
  final _observationKey = GlobalKey();
  final _actionKey = GlobalKey();
  final _actionOwnerKey = GlobalKey();
  GlobalKey? _invalidFieldKey;
  final List<String> _evidence = [];
  String? _attentionParameterId;
  int _step = 0;
  int? _companyId;
  String _shift = 'Day Shift';
  String _weather = 'Cerah';
  final int _consequence = 3;
  final int _likelihood = 3;
  final String _exposure = 'Medium';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  DateTime _validUntil = DateTime.now().add(const Duration(days: 1));
  double? _lockedSegmentLength;
  bool _saving = false;

  List<CiParameter> get _parameters => CiCatalog.forType(widget.type);
  double get _index => CiRules.index(_answers, _parameters);
  String get _band => CiRules.band(_index);
  String get _operationalStatus => CiRules.status(_index, false);
  String get _priority =>
      CiRules.priority(_consequence, _likelihood, _exposure, false);

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId;
    _areaOwner.text = _profile?.depart ?? '';
    _sidakTeam.text = _profile?.namaLengkap ?? '';
    _answers = _parameters.map((e) => CiAnswer(parameterId: e.id)).toList();
    if (widget.type == 'RCI') {
      for (final answer in _answers) {
        answer
          ..value = '0'
          ..unit = 'm'
          ..score = 4;
      }
    }
    _rciDeficitControllers = widget.type == 'RCI'
        ? {
            for (final answer in _answers)
              answer.parameterId: TextEditingController(text: answer.value)
          }
        : {};
    _parameterKeys = {
      for (final parameter in _parameters) parameter.id: GlobalKey(),
    };
    _groupControllers = {
      for (final parameter in _parameters)
        parameter.group: ExpansibleController(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => fillGpsCoordinate(
        context, _coordinate, () => setState(() {}),
        silent: true));
  }

  @override
  void dispose() {
    for (final controller in [
      _location,
      _coordinate,
      _areaOwner,
      _context,
      _mainArea,
      _locationDetail,
      _pitSector,
      _frontName,
      _benchmark,
      _roadName,
      _roadSegment,
      _segmentLength,
      _disposalName,
      _dumpPad,
      _pondName,
      _environmentPoint,
      _sidakTeam,
      _approver,
      _ruleVersion,
      _temporaryControls,
      _action,
      _actionOwner
    ]) {
      controller.dispose();
    }
    for (final controller in _rciDeficitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  void _focusField(GlobalKey key, String message) {
    setState(() => _invalidFieldKey = key);
    _message(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            alignment: .18);
      }
    });
  }

  void _clearInvalid(GlobalKey key) {
    if (_invalidFieldKey == key) setState(() => _invalidFieldKey = null);
  }

  Widget _validationField(GlobalKey key, Widget child) => AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 180),
      padding:
          _invalidFieldKey == key ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: BoxDecoration(
          color: _invalidFieldKey == key ? const Color(0xFFFFF1F2) : null,
          borderRadius: BorderRadius.circular(14),
          border: _invalidFieldKey == key
              ? Border.all(color: const Color(0xFFDC2626), width: 1.5)
              : null),
      child: child);

  bool _isUnanswered(CiAnswer answer) =>
      answer.score == null && answer.value != '__NA__';

  void _focusFirstUnanswered() {
    final answer = _answers.firstWhere(_isUnanswered);
    final parameter =
        _parameters.firstWhere((item) => item.id == answer.parameterId);
    setState(() {
      _step = 1;
      _attentionParameterId = parameter.id;
    });
    _message('${parameter.id} • ${parameter.title} belum dinilai.');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _groupControllers[parameter.group]?.expand();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      final targetContext = _parameterKeys[parameter.id]?.currentContext;
      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          alignment: .08,
        );
      }
    });
  }

  bool _validate() {
    if (_step == 0 && _companyId == null) {
      _focusField(_companyKey, 'Pilih perusahaan terlebih dahulu.');
      return false;
    }
    if (_step == 0 && _location.text.trim().isEmpty) {
      _focusField(_locationKey, 'Isi lokasi / area inspeksi.');
      return false;
    }
    if (_step == 0 && _areaOwner.text.trim().isEmpty) {
      _focusField(_areaOwnerKey, 'Isi pemilik area / departemen.');
      return false;
    }
    if (_step == 0 && _context.text.trim().isEmpty) {
      _focusField(_contextKey, 'Isi detail konteks asesmen.');
      return false;
    }
    if (_step == 0 && widget.type == 'RCI' && _approver.text.trim().isEmpty) {
      _focusField(
          _approverKey, 'Pilih atau isi nama Approver untuk penilaian RCI.');
      return false;
    }
    if ((_step == 1 || _step == 3) && _answers.any(_isUnanswered)) {
      _focusFirstUnanswered();
      return false;
    }
    if (_step == 2 && _temporaryControls.text.trim().isEmpty) {
      _focusField(
          _observationKey, 'Isi catatan observasi / kontrol sementara.');
      return false;
    }
    if (_step == 2 && _action.text.trim().isEmpty) {
      _focusField(_actionKey, 'Isi rekomendasi tindakan perbaikan.');
      return false;
    }
    if (_step == 2 && _actionOwner.text.trim().isEmpty) {
      _focusField(_actionOwnerKey, 'Isi PIC tindakan perbaikan.');
      return false;
    }
    return true;
  }

  Future<void> _next() async {
    if (!_validate()) return;
    if (_step == 0 && widget.type == 'RCI') {
      final length = double.tryParse(_segmentLength.text.replaceAll(',', '.'));
      if (length == null || length <= 0) {
        _message('Masukkan Panjang Segmen Jalan lebih dari 0 meter.');
        return;
      }
      setState(() {
        _lockedSegmentLength = length;
        _recalculateRciScores();
      });
    }
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final item = CiAssessment(
      id: '${widget.type}-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}',
      type: widget.type,
      assessorName: _profile?.namaLengkap ?? '-',
      assessorNik: _profile?.noNik ?? '-',
      companyId: _companyId,
      location: _location.text.trim(),
      coordinate: _coordinate.text.trim(),
      assessedAt: DateTime.now(),
      shift: _shift,
      weather: _weather,
      areaOwner: _areaOwner.text.trim(),
      context: widget.type == 'FCI'
          ? 'Area utama: ${_mainArea.text.trim()}\n'
              'Detail lokasi/benchmark: ${_locationDetail.text.trim()}\n'
              'Pit/sektor: ${_pitSector.text.trim()}\n'
              'Front/loading point: ${_frontName.text.trim()}\n'
              'Benchmark/RL: ${_benchmark.text.trim()}\n'
              '${_context.text.trim()}'
          : widget.type == 'RCI'
              ? 'Nama jalan/jalur hauling: ${_roadName.text.trim()}\n'
                  'Segmen / STA / KM: ${_roadSegment.text.trim()}\n'
                  'Panjang segmen: ${_segmentLength.text.trim()} m\n'
                  'Tim sidak: ${_sidakTeam.text.trim()}\n'
                  'Approver: ${_approver.text.trim()}\n'
                  '${_context.text.trim()}'
              : widget.type == 'DCI'
                  ? 'Disposal: ${_disposalName.text.trim()}\n'
                      'Nama dump/pad: ${_dumpPad.text.trim()}\n'
                      '${_context.text.trim()}'
                  : widget.type == 'SPI'
                      ? 'Kolam sedimen: ${_pondName.text.trim()}\n'
                          'Titik penaatan lingkungan: ${_environmentPoint.text.trim()}\n'
                          '${_context.text.trim()}'
                      : _context.text.trim(),
      ruleVersion: _ruleVersion.text.trim(),
      answers: _answers,
      index: _index,
      band: _band,
      operationalStatus: _operationalStatus,
      criticalOverride: false,
      consequence: _consequence,
      likelihood: _likelihood,
      exposure: _exposure,
      priority: _priority,
      temporaryControls: _temporaryControls.text.trim(),
      action: _action.text.trim(),
      actionOwner: _actionOwner.text.trim(),
      dueDate: _dueDate,
      validUntil: _validUntil,
      evidencePaths: [..._evidence],
      status: _operationalStatus == 'READY / OPEN' ? 'Closed' : 'Open',
    );
    await CiStorage.save(item);
    await OfflineSyncService.instance.enqueue(
      feature: 'condition-index',
      localId: item.id,
      payload: item.toJson(),
    );
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => CiDetailPage(item)));
  }

  Future<void> _pickDate(bool validity) async {
    final current = validity ? _validUntil : _dueDate;
    final value = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (value != null) {
      setState(() => validity ? _validUntil = value : _dueDate = value);
    }
  }

  Future<void> _pickEvidence() async {
    if (_evidence.length >= 5) {
      _message('Maksimal 5 foto bukti.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Ambil Foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ])));
    if (source == null) return;
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final image = await picker.pickImage(
          source: source, imageQuality: 78, maxWidth: 1600);
      if (image != null) {
        final stored = await persistReportFile(File(image.path));
        setState(() => _evidence.add(stored.path));
      }
    } else {
      final images =
          await picker.pickMultiImage(imageQuality: 78, maxWidth: 1600);
      final stored = await Future.wait(images
          .take(5 - _evidence.length)
          .map((image) => persistReportFile(File(image.path))));
      setState(() => _evidence.addAll(stored.map((file) => file.path)));
    }
  }

  Future<void> _pickParameterEvidence(CiAnswer answer) async {
    if (answer.evidencePaths.length >= 3) {
      _message('Maksimal 3 foto untuk setiap parameter penilaian.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Ambil Foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ])));
    if (source == null) return;
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final image = await picker.pickImage(
          source: source, imageQuality: 78, maxWidth: 1600);
      if (image != null) {
        final stored = await persistReportFile(File(image.path));
        setState(() => answer.evidencePaths.add(stored.path));
      }
      return;
    }
    final images =
        await picker.pickMultiImage(imageQuality: 78, maxWidth: 1600);
    if (images.isEmpty) return;
    final remaining = 3 - answer.evidencePaths.length;
    final stored = await Future.wait(images
        .take(remaining)
        .map((image) => persistReportFile(File(image.path))));
    setState(
        () => answer.evidencePaths.addAll(stored.map((file) => file.path)));
    if (images.length > remaining && mounted) {
      _message('Foto dibatasi maksimal 3 untuk setiap parameter.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: TopBar(title: _typeName(widget.type), back: 2),
      body: Column(children: [
        _Progress(step: _step, steps: _steps),
        Expanded(
            child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: _buildStep()))),
      ]),
      bottomNavigationBar: SafeArea(
          child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
        child: Row(children: [
          if (_step > 0) ...[
            IconButton.filledTonal(
                onPressed: () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back_rounded)),
            const SizedBox(width: 10)
          ],
          Expanded(
              child: FilledButton.icon(
                  onPressed: _saving ? null : _next,
                  style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      minimumSize: const Size.fromHeight(50)),
                  icon: Icon(_step == _steps.length - 1
                      ? Icons.save_rounded
                      : Icons.arrow_forward_rounded),
                  label: Text(_saving
                      ? 'Menyimpan...'
                      : _step == _steps.length - 1
                          ? 'Simpan Assessment'
                          : 'Lanjut'))),
        ]),
      )),
    );
  }

  Widget _buildStep() => switch (_step) {
        0 => _contextStep(),
        1 => _assessmentStep(),
        2 => _actionStep(),
        _ => _reviewStep()
      };

  Widget _contextStep() {
    final hint = switch (widget.type) {
      'RCI' =>
        'Kelas jalan, ruas/segment, arah, STA awal–akhir, dan design vehicle',
      'DCI' =>
        'Nama disposal, lift/elevasi, area dumping, dan referensi geoteknik',
      _ => 'Nama loading front, fleet, material, bench, dan alat utama',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Lead(
          icon: Icons.pin_drop_rounded,
          title: 'Lokasi & Konteks ${_typeName(widget.type)}',
          subtitle: 'Data konteks menentukan standar teknis yang berlaku.'),
      _validationField(
          _companyKey,
          CompanyDropdown(
              initialCompanyId: _profile?.companyId,
              initialCompanyName: _profile?.company,
              onChanged: (v) => setState(() {
                    _companyId = v;
                    if (_invalidFieldKey == _companyKey) {
                      _invalidFieldKey = null;
                    }
                  }))),
      if (widget.type == 'RCI') ...[
        const SizedBox(height: 4),
        _label('Tim Sidak & Persetujuan'),
        _field(
            _sidakTeam, 'Nama tim sidak / rekan sidak', Icons.groups_rounded),
        _label('Disetujui Oleh (Approver) *'),
        _validationField(
            _approverKey,
            _field(_approver, 'Nama atau NIK atasan peninjau',
                Icons.verified_user_outlined,
                onChanged: (_) => _clearInvalid(_approverKey))),
      ],
      if (widget.type == 'FCI') ...[
        _label('Nama Front / Loading Point'),
        _field(_frontName, 'Contoh: Front OB Ex-01', Icons.landscape_outlined),
      ],
      if (widget.type == 'DCI') ...[
        _label('Disposal'),
        _field(_disposalName, 'Contoh: Disposal Utama, In-Pit',
            Icons.layers_rounded),
        _label('Nama Dump / Pad'),
        _field(
            _dumpPad, 'Contoh: Pad 2B, Dump RL 45', Icons.landscape_outlined),
      ],
      if (widget.type == 'SPI') ...[
        _label('Nama Kolam Sedimen'),
        _field(_pondName, 'Contoh: Settling Pond 01, Kolam KM 8',
            Icons.water_drop_outlined),
        _label('Titik Penaatan Lingkungan'),
        _field(_environmentPoint, 'Contoh: Point compliance A, Outfall SP-01',
            Icons.pin_drop_outlined),
      ],
      _label(widget.type == 'FCI' ? 'Lokasi / Area Inspeksi' : 'Lokasi / Area'),
      _validationField(
          _locationKey,
          _field(_location, 'Contoh: Pit 1 - North Block',
              Icons.location_on_outlined,
              onChanged: (_) => _clearInvalid(_locationKey))),
      if (widget.type == 'FCI') ...[
        _label('Area Utama'),
        _field(_mainArea, 'Contoh: Pit MGE', Icons.map_outlined),
        _label('Pit / Sektor'),
        _field(_pitSector, 'Contoh: Pit 1 / Tengah', Icons.layers_outlined),
        _label('Detail Lokasi / Benchmark'),
        _field(_locationDetail, 'Contoh: Pit MGE - Seam 37A',
            Icons.place_outlined),
        _label('Detail Benchmark / RL'),
        _field(
            _benchmark, 'Contoh: RL 50, BM-22, Seam B', Icons.explore_outlined),
      ],
      if (widget.type == 'RCI') ...[
        _label('Nama Jalan / Jalur Hauling'),
        _field(_roadName, 'Contoh: Jalan Anggrek, Jalan Sams',
            Icons.add_road_rounded),
        _label('Segment / STA / KM'),
        _field(_roadSegment, 'Contoh: STA 0+000 – 0+100, KM 2.5',
            Icons.route_rounded),
        _label('Panjang Segmen Jalan (Meter)'),
        TextField(
            controller: _segmentLength,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {
                  _lockedSegmentLength = null;
                  _recalculateRciScores();
                }),
            decoration: const InputDecoration(
                hintText: '100',
                suffixText: 'meter',
                prefixIcon: Icon(Icons.straighten_rounded))),
        const SizedBox(height: 14),
      ],
      _label('Koordinat GPS'),
      TextField(
          controller: _coordinate,
          readOnly: true,
          decoration: gpsInputDecoration(
                  context: context,
                  onPressed: () => fillGpsCoordinate(
                      context, _coordinate, () => setState(() {})),
                  iconColor: _cyan)
              .copyWith(hintText: 'Diambil otomatis dari perangkat')),
      const SizedBox(height: 14),
      _label('Pemilik Area / Departemen'),
      _validationField(
          _areaOwnerKey,
          _field(_areaOwner, 'Departemen yang bertanggung jawab',
              Icons.apartment_rounded,
              onChanged: (_) => _clearInvalid(_areaOwnerKey))),
      _label('Detail Konteks'),
      _validationField(
          _contextKey,
          TextField(
              controller: _context,
              maxLines: 4,
              onChanged: (_) => _clearInvalid(_contextKey),
              decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 62),
                      child: Icon(Icons.description_outlined))))),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            child: _dropdown(
                'Shift',
                _shift,
                const ['Day Shift', 'Night Shift'],
                (v) => setState(() => _shift = v!))),
        const SizedBox(width: 10),
        Expanded(
            child: _dropdown(
                'Cuaca',
                _weather,
                const ['Cerah', 'Berawan', 'Hujan', 'Kabut'],
                (v) => setState(() => _weather = v!)))
      ]),
    ]);
  }

  Widget _assessmentStep() {
    final groups = <String, List<CiParameter>>{};
    for (final item in _parameters) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }
    final done =
        _answers.where((e) => e.score != null || e.value == '__NA__').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Lead(
          icon: Icons.fact_check_rounded,
          title: 'Parameter Teknis',
          subtitle:
              '$done dari ${_parameters.length} parameter telah dinilai.'),
      LinearProgressIndicator(
          value: done / _parameters.length,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: _cyan,
          backgroundColor: const Color(0xFFDCE7EF)),
      const SizedBox(height: 14),
      if (widget.type == 'RCI') ...[
        _rciSegmentBanner(),
        const SizedBox(height: 14),
      ],
      ...groups.entries.map((group) => _parameterGroup(group.key, group.value)),
    ]);
  }

  Widget _rciSegmentBanner() => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF93C5FD))),
      child: Row(children: [
        const CircleAvatar(
            backgroundColor: Color(0xFFDCEBFF),
            child: Icon(Icons.straighten_rounded, color: Color(0xFF2563EB))),
        const SizedBox(width: 11),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Panjang Segmen Jalan (Meter)',
              style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 2),
          Text('Basis perhitungan tiap pilar (terkunci).',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey))
        ])),
        const SizedBox(width: 8),
        Text('${_formatMeter(_activeSegmentLength)} m',
            style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 17,
                fontWeight: FontWeight.w900))
      ]));

  Widget _parameterGroup(String title, List<CiParameter> params) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: Colors.white,
        child: ExpansionTile(
            controller: _groupControllers[title],
            initiallyExpanded: true,
            leading: const CircleAvatar(
                backgroundColor: Color(0xFFE6F6F6),
                child: Icon(Icons.engineering_rounded, color: _cyan)),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${params.length} parameter'),
            children: params.map(_parameterCard).toList()),
      );

  Widget _parameterCard(CiParameter item) {
    final answer = _answers.firstWhere((e) => e.parameterId == item.id);
    final options = widget.type == 'FCI'
        ? _fciOptions(item.id)
        : widget.type == 'DCI'
            ? _dciOptions(item.id)
            : widget.type == 'SPI'
                ? _spiOptions(item.id)
                : widget.type == 'RCI'
                    ? _rciOptions()
                    : <double?, String>{
                        5: 'Baik',
                        4: 'Diterima',
                        3: 'Menurun',
                        2: 'Buruk',
                        1: 'Kritis',
                        null: 'N/A'
                      };
    return Container(
      key: _parameterKeys[item.id],
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
          color: _attentionParameterId == item.id
              ? const Color(0xFFFFF1F2)
              : Colors.white,
          border: Border(
              top: const BorderSide(color: Color(0xFFE8EEF3)),
              left: BorderSide(
                  color: _attentionParameterId == item.id
                      ? const Color(0xFFDC2626)
                      : Colors.transparent,
                  width: 4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text('${item.id}  ${item.title}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, height: 1.3))),
          const SizedBox(width: 8),
          _tag('W${item.weight}', _navy),
          if (item.regulatory) ...[
            const SizedBox(width: 4),
            _tag('REG', const Color(0xFF7C3AED))
          ],
        ]),
        if (_attentionParameterId == item.id) ...[
          const SizedBox(height: 7),
          Row(children: [
            const Icon(Icons.error_outline_rounded,
                size: 16, color: Color(0xFFDC2626)),
            const SizedBox(width: 5),
            Text('Penilaian ini belum diisi',
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w800))
          ])
        ],
        const SizedBox(height: 10),
        if (widget.type == 'RCI') ...[
          TextFormField(
              controller: _rciDeficitControllers[item.id],
              readOnly: true,
              decoration: InputDecoration(
                  isDense: true,
                  labelText: _rciDeficitLabel(item.id),
                  hintText: '0',
                  suffixText: 'm')),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
                child: Text(_rciFormula(),
                    style:
                        const TextStyle(fontSize: 11, color: Colors.blueGrey))),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(7)),
                child: Text(_rciAchievement(answer.value),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700)))
          ]),
          const SizedBox(height: 10),
        ],
        Column(
            children: options.entries.map((entry) {
          final selected = answer.score == entry.key &&
              (entry.key != null || answer.value == '__NA__');
          return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: SizedBox(
                  width: double.infinity,
                  child: ChoiceChip(
                      label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(entry.key == null ? 'N/A' : entry.value,
                              style: const TextStyle(fontSize: 12))),
                      selected: selected,
                      selectedColor: const Color(0xFFD8F3F3),
                      side: BorderSide(
                          color: selected ? _cyan : const Color(0xFFD5DEE7)),
                      onSelected: (_) => setState(() {
                            if (widget.type == 'RCI') {
                              answer.score = entry.key;
                              answer.value = _rciDeficitForScore(entry.key);
                              _rciDeficitControllers[item.id]?.text =
                                  answer.value;
                              answer.unit = 'm';
                              if (_attentionParameterId == item.id) {
                                _attentionParameterId = null;
                              }
                              return;
                            }
                            answer.score = entry.key;
                            if (_attentionParameterId == item.id) {
                              _attentionParameterId = null;
                            }
                            if (entry.key == null) {
                              answer.value = '__NA__';
                            } else if (answer.value == '__NA__') {
                              answer.value = '';
                            }
                            answer.criticalFailure = false;
                          }))));
        }).toList()),
        if (answer.score != null) ...[
          const SizedBox(height: 10),
          TextFormField(
              initialValue: answer.note,
              onChanged: (v) => answer.note = v,
              decoration: const InputDecoration(
                  labelText: 'Catatan / temuan', isDense: true)),
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(
                child: Text('Foto pendukung (opsional)',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            Text('${answer.evidencePaths.length}/3',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            const SizedBox(width: 6),
            IconButton.filledTonal(
                tooltip: 'Tambah foto opsional',
                onPressed: () => _pickParameterEvidence(answer),
                icon: const Icon(Icons.add_a_photo_rounded, size: 19))
          ]),
          if (answer.evidencePaths.isNotEmpty)
            SizedBox(
                height: 76,
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: answer.evidencePaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 7),
                    itemBuilder: (_, index) => Stack(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                  File(answer.evidencePaths[index]),
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover)),
                          Positioned(
                              right: 2,
                              top: 2,
                              child: InkWell(
                                  onTap: () => setState(() =>
                                      answer.evidencePaths.removeAt(index)),
                                  child: const CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close,
                                          size: 13, color: Colors.white))))
                        ]))),
        ],
      ]),
    );
  }

  Map<double?, String> _fciOptions(String id) {
    const descriptions = <String, List<String>>{
      'F01': [
        'Rata & padat',
        'Bergelombang / undulasi',
        'Amblas / becek parah'
      ],
      'F02': [
        'Luas & double spotting',
        'Pas-pasan (single spotting)',
        'Sempit / bahaya senggolan'
      ],
      'F03': [
        '≥ 3/4 ban & kokoh',
        'Kurang tinggi (1/2 ban)',
        'Tidak ada tanggul / drop-off'
      ],
      'F04': [
        'Dinding aman & stabil',
        'Retak halus / menggantung',
        'Overhang / rawan longsor'
      ],
      'F05': [
        'Kering & lancar',
        'Ada genangan air',
        'Terendam air / sump penuh'
      ],
      'F06': [
        'Bersih rapi bebas boulder',
        'Ada ceceran batuan',
        'Boulder berserakan di lantai'
      ],
      'F07': [
        'Optimal jangkauan gali',
        'Agak tinggi / sudut terbatas',
        'Terlalu tinggi / undercut'
      ],
      'F08': [
        'Terang & rambu lengkap',
        'Kurang terang / kusam',
        'Gelap / tanpa rambu'
      ],
    };
    final labels = descriptions[id]!;
    return <double?, String>{
      5: '100 • ${labels[0]}',
      3.5: '70 • ${labels[1]}',
      2: '40 • ${labels[2]}',
    };
  }

  Map<double?, String> _dciOptions(String id) {
    const descriptions = <String, List<String>>{
      'D01': [
        'Rata, kering & padat kuat',
        'Bergelombang / lembek sedang',
        'Amblas parah / lumpur / becek'
      ],
      'D02': [
        '≥ 3/4 roda, padat & kokoh',
        '1/2 - 3/4 roda / agak tipis',
        '< 1/2 roda / tanggul putus'
      ],
      'D03': [
        'Stabil, rapat & bebas retakan',
        'Retak rambut / penurunan ringan',
        'Retak lebar / slump / longsor'
      ],
      'D04': [
        'Counter grade 2–3% sempurna',
        'Datar / kurang tanjakan',
        'Turun ke luar crest (bahaya)'
      ],
      'D05': [
        'Kering, air mengalir lancar',
        'Ada genangan lokal minor',
        'Tergenang air masif / saluran rusak'
      ],
      'D06': [
        'Bersih, dozer aktif merapikan',
        'Tumpukan belum rata / lambat dozer',
        'Menumpuk berantakan / jalur macet'
      ],
      'D07': [
        'Tower lamp terang & rambu lengkap',
        'Lampu kurang / rambu kusam',
        'Gelap total / tanpa rambu batas'
      ],
      'D08': [
        'Spotter standby, manuver tertib',
        'Spotter kurang fokus / manuver mepet',
        'Tanpa spotter / manuver semrawut'
      ],
    };
    final labels = descriptions[id]!;
    return <double?, String>{
      5: '100 • ${labels[0]}',
      3.5: '70 • ${labels[1]}',
      2: '40 • ${labels[2]}',
    };
  }

  Map<double?, String> _spiOptions(String id) {
    const descriptions = <String, List<String>>{
      'S01': [
        '< 50% kapasitas (luas & dalam)',
        '50% - 80% (perlu pengerukan)',
        '> 80% (dangkal / penuh lumpur)'
      ],
      'S02': [
        'Kokoh, stabil, bebas rembesan',
        'Erosi minor / retak rambut',
        'Rembesan air / slump / rawan jebol'
      ],
      'S03': [
        'Utuh, efektif memperlambat arus',
        'Sekat miring / kerusakan parsial',
        'Sekat jebol / hanyut / bypass arus'
      ],
      'S04': [
        'Bersih, lancar, struktur utuh',
        'Sumbatan ranting / sedimen ringan',
        'Tersumbat parah / struktur retak'
      ],
      'S05': [
        'Berfungsi aktif & stok cukup',
        'Dosing manual / stok menipis',
        'Dosing rusak / stok habis total'
      ],
      'S06': [
        'Jernih sesuai baku mutu lingkungan',
        'Agak keruh (perlu dosing tambahan)',
        'Keruh pekat / berlumpur meluap'
      ],
      'S07': [
        'V-Notch standar, skala terbaca jelas',
        'Skala agak kusam / sedimen di hulu',
        'Alat ukur rusak / tanpa titik pantau'
      ],
      'S08': [
        'Pagar, ringbuoy & rambu lengkap',
        'Rambu kusam / pagar rusak sebagian',
        'Tanpa pengaman / rawan tenggelam'
      ],
    };
    final labels = descriptions[id]!;
    return <double?, String>{
      5: '100 • ${labels[0]}',
      3.5: '70 • ${labels[1]}',
      2: '40 • ${labels[2]}',
    };
  }

  double get _activeSegmentLength =>
      _lockedSegmentLength ??
      double.tryParse(_segmentLength.text.replaceAll(',', '.')) ??
      100;

  Map<double?, String> _rciOptions() {
    return <double?, String>{
      4: '4.0 • 0% defisit',
      3.5: '3.5 • ≤10%',
      3: '3.0 • 11%–20%',
      2.5: '2.5 • 21%–50%',
      2: '2.0 • >50%',
    };
  }

  String _formatMeter(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

  String _rciDeficitForScore(double? score) {
    final multiplier = switch (score) {
      4 => 0.0,
      3.5 => .10,
      3 => .15,
      2.5 => .35,
      _ => .51,
    };
    return _formatMeter(_activeSegmentLength * multiplier);
  }

  double _rciScore(String value) {
    final deficit = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    final length = _activeSegmentLength;
    final percentage = length <= 0 ? 0 : deficit / length * 100;
    if (percentage == 0) return 4;
    if (percentage <= 10) return 3.5;
    if (percentage <= 20) return 3;
    if (percentage <= 50) return 2.5;
    return 2;
  }

  void _recalculateRciScores() {
    for (final answer in _answers) {
      if (answer.value.isNotEmpty && answer.value != '__NA__') {
        answer.score = _rciScore(answer.value);
      }
    }
  }

  String _rciFormula() {
    final length = _activeSegmentLength;
    final display = _formatMeter(length);
    return 'Formula: ($display - Defisit) / $display';
  }

  String _rciAchievement(String value) {
    final deficit = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    final length = _activeSegmentLength;
    final achievement = length <= 0
        ? 0.0
        : ((length - deficit) / length * 100).clamp(0, 100).toDouble();
    final deficitDisplay =
        deficit.toStringAsFixed(deficit == deficit.roundToDouble() ? 0 : 1);
    return 'Ketercapaian: ${achievement.toStringAsFixed(1)}% (Defisit: $deficitDisplay m)';
  }

  String _rciDeficitLabel(String id) => switch (id) {
        'R01' => 'Defisit kerusakan surfacing',
        'R02' => 'Defisit kerusakan undulasi',
        'R03' => 'Defisit spoil / penyempitan',
        'R04' => 'Defisit tanggul kurang dari 3/4 ban',
        'R05' => 'Defisit rambu rusak / tanpa delineator',
        'R06' => 'Defisit segmen berdebu',
        'R07' => 'Defisit crossfall tidak terbentuk',
        _ => 'Defisit parit tidak terbentuk / genangan',
      };

  Widget _actionStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Lead(
            icon: Icons.assignment_turned_in_rounded,
            title: widget.type == 'FCI' ||
                    widget.type == 'RCI' ||
                    widget.type == 'DCI' ||
                    widget.type == 'SPI'
                ? 'Foto Dokumentasi & Tindakan'
                : 'Kontrol & Action',
            subtitle: widget.type == 'FCI' ||
                    widget.type == 'RCI' ||
                    widget.type == 'DCI' ||
                    widget.type == 'SPI'
                ? 'Catat kondisi aktual, tentukan rekomendasi dan PIC perbaikan.'
                : 'Tetapkan perlindungan sementara, PIC, target, dan masa berlaku keputusan.'),
        _label(widget.type == 'FCI' ||
                widget.type == 'RCI' ||
                widget.type == 'DCI' ||
                widget.type == 'SPI'
            ? 'Catatan Observasi Kondisi ${widget.type == 'FCI' ? 'Front' : widget.type == 'RCI' ? 'Jalan' : widget.type == 'DCI' ? 'Disposal' : 'Kolam Sedimen'}'
            : 'Kontrol Sementara'),
        _validationField(
            _observationKey,
            _area(
                _temporaryControls,
                widget.type == 'FCI' ||
                        widget.type == 'RCI' ||
                        widget.type == 'DCI' ||
                        widget.type == 'SPI'
                    ? 'Tuliskan temuan atau catatan kondisi aktual di ${widget.type == 'FCI' ? 'front' : widget.type == 'RCI' ? 'jalan' : widget.type == 'DCI' ? 'area disposal' : 'kolam sedimen'}...'
                    : 'Contoh: Tutup jalur, pasang barricade, grader dan water truck standby',
                onChanged: (_) => _clearInvalid(_observationKey))),
        _label(widget.type == 'FCI' ||
                widget.type == 'RCI' ||
                widget.type == 'DCI' ||
                widget.type == 'SPI'
            ? 'Rekomendasi Tindakan Perbaikan'
            : 'Corrective Action'),
        _validationField(
            _actionKey,
            _area(
                _action,
                widget.type == 'FCI' ||
                        widget.type == 'RCI' ||
                        widget.type == 'DCI' ||
                        widget.type == 'SPI'
                    ? widget.type == 'FCI'
                        ? 'Contoh: Perlu dozer merapikan lantai dan meninggikan tanggul crest...'
                        : widget.type == 'RCI'
                            ? 'Contoh: Perlu motor grader meratakan jalan dan compactor memadatkan...'
                            : widget.type == 'DCI'
                                ? 'Contoh: Perlu dozer merapikan lantai dump dan memperbaiki tanggul...'
                                : 'Contoh: Lakukan pengerukan sedimen, perbaikan tanggul, atau dosing...'
                    : 'Uraikan tindakan permanen dan kriteria penyelesaiannya',
                onChanged: (_) => _clearInvalid(_actionKey))),
        _label(widget.type == 'FCI' ||
                widget.type == 'RCI' ||
                widget.type == 'DCI' ||
                widget.type == 'SPI'
            ? 'PIC Tindakan Perbaikan'
            : 'PIC / Action Owner'),
        _validationField(
            _actionOwnerKey,
            _field(
                _actionOwner,
                widget.type == 'FCI' ||
                        widget.type == 'RCI' ||
                        widget.type == 'DCI' ||
                        widget.type == 'SPI'
                    ? widget.type == 'FCI'
                        ? 'Contoh: Pengawas Pit / Foreman Dozer'
                        : widget.type == 'RCI'
                            ? 'Contoh: Road Maintenance / Foreman Grader'
                            : widget.type == 'DCI'
                                ? 'Contoh: SPV Pit / GL Dozer'
                                : 'Contoh: SPV Environment / Water Treatment'
                    : 'Nama atau departemen penanggung jawab',
                Icons.person_outline_rounded,
                onChanged: (_) => _clearInvalid(_actionOwnerKey))),
        if (widget.type != 'FCI' &&
            widget.type != 'RCI' &&
            widget.type != 'DCI' &&
            widget.type != 'SPI') ...[
          Row(children: [
            Expanded(
                child: _dateTile(
                    'Target Selesai', _dueDate, () => _pickDate(false))),
            const SizedBox(width: 10),
            Expanded(
                child: _dateTile(
                    'Berlaku Sampai', _validUntil, () => _pickDate(true)))
          ]),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(
              child: Text(
                  widget.type == 'FCI'
                      ? 'Foto Kondisi Front'
                      : widget.type == 'RCI'
                          ? 'Foto Kondisi Jalan'
                          : widget.type == 'DCI'
                              ? 'Foto Kondisi Disposal'
                              : widget.type == 'SPI'
                                  ? 'Foto Kondisi Kolam Sedimen'
                                  : 'Bukti Foto',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800))),
          Text('${_evidence.length}/5',
              style:
                  const TextStyle(color: _cyan, fontWeight: FontWeight.w800)),
          IconButton.filledTonal(
              onPressed: _pickEvidence,
              icon: const Icon(Icons.add_a_photo_rounded))
        ]),
        if (_evidence.isNotEmpty)
          SizedBox(
              height: 92,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _evidence.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(_evidence[i]),
                                width: 92, height: 92, fit: BoxFit.cover)),
                        Positioned(
                            right: 2,
                            top: 2,
                            child: InkWell(
                                onTap: () =>
                                    setState(() => _evidence.removeAt(i)),
                                child: const CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.white))))
                      ]))),
      ]);

  Widget _reviewStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Lead(
            icon: Icons.task_alt_rounded,
            title: 'Review & Simpan',
            subtitle:
                'Periksa kembali hasil sebelum disimpan sebagai rekaman asesmen.'),
        _resultBanner(),
        const SizedBox(height: 14),
        _review('Assessment', _typeName(widget.type)),
        _review('Lokasi', '${_location.text}\n${_coordinate.text}'),
        _review('Pemilik Area', _areaOwner.text),
        _review('Konteks', _context.text),
        _review('Kontrol Sementara', _temporaryControls.text),
        _review('Action / PIC', '${_action.text}\nPIC: ${_actionOwner.text}'),
        _review('Target / Validitas',
            '${DateFormat('dd MMM yyyy').format(_dueDate)} / ${DateFormat('dd MMM yyyy').format(_validUntil)}'),
      ]);

  Widget _resultBanner() {
    final color = _index < 50
        ? const Color(0xFFDC2626)
        : _index < 80
            ? const Color(0xFFF59E0B)
            : const Color(0xFF059669);
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: .35))),
        child: Row(children: [
          SizedBox(
              width: 72,
              height: 72,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                    value: _index / 100,
                    strokeWidth: 8,
                    color: color,
                    backgroundColor: color.withValues(alpha: .15)),
                Text(_index.toStringAsFixed(0),
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: color))
              ])),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_band,
                    style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                Text(_operationalStatus,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ]))
        ]));
  }

  Widget _dateTile(String title, DateTime date, VoidCallback tap) => InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD5DEE7))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            const SizedBox(height: 5),
            Row(children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: _cyan),
              const SizedBox(width: 6),
              Text(DateFormat('dd MMM yy').format(date),
                  style: const TextStyle(fontWeight: FontWeight.w700))
            ])
          ])));
  Widget _review(String label, String value) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        const SizedBox(height: 3),
        Text(value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35))
      ]));
}

String _typeName(String type) => switch (type) {
      'RCI' => 'Road Condition Index',
      'DCI' => 'Disposal Condition Index',
      'SPI' => 'Sediment Pond Index',
      _ => 'Front Condition Index'
    };

Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(6)),
    child: Text(text,
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)));
Widget _field(TextEditingController c, String hint, IconData icon,
        {ValueChanged<String>? onChanged}) =>
    Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
            controller: c,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onChanged,
            decoration:
                InputDecoration(hintText: hint, prefixIcon: Icon(icon))));
Widget _area(TextEditingController c, String hint,
        {ValueChanged<String>? onChanged}) =>
    Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
            controller: c,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: hint)));
Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF26384A))));
Widget _dropdown(String label, String value, List<String> items,
        ValueChanged<String?> changed) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: changed)
    ]);

class _Lead extends StatelessWidget {
  const _Lead(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xFFE0F2FE),
            child: Icon(icon, color: _navy)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033))),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(color: Colors.blueGrey, height: 1.35))
        ]))
      ]));
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.steps});
  final int step;
  final List<String> steps;
  @override
  Widget build(BuildContext context) => Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(children: [
        Row(children: [
          Text('${step + 1}/${steps.length}',
              style:
                  const TextStyle(color: _cyan, fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(steps[step],
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('${((step + 1) / steps.length * 100).round()}%',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey))
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: (step + 1) / steps.length,
            minHeight: 5,
            borderRadius: BorderRadius.circular(5),
            color: _cyan,
            backgroundColor: const Color(0xFFE2E8F0))
      ]));
}
