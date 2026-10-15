import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/preference.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'bbs_model.dart';
import 'bbs_page.dart';

const _blue = Color(0xFF075985);
const _green = Color(0xFF059669);
const _background = Color(0xFFF4F7FB);

class BbsFormPage extends StatefulWidget {
  const BbsFormPage({super.key});

  @override
  State<BbsFormPage> createState() => _BbsFormPageState();
}

class _BbsFormPageState extends State<BbsFormPage> {
  static const _stepTitles = [
    'Informasi Observasi',
    'Perilaku yang Diamati',
    'Klasifikasi & Konteks',
    'Risiko, Tindakan & Coaching',
    'Review & Simpan',
  ];

  static const Map<String, List<String>> _behaviorCatalog = {
    'Mengemudi & Hauling': [
      'Kecepatan kendaraan sesuai ketentuan',
      'Menjaga jarak aman',
      'Tidak menggunakan HP saat mengemudi',
      'Menggunakan sabuk keselamatan',
      'Mematuhi rambu dan jalur',
      'Melakukan komunikasi radio sesuai prosedur',
      'Melakukan pemeriksaan blind spot',
      'Parkir dan berhenti di area aman',
    ],
    'Interaksi Alat & Manusia': [
      'Menjaga jarak aman dari alat bergerak',
      'Melakukan positive communication',
      'Berada di luar blind spot operator',
      'Menggunakan jalur pedestrian',
      'Memastikan izin sebelum mendekati unit',
      'Menggunakan spotter saat diperlukan',
      'Tidak melintas di bawah attachment',
    ],
    'Area Loading & Dumping': [
      'Posisi unit stabil dan aman',
      'Jarak antarunit sesuai ketentuan',
      'Tidak keluar kabin tanpa izin',
      'Mengikuti arahan spotter',
      'Area dumping memiliki bundwall aman',
      'Tidak melakukan manuver berisiko',
    ],
    'Perawatan & Maintenance': [
      'Melakukan isolasi energi dan LOTO',
      'Menggunakan alat kerja sesuai fungsi',
      'Menempatkan wheel chock atau safety support',
      'Menjaga area kerja tetap rapi',
      'Menggunakan APD sesuai risiko',
      'Memastikan unit bebas tekanan tersimpan',
      'Mengikuti job safety analysis',
      'Melakukan test run secara aman',
    ],
    'Pekerjaan Berisiko Khusus': [
      'Izin kerja tersedia dan masih berlaku',
      'Bekerja di ketinggian dengan fall protection',
      'Gas test dilakukan sebelum pekerjaan',
      'Standby person tersedia',
      'Area kerja dipasang barricade',
      'Peralatan lifting telah diperiksa',
      'Komunikasi rigger dan operator efektif',
      'Hot work diawasi fire watch',
    ],
    'Faktor Manusia': [
      'Pekerja dalam kondisi fit to work',
      'Tidak menunjukkan tanda kelelahan',
      'Fokus pada pekerjaan',
      'Tidak terburu-buru mengejar target',
      'Berani melakukan stop work',
      'Memahami instruksi kerja',
      'Berkomunikasi secara jelas',
      'Tidak mengambil jalan pintas',
    ],
    'Kepatuhan Prosedur': [
      'Prosedur/JSA tersedia di lokasi',
      'Langkah kerja diikuti berurutan',
      'Permit telah diverifikasi',
      'Pemeriksaan awal telah dilakukan',
      'Perubahan kondisi telah dinilai ulang',
      'Housekeeping sesuai standar',
    ],
    'Kepemimpinan & Intervensi': [
      'Atasan memberi contoh perilaku aman',
      'Bahaya dibahas sebelum pekerjaan',
      'Intervensi dilakukan dengan positif',
      'Masukan pekerja didengarkan',
      'Tindak lanjut disepakati bersama',
    ],
  };

  final _profile = PreferenceService.getProfile();
  final _location = TextEditingController();
  final _coordinate = TextEditingController();
  final _department = TextEditingController();
  final _observedPerson = TextEditingController();
  final _observedPosition = TextEditingController();
  final _otherBehavior = TextEditingController();
  final _potentialConsequence = TextEditingController();
  final _coachingNotes = TextEditingController();
  final _commitment = TextEditingController();
  final _otherAction = TextEditingController();

  int _step = 0;
  int? _companyId;
  String _observationType = 'Observasi Rutin';
  DateTime _observedAt = DateTime.now();
  String? _category;
  final Set<String> _behaviors = {};
  String _classification = 'Perilaku Aman';
  String _roadCondition = 'Normal / Kering';
  String _weatherCondition = 'Cerah';
  String _trafficCondition = 'Rendah';
  final Set<String> _triggerFactors = {};
  String _riskLevel = 'Rendah';
  final Set<String> _immediateActions = {};
  String _workerResponse = 'Positif';
  DateTime? _dueDate;
  final List<String> _evidencePaths = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fillGpsCoordinate(
        context,
        _coordinate,
        () => setState(() {}),
        silent: true,
      );
    });
  }

  @override
  void dispose() {
    _location.dispose();
    _coordinate.dispose();
    _department.dispose();
    _observedPerson.dispose();
    _observedPosition.dispose();
    _otherBehavior.dispose();
    _potentialConsequence.dispose();
    _coachingNotes.dispose();
    _commitment.dispose();
    _otherAction.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _validateStep() {
    if (_step == 0 &&
        (_companyId == null ||
            _location.text.trim().isEmpty ||
            _department.text.trim().isEmpty ||
            _observedPerson.text.trim().isEmpty)) {
      _message(
          'Lengkapi perusahaan, lokasi, departemen, dan pekerja yang diamati.');
      return false;
    }
    if (_step == 1 && (_category == null || _behaviors.isEmpty)) {
      _message('Pilih kategori dan minimal satu perilaku yang diamati.');
      return false;
    }
    if (_step == 3 &&
        (_potentialConsequence.text.trim().isEmpty ||
            _immediateActions.isEmpty ||
            _coachingNotes.text.trim().isEmpty ||
            _commitment.text.trim().isEmpty)) {
      _message('Lengkapi risiko, tindakan, catatan coaching, dan komitmen.');
      return false;
    }
    return true;
  }

  Future<void> _next() async {
    if (!_validateStep()) return;
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final behaviors = [..._behaviors];
    if (_otherBehavior.text.trim().isNotEmpty) {
      behaviors.add(_otherBehavior.text.trim());
    }
    final actions = [..._immediateActions];
    if (_otherAction.text.trim().isNotEmpty) {
      actions.add(_otherAction.text.trim());
    }
    final requiresFollowUp = _classification == 'Perilaku Berisiko' ||
        _riskLevel == 'Tinggi' ||
        _riskLevel == 'Sangat Tinggi';
    final observation = BbsObservation(
      id: 'BBS-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}',
      observerName: _profile?.namaLengkap ?? '-',
      observerNik: _profile?.noNik ?? '-',
      observationType: _observationType,
      companyId: _companyId,
      location: _coordinate.text.trim().isEmpty
          ? _location.text.trim()
          : '${_location.text.trim()} • ${_coordinate.text.trim()}',
      department: _department.text.trim(),
      observedPerson: _observedPerson.text.trim(),
      observedPosition: _observedPosition.text.trim(),
      observedAt: _observedAt,
      category: _category!,
      behaviors: behaviors,
      classification: _classification,
      roadCondition: _roadCondition,
      weatherCondition: _weatherCondition,
      trafficCondition: _trafficCondition,
      triggerFactors: [..._triggerFactors],
      riskLevel: _riskLevel,
      potentialConsequence: _potentialConsequence.text.trim(),
      immediateActions: actions,
      workerResponse: _workerResponse,
      coachingNotes: _coachingNotes.text.trim(),
      commitment: _commitment.text.trim(),
      dueDate: _dueDate,
      evidencePaths: [..._evidencePaths],
      status: requiresFollowUp ? 'Open' : 'Closed',
      followUpNotes: '',
    );
    await BbsStorage.save(observation);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BbsDetailPage(observation)),
    );
  }

  Future<void> _pickObservedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _observedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_observedAt),
    );
    if (time == null) return;
    setState(() {
      _observedAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _pickEvidence() async {
    if (_evidencePaths.length >= 5) {
      _message('Maksimal 5 foto untuk setiap observasi BBS.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final remaining = 5 - _evidencePaths.length;
    if (source == ImageSource.camera) {
      final image = await picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (image != null) setState(() => _evidencePaths.add(image.path));
      return;
    }
    final images = await picker.pickMultiImage(
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (images.isEmpty) return;
    final selected = images.take(remaining).map((image) => image.path);
    setState(() => _evidencePaths.addAll(selected));
    if (images.length > remaining && mounted) {
      _message(
          'Hanya $remaining foto yang ditambahkan. Batas maksimal 5 foto.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: const TopBar(title: 'Buat Observasi BBS', back: 2),
      body: Column(
        children: [
          _ProgressHeader(step: _step, titles: _stepTitles),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: _buildStep(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _next,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: Icon(
              _step == _stepTitles.length - 1
                  ? Icons.save_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(
              _saving
                  ? 'Menyimpan...'
                  : _step == _stepTitles.length - 1
                      ? 'Simpan Observasi'
                      : 'Lanjut',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _informationStep(),
      1 => _behaviorStep(),
      2 => _classificationStep(),
      3 => _actionStep(),
      _ => _reviewStep(),
    };
  }

  Widget _informationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLead(
          icon: Icons.assignment_outlined,
          title: 'Jenis & Lokasi Observasi',
          subtitle: 'Catat konteks observasi secara lengkap dan objektif.',
        ),
        const _FieldLabel('Jenis Observasi'),
        Row(
          children: [
            Expanded(
              child: _SelectCard(
                title: 'Observasi Rutin',
                subtitle: 'Aktivitas sehari-hari',
                icon: Icons.visibility_outlined,
                selected: _observationType == 'Observasi Rutin',
                onTap: () =>
                    setState(() => _observationType = 'Observasi Rutin'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SelectCard(
                title: 'Special Case',
                subtitle: 'Risiko tinggi/spesifik',
                icon: Icons.crisis_alert_rounded,
                selected: _observationType == 'Special Case',
                onTap: () => setState(() => _observationType = 'Special Case'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CompanyDropdown(
          initialCompanyId: _profile?.companyId,
          initialCompanyName: _profile?.company,
          onChanged: (value) => setState(() => _companyId = value),
        ),
        const _FieldLabel('Lokasi / Area Kerja'),
        TextField(
          controller: _location,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Contoh: Pit 1, Workshop, Jetty',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Koordinat GPS'),
        TextField(
          controller: _coordinate,
          readOnly: true,
          decoration: gpsInputDecoration(
            context: context,
            onPressed: () => fillGpsCoordinate(
              context,
              _coordinate,
              () => setState(() {}),
            ),
            iconColor: _blue,
          ).copyWith(hintText: 'Diambil otomatis dari perangkat'),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Unit / Departemen'),
        TextField(
          controller: _department,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Contoh: Produksi - Hauling',
            prefixIcon: Icon(Icons.apartment_rounded),
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Pekerja yang Diamati'),
        TextField(
          controller: _observedPerson,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Nama pekerja / identitas unit',
            prefixIcon: Icon(Icons.person_search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Jabatan / Peran (opsional)'),
        TextField(
          controller: _observedPosition,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Contoh: Driver DT, Mekanik',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Tanggal & Waktu'),
        _ReadOnlyField(
          icon: Icons.calendar_month_rounded,
          value: DateFormat('dd MMMM yyyy, HH:mm').format(_observedAt),
          onTap: _pickObservedAt,
        ),
      ],
    );
  }

  Widget _behaviorStep() {
    final behaviors = _category == null
        ? const <String>[]
        : _behaviorCatalog[_category!] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLead(
          icon: Icons.rule_folder_outlined,
          title: 'Pilih Kategori Perilaku',
          subtitle:
              'Pilih kategori lalu tandai seluruh perilaku yang terlihat.',
        ),
        ..._behaviorCatalog.keys.map(
          (category) => _CategoryTile(
            title: category,
            count: _behaviorCatalog[category]!.length,
            selected: _category == category,
            icon: _categoryIcon(category),
            onTap: () => setState(() {
              _category = category;
              _behaviors.clear();
            }),
          ),
        ),
        if (_category != null) ...[
          const SizedBox(height: 18),
          _SectionLead(
            icon: Icons.checklist_rounded,
            title: _category!,
            subtitle: 'Anda dapat memilih lebih dari satu perilaku.',
          ),
          ...behaviors.map(
            (behavior) => CheckboxListTile(
              value: _behaviors.contains(behavior),
              onChanged: (selected) => setState(() {
                if (selected == true) {
                  _behaviors.add(behavior);
                } else {
                  _behaviors.remove(behavior);
                }
              }),
              title: Text(behavior, style: const TextStyle(fontSize: 13)),
              activeColor: _blue,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otherBehavior,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Perilaku lain (opsional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _classificationStep() {
    const triggers = [
      'Terburu-buru / mengejar target',
      'Kebiasaan',
      'Kurang pengetahuan',
      'Kurang kesadaran',
      'Kelelahan',
      'Peralatan / fasilitas tidak memadai',
      'Pengawasan kurang',
      'Tekanan pekerjaan',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLead(
          icon: Icons.psychology_alt_outlined,
          title: 'Klasifikasi & Konteks',
          subtitle: 'Nilai perilaku berdasarkan apa yang benar-benar diamati.',
        ),
        Row(
          children: [
            Expanded(
              child: _SelectCard(
                title: 'Perilaku Aman',
                subtitle: 'Safe behavior',
                icon: Icons.thumb_up_alt_rounded,
                selected: _classification == 'Perilaku Aman',
                selectedColor: _green,
                onTap: () => setState(() => _classification = 'Perilaku Aman'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SelectCard(
                title: 'Perilaku Berisiko',
                subtitle: 'At-risk behavior',
                icon: Icons.thumb_down_alt_rounded,
                selected: _classification == 'Perilaku Berisiko',
                selectedColor: const Color(0xFFDC2626),
                onTap: () =>
                    setState(() => _classification = 'Perilaku Berisiko'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Kondisi Jalan / Area'),
        _Dropdown(
          value: _roadCondition,
          items: const [
            'Normal / Kering',
            'Basah / Licin',
            'Berlumpur',
            'Berdebu',
            'Rusak / Tidak Rata',
            'Tidak Relevan'
          ],
          onChanged: (value) => setState(() => _roadCondition = value),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Kondisi Cuaca'),
        _Dropdown(
          value: _weatherCondition,
          items: const [
            'Cerah',
            'Mendung',
            'Hujan Ringan',
            'Hujan Lebat',
            'Kabut',
            'Malam Hari'
          ],
          onChanged: (value) => setState(() => _weatherCondition = value),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Kepadatan Aktivitas / Traffic'),
        _Dropdown(
          value: _trafficCondition,
          items: const ['Rendah', 'Sedang', 'Tinggi', 'Tidak Relevan'],
          onChanged: (value) => setState(() => _trafficCondition = value),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Faktor Pemicu / Penyebab'),
        const Text(
          'Pilih satu atau lebih faktor yang paling berpengaruh.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: triggers
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: FilterChip(
                    label: Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(item, style: const TextStyle(fontSize: 11))),
                    selected: _triggerFactors.contains(item),
                    selectedColor: const Color(0xFFDDF2FF),
                    checkmarkColor: _blue,
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _triggerFactors.add(item);
                      } else {
                        _triggerFactors.remove(item);
                      }
                    }),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _actionStep() {
    const actions = [
      'Menghentikan aktivitas / unit',
      'Memberikan teguran lisan',
      'Melakukan coaching di lokasi',
      'Memperbaiki kondisi / alat',
      'Melaporkan kepada atasan',
      'Memberikan apresiasi perilaku aman',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLead(
          icon: Icons.health_and_safety_outlined,
          title: 'Risiko, Tindakan & Coaching',
          subtitle:
              'Tentukan dampak dan catat dialog perbaikan bersama pekerja.',
        ),
        const _FieldLabel('Level Risiko / Dampak Potensial'),
        ...[
          ('Sangat Tinggi', 'Fatality / cidera berat', const Color(0xFFDC2626)),
          (
            'Tinggi',
            'Cidera sedang / kerusakan besar',
            const Color(0xFFF97316)
          ),
          ('Sedang', 'Cidera ringan / kerusakan alat', const Color(0xFFEAB308)),
          ('Rendah', 'Hampir tidak ada dampak', _green),
        ].map(
          (item) => _RiskOption(
            title: item.$1,
            subtitle: item.$2,
            color: item.$3,
            selected: _riskLevel == item.$1,
            onTap: () => setState(() => _riskLevel = item.$1),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _potentialConsequence,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Jelaskan risiko / konsekuensi potensial',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        const _FieldLabel('Tindakan Langsung'),
        ...actions.map(
          (action) => CheckboxListTile(
            value: _immediateActions.contains(action),
            onChanged: (selected) => setState(() {
              if (selected == true) {
                _immediateActions.add(action);
              } else {
                _immediateActions.remove(action);
              }
            }),
            title: Text(action, style: const TextStyle(fontSize: 13)),
            activeColor: _blue,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        TextField(
          controller: _otherAction,
          decoration:
              const InputDecoration(labelText: 'Tindakan lain (opsional)'),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Respons Pekerja'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'Positif',
                label: Text('Positif'),
                icon: Icon(Icons.sentiment_satisfied_alt_rounded)),
            ButtonSegment(
                value: 'Netral',
                label: Text('Netral'),
                icon: Icon(Icons.sentiment_neutral_rounded)),
            ButtonSegment(
                value: 'Resisten',
                label: Text('Resisten'),
                icon: Icon(Icons.sentiment_dissatisfied_rounded)),
          ],
          selected: {_workerResponse},
          onSelectionChanged: (value) =>
              setState(() => _workerResponse = value.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _coachingNotes,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Catatan coaching',
            hintText:
                'Tuliskan percakapan, pemahaman pekerja, dan pesan keselamatan.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commitment,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Komitmen / tindakan perbaikan',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Target Follow Up (opsional)'),
        _ReadOnlyField(
          icon: Icons.event_available_rounded,
          value: _dueDate == null
              ? 'Pilih tanggal target'
              : DateFormat('dd MMMM yyyy').format(_dueDate!),
          onTap: _pickDueDate,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: _FieldLabel('Bukti Foto (opsional)')),
            Text(
              '${_evidencePaths.length}/5 foto',
              style: const TextStyle(
                color: _blue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount:
              _evidencePaths.length + (_evidencePaths.length < 5 ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _evidencePaths.length) {
              return Material(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _pickEvidence,
                  borderRadius: BorderRadius.circular(14),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, color: _blue),
                      SizedBox(height: 6),
                      Text(
                        'Tambah Foto',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final path = _evidencePaths[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(path), fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filled(
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: .65),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        setState(() => _evidencePaths.removeAt(index)),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final selectedBehaviors = [..._behaviors];
    if (_otherBehavior.text.trim().isNotEmpty) {
      selectedBehaviors.add(_otherBehavior.text.trim());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _green, size: 34),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Siap Disimpan',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('Periksa kembali data sebelum menyimpan observasi.',
                        style:
                            TextStyle(color: Color(0xFF047857), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ReviewCard(
          title: 'Ringkasan Observasi',
          items: {
            'Jenis': _observationType,
            'Lokasi': _location.text.trim(),
            'Departemen': _department.text.trim(),
            'Pekerja': _observedPerson.text.trim(),
            'Waktu': DateFormat('dd MMM yyyy, HH:mm').format(_observedAt),
          },
        ),
        _ReviewCard(
          title: 'Perilaku & Risiko',
          items: {
            'Kategori': _category ?? '-',
            'Perilaku': selectedBehaviors.join(', '),
            'Klasifikasi': _classification,
            'Risiko': _riskLevel,
            'Pemicu':
                _triggerFactors.isEmpty ? '-' : _triggerFactors.join(', '),
          },
        ),
        _ReviewCard(
          title: 'Tindakan & Komitmen',
          items: {
            'Tindakan': _immediateActions.join(', '),
            'Respons': _workerResponse,
            'Coaching': _coachingNotes.text.trim(),
            'Komitmen': _commitment.text.trim(),
            'Target': _dueDate == null
                ? '-'
                : DateFormat('dd MMM yyyy').format(_dueDate!),
            'Bukti Foto': '${_evidencePaths.length} foto',
          },
        ),
      ],
    );
  }

  IconData _categoryIcon(String category) => switch (category) {
        'Mengemudi & Hauling' => Icons.local_shipping_rounded,
        'Interaksi Alat & Manusia' => Icons.engineering_rounded,
        'Area Loading & Dumping' => Icons.landscape_rounded,
        'Perawatan & Maintenance' => Icons.build_rounded,
        'Pekerjaan Berisiko Khusus' => Icons.settings_suggest_rounded,
        'Faktor Manusia' => Icons.psychology_rounded,
        'Kepatuhan Prosedur' => Icons.assignment_turned_in_rounded,
        _ => Icons.groups_rounded,
      };
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Langkah ${step + 1} dari ${titles.length}',
                style: const TextStyle(
                    color: _blue, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text('${((step + 1) / titles.length * 100).round()}%',
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (step + 1) / titles.length,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              color: _blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(titles[step],
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }
}

class _SectionLead extends StatelessWidget {
  const _SectionLead(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF667085), fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.selectedColor = _blue,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor.withValues(alpha: .08) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? selectedColor : const Color(0xFFE2E8F0),
                width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? selectedColor : Colors.blueGrey, size: 28),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 3),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(
      {required this.title,
      required this.count,
      required this.selected,
      required this.icon,
      required this.onTap});

  final String title;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFE0F2FE) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border:
                  Border.all(color: selected ? _blue : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF1D6),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: const Color(0xFFB45309), size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('$count item perilaku',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 10)),
                    ],
                  ),
                ),
                Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: selected ? _blue : Colors.blueGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown(
      {required this.value, required this.items, required this.onChanged});

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) => onChanged(value!),
    );
  }
}

class _RiskOption extends StatelessWidget {
  const _RiskOption({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? color.withValues(alpha: .08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : const Color(0xFFE2E8F0),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField(
      {required this.icon, required this.value, required this.onTap});

  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.shade200)),
          child: Row(
            children: [
              Icon(icon, color: _blue),
              const SizedBox(width: 12),
              Expanded(child: Text(value)),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.items});

  final String title;
  final Map<String, String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Divider(height: 24),
          ...items.entries.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 90,
                      child: Text(item.key,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 11))),
                  Expanded(
                      child: Text(item.value.isEmpty ? '-' : item.value,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 11))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
