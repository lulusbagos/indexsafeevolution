import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/database.dart';
import '../../services/preference.dart';
import '../../widgets/top_bar.dart';

class AchievementSapPage extends StatelessWidget {
  const AchievementSapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MockScaffold(
      title: 'Pencapaian SAP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroMetricCard(
            title: 'Pencapaian Individual',
            value: '112%',
            subtitle: 'Aktual 28 dari target 25 SAP bulan ini',
            color: Color(0xFF2563EB),
            icon: Icons.track_changes_rounded,
          ),
          SizedBox(height: 14),
          _SectionTitle('Aktual vs Target'),
          _ProgressMetric(label: 'Hazard Report', actual: 9, target: 8),
          _ProgressMetric(label: 'Observation', actual: 7, target: 6),
          _ProgressMetric(label: 'Safety Talk', actual: 5, target: 5),
          _ProgressMetric(label: 'Coaching', actual: 4, target: 3),
          _ProgressMetric(label: 'Inspection', actual: 3, target: 3),
          SizedBox(height: 18),
          _SectionTitle('Departemen'),
          _DepartmentCard(
              name: 'Digital Product Development', score: '104%', rank: '#2'),
          _DepartmentCard(name: 'Operation', score: '97%', rank: '#5'),
          _DepartmentCard(name: 'Plant', score: '91%', rank: '#7'),
        ],
      ),
    );
  }
}

class SapLeaguePage extends StatelessWidget {
  const SapLeaguePage({super.key});

  static const _rows = [
    ('1', 'A. Pratama', 'Operation', '1,240', '+12%'),
    ('2', 'Muhammad Alfian', 'DPD', '1,180', '+9%'),
    ('3', 'R. Wijaya', 'Plant', '1,095', '+7%'),
    ('4', 'D. Saputra', 'HSE', '1,040', '+5%'),
    ('5', 'N. Ananda', 'Mining', '980', '+3%'),
  ];

  @override
  Widget build(BuildContext context) {
    return _MockScaffold(
      title: 'Klasemen League SAP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroMetricCard(
            title: 'SAP League',
            value: '#2',
            subtitle: 'Posisi anda bulan ini dari 128 peserta',
            color: Color(0xFFF59E0B),
            icon: Icons.emoji_events_rounded,
          ),
          const SizedBox(height: 14),
          const _SectionTitle('Leaderboard'),
          ..._rows.map((row) {
            return _LeagueTile(
              rank: row.$1,
              name: row.$2,
              dept: row.$3,
              point: row.$4,
              trend: row.$5,
            );
          }),
        ],
      ),
    );
  }
}

class IncidentInformationPage extends StatelessWidget {
  const IncidentInformationPage({super.key});

  static const _incidents = [
    IncidentArticle(
      imageUrl:
          'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=900&q=80',
      category: 'High Potential Incident',
      title: 'Material loose ditemukan di hauling road KM 4',
      caption:
          'Tim operasi memasang rambu sementara dan melakukan pembersihan jalur. Tidak ada korban dalam kejadian ini.',
      date: '29 Sep 2026',
      location: 'Hauling Road KM 4',
      reporter: 'Operation Team',
      severity: 'High Potential',
      body: [
        'Pada pemeriksaan awal shift pagi, tim operasi menemukan material loose di sisi kiri hauling road KM 4. Kondisi tersebut berpotensi mengenai unit yang melintas apabila terkena getaran atau hujan intensitas tinggi.',
        'Area kemudian diamankan menggunakan traffic cone dan rambu sementara. Dispatcher mengalihkan lajur unit berat ke sisi aman sampai proses pembersihan dan pemeriksaan slope selesai dilakukan.',
        'Tindak lanjut yang direkomendasikan adalah inspeksi ulang setelah hujan, penambahan patrol road maintenance pada jam kritis, dan briefing kepada operator terkait pelaporan dini kondisi jalan tidak normal.',
      ],
    ),
    IncidentArticle(
      imageUrl:
          'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=900&q=80',
      category: 'Property Damage',
      title: 'Kontak ringan unit LV dengan pembatas area workshop',
      caption:
          'Investigasi awal menunjukkan blind spot saat manuver mundur. Refreshment defensive driving dijadwalkan pekan ini.',
      date: '28 Sep 2026',
      location: 'Workshop Light Vehicle',
      reporter: 'Plant Department',
      severity: 'Medium',
      body: [
        'Satu unit light vehicle mengalami kontak ringan dengan pembatas area workshop saat melakukan manuver mundur. Tidak terdapat cedera personel, namun terdapat kerusakan minor pada bumper belakang dan pembatas portable.',
        'Hasil review awal menunjukkan spotter belum berada pada posisi optimal dan driver tidak melakukan stop-look-wave secara lengkap sebelum kendaraan bergerak mundur.',
        'Action sementara meliputi pemasangan marka parkir tambahan, refreshment defensive driving, dan penegasan kembali penggunaan spotter pada area padat aktivitas.',
      ],
    ),
    IncidentArticle(
      imageUrl:
          'https://images.unsplash.com/photo-1590496793929-36417d3117de?auto=format&fit=crop&w=900&q=80',
      category: 'Safety Alert',
      title: 'Debu meningkat pada area crusher saat shift siang',
      caption:
          'Pengendalian sementara dilakukan melalui water spray tambahan dan inspeksi ulang penggunaan respirator.',
      date: '27 Sep 2026',
      location: 'Crusher Area',
      reporter: 'HSE Patrol',
      severity: 'Safety Alert',
      body: [
        'Tim HSE mencatat peningkatan paparan debu pada area crusher ketika aktivitas dumping meningkat pada shift siang. Visibility masih dalam batas operasi, namun beberapa pekerja terlihat perlu menyesuaikan respirator.',
        'Supervisor area mengaktifkan water spray tambahan dan mengatur jeda dumping agar debu tidak terkonsentrasi di satu titik. Pemeriksaan singkat dilakukan pada respirator pekerja dan kondisi filter.',
        'Rekomendasi lanjutan adalah verifikasi efektivitas water spray, inspeksi nozzle, dan komunikasi rutin kepada pekerja mengenai penggunaan respirator pada kondisi berdebu.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _MockScaffold(
      title: 'Informasi Insiden',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Berita Insiden Terbaru'),
          ..._incidents.map((incident) => _NewsCard(article: incident)),
        ],
      ),
    );
  }
}

class IncidentArticleDetailPage extends StatelessWidget {
  const IncidentArticleDetailPage({required this.article, super.key});

  final IncidentArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBar(title: 'Informasi Insiden'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IncidentImage(
              imageUrl: article.imageUrl,
              height: 240,
              borderRadius: BorderRadius.zero,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(label: article.category, icon: Icons.article),
                      _InfoChip(label: article.date, icon: Icons.event),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    article.caption,
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SurfaceCard(
                    child: Column(
                      children: [
                        _ArticleMetaRow(
                          icon: Icons.place_rounded,
                          label: 'Lokasi',
                          value: article.location,
                        ),
                        const Divider(height: 18),
                        _ArticleMetaRow(
                          icon: Icons.person_rounded,
                          label: 'Pelapor',
                          value: article.reporter,
                        ),
                        const Divider(height: 18),
                        _ArticleMetaRow(
                          icon: Icons.warning_amber_rounded,
                          label: 'Klasifikasi',
                          value: article.severity,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _SectionTitle('Kronologi & Tindak Lanjut'),
                  ...article.body.map(
                    (paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        paragraph,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IncidentArticle {
  const IncidentArticle({
    required this.imageUrl,
    required this.category,
    required this.title,
    required this.caption,
    required this.date,
    required this.location,
    required this.reporter,
    required this.severity,
    required this.body,
  });

  final String imageUrl;
  final String category;
  final String title;
  final String caption;
  final String date;
  final String location;
  final String reporter;
  final String severity;
  final List<String> body;
}

class WorkRosterPage extends StatefulWidget {
  const WorkRosterPage({super.key});

  @override
  State<WorkRosterPage> createState() => _WorkRosterPageState();
}

class _WorkRosterPageState extends State<WorkRosterPage> {
  bool _reminder = true;
  String _pattern = '5-2';
  String _shift = 'Day Shift';

  @override
  Widget build(BuildContext context) {
    return _MockScaffold(
      title: 'Roster Kerja',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroMetricCard(
            title: 'Roster Aktif',
            value: 'Day',
            subtitle: 'Periode 29 Sep - 03 Okt 2026',
            color: Color(0xFF0F766E),
            icon: Icons.calendar_month_rounded,
          ),
          const SizedBox(height: 14),
          const _SectionTitle('Pengaturan Pribadi'),
          _SettingCard(
            title: 'Pola roster',
            subtitle: _pattern,
            icon: Icons.date_range_rounded,
            trailing: DropdownButton<String>(
              value: _pattern,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: '5-2', child: Text('5-2')),
                DropdownMenuItem(value: '6-1', child: Text('6-1')),
                DropdownMenuItem(value: '14-7', child: Text('14-7')),
              ],
              onChanged: (value) =>
                  setState(() => _pattern = value ?? _pattern),
            ),
          ),
          _SettingCard(
            title: 'Shift utama',
            subtitle: _shift,
            icon: Icons.schedule_rounded,
            trailing: DropdownButton<String>(
              value: _shift,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'Day Shift', child: Text('Day')),
                DropdownMenuItem(value: 'Night Shift', child: Text('Night')),
              ],
              onChanged: (value) => setState(() => _shift = value ?? _shift),
            ),
          ),
          _SettingCard(
            title: 'Reminder sebelum shift',
            subtitle: 'Notifikasi 60 menit sebelum jadwal',
            icon: Icons.notifications_active_rounded,
            trailing: Switch(
              value: _reminder,
              onChanged: (value) => setState(() => _reminder = value),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Jadwal Minggu Ini'),
          const _ScheduleChip(day: 'Sen', value: 'Day'),
          const _ScheduleChip(day: 'Sel', value: 'Day'),
          const _ScheduleChip(day: 'Rab', value: 'Day'),
          const _ScheduleChip(day: 'Kam', value: 'Off'),
          const _ScheduleChip(day: 'Jum', value: 'Night'),
        ],
      ),
    );
  }
}

class SapQualityPage extends StatelessWidget {
  const SapQualityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MockScaffold(
      title: 'Kualitas SAP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroMetricCard(
            title: 'Quality Score',
            value: '86',
            subtitle: 'Baik - 18 data berkualitas dari 21 input',
            color: Color(0xFF16A34A),
            icon: Icons.verified_rounded,
          ),
          SizedBox(height: 14),
          _SectionTitle('Kualitas Input'),
          _QualityTile(
              label: 'Baik', value: 18, total: 21, color: Color(0xFF16A34A)),
          _QualityTile(
              label: 'Memenuhi Target',
              value: 2,
              total: 21,
              color: Color(0xFFF59E0B)),
          _QualityTile(
              label: 'Perlu Perbaikan',
              value: 1,
              total: 21,
              color: Color(0xFFEF4444)),
          SizedBox(height: 16),
          _SectionTitle('Catatan Evaluasi'),
          _InsightCard(
              text:
                  'Foto evidence sudah konsisten dan remark mudah dipahami. Tingkatkan detail lokasi pada temuan area workshop.'),
        ],
      ),
    );
  }
}

class ActionTrackerPage extends StatelessWidget {
  const ActionTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MockScaffold(
      title: 'Action Tracker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroMetricCard(
            title: 'Progress Action SAP',
            value: '72%',
            subtitle: '8 closed, 3 on progress, 1 overdue',
            color: Color(0xFF7C3AED),
            icon: Icons.assignment_turned_in_rounded,
          ),
          SizedBox(height: 14),
          _SectionTitle('Daftar Action'),
          _ActionTimelineTile(
              title: 'Pasang barricade area pit selatan',
              owner: 'Operation',
              status: 'On Progress',
              progress: .65,
              color: Color(0xFF2563EB)),
          _ActionTimelineTile(
              title: 'Housekeeping tumpahan oli workshop',
              owner: 'Plant',
              status: 'Closed',
              progress: 1,
              color: Color(0xFF16A34A)),
          _ActionTimelineTile(
              title: 'Refreshment defensive driving',
              owner: 'HSE',
              status: 'Overdue',
              progress: .35,
              color: Color(0xFFEF4444)),
          _ActionTimelineTile(
              title: 'Perbaikan signage hauling KM 4',
              owner: 'Mining',
              status: 'Review',
              progress: .85,
              color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class DriverPerformanceAssessmentPage extends StatefulWidget {
  const DriverPerformanceAssessmentPage({super.key});

  @override
  State<DriverPerformanceAssessmentPage> createState() =>
      _DriverPerformanceAssessmentPageState();
}

class _DriverPerformanceAssessmentPageState
    extends State<DriverPerformanceAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _routeController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _externalDriverController = TextEditingController();
  final _notesController = TextEditingController();
  final _db = DatabaseService();

  static const _sections = <_DpaSection>[
    _DpaSection(
      number: 1,
      title: 'Safety & Skill Driving',
      color: Color(0xFFF97316),
      questions: [
        'Bagaimana kemampuan driver menjaga kecepatan yang aman selama perjalanan?',
        'Bagaimana kemampuan driver mengantisipasi kondisi jalan dan potensi bahaya?',
        'Bagaimana kemampuan driver melakukan pengereman dan akselerasi secara halus?',
        'Bagaimana kemampuan driver menjaga fokus dan konsentrasi selama perjalanan?',
        'Bagaimana kemampuan driver mengendalikan kendaraan dalam berbagai kondisi jalan?',
      ],
    ),
    _DpaSection(
      number: 2,
      title: 'Behavior & Service',
      color: Color(0xFF6366F1),
      questions: [
        'Bagaimana kedisiplinan driver terhadap waktu keberangkatan dan jadwal perjalanan?',
        'Bagaimana sikap, keramahan, dan komunikasi driver kepada penumpang?',
        'Bagaimana kepatuhan driver terhadap peraturan lalu lintas dan prosedur perusahaan?',
        'Bagaimana kepedulian driver terhadap kenyamanan dan keselamatan penumpang?',
        'Bagaimana kebersihan diri, kabin, dan kendaraan yang digunakan?',
      ],
    ),
  ];

  final Map<String, int> _ratings = {};
  _DpaDriver? _selectedDriver;
  _DpaVehicle? _selectedVehicle;
  bool _isExternalDriver = false;
  bool _isRentalVehicle = false;
  String? _tripType;
  DateTime _assessmentDate = DateTime.now();
  final Set<int> _expandedSections = {1, 2};

  @override
  void dispose() {
    _routeController.dispose();
    _vehicleController.dispose();
    _externalDriverController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _assessmentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _assessmentDate = value);
  }

  Future<void> _selectDriver() async {
    final rows = await _db.rawQuery('''select
      e.id,
      e.no_nik,
      e.nama_lengkap,
      e.posisi
    from employees e
    where e.deleted_at is null
      and e.no_nik is not null
      and e.nama_lengkap is not null
    order by e.no_nik''');
    if (!mounted) return;

    final drivers = rows
        .map((row) => _DpaDriver(
              id: row['id'] as int,
              nik: '${row['no_nik']}',
              name: '${row['nama_lengkap']}',
              position: row['posisi'] == null ? '' : '${row['posisi']}',
            ))
        .toList();
    var query = '';
    final value = await showModalBottomSheet<_DpaDriver>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final keyword = query.toLowerCase();
          final filtered = drivers.where((driver) {
            return driver.nik.toLowerCase().contains(keyword) ||
                driver.name.toLowerCase().contains(keyword);
          }).toList();
          return FractionallySizedBox(
            heightFactor: .86,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pilih Driver dari Data Karyawan',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: 3),
                              Text('Cari menggunakan NIK atau nama karyawan',
                                  style: TextStyle(
                                      color: Colors.black54, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                    child: TextField(
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      decoration: _dpaInputDecoration(
                        hint: 'Ketik NIK karyawan...',
                        icon: Icons.badge_rounded,
                      ),
                      onChanged: (value) =>
                          setModalState(() => query = value.trim()),
                    ),
                  ),
                  Expanded(
                    child: drivers.isEmpty
                        ? const _DpaDriverEmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: 'Data karyawan belum tersedia',
                            message:
                                'Sinkronkan master data terlebih dahulu agar NIK driver dapat dipilih.',
                          )
                        : filtered.isEmpty
                            ? const _DpaDriverEmptyState(
                                icon: Icons.person_search_rounded,
                                title: 'NIK tidak ditemukan',
                                message:
                                    'Periksa kembali NIK atau cari menggunakan nama karyawan.',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final driver = filtered[index];
                                  final selected =
                                      driver.id == _selectedDriver?.id;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 5),
                                    leading: CircleAvatar(
                                      backgroundColor: selected
                                          ? const Color(0xFF1769E8)
                                          : const Color(0xFFEAF2FF),
                                      child: Icon(Icons.person_rounded,
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFF1769E8)),
                                    ),
                                    title: Text(driver.nik,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    subtitle: Text([
                                      driver.name,
                                      if (driver.position.isNotEmpty)
                                        driver.position,
                                    ].join(' • ')),
                                    trailing: selected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: Color(0xFF16A34A))
                                        : const Icon(
                                            Icons.chevron_right_rounded),
                                    onTap: () => Navigator.pop(context, driver),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _selectedDriver = value);
  }

  Future<void> _selectVehicle() async {
    final rows = await _db.rawQuery('''select
      mv.id,
      mv.code,
      mv."name",
      mv.type,
      mv.license_plate,
      mv.company
    from vehicle_masters mv
    where mv.deleted_at is null
    order by mv.code''');
    if (!mounted) return;

    final vehicles = rows
        .map((row) => _DpaVehicle(
              id: row['id'] as int,
              code: row['code'] == null ? '' : '${row['code']}',
              name: row['name'] == null ? '' : '${row['name']}',
              type: row['type'] == null ? '' : '${row['type']}',
              licensePlate:
                  row['license_plate'] == null ? '' : '${row['license_plate']}',
              company: row['company'] == null ? '' : '${row['company']}',
            ))
        .toList();
    var query = '';
    final value = await showModalBottomSheet<_DpaVehicle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final keyword = query.toLowerCase();
          final filtered = vehicles.where((vehicle) {
            return vehicle.code.toLowerCase().contains(keyword) ||
                vehicle.licensePlate.toLowerCase().contains(keyword) ||
                vehicle.name.toLowerCase().contains(keyword);
          }).toList();
          return FractionallySizedBox(
            heightFactor: .86,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pilih Unit Kendaraan',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: 3),
                              Text(
                                  'Cari nomor lambung, plat polisi, atau nama unit',
                                  style: TextStyle(
                                      color: Colors.black54, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                    child: TextField(
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _dpaInputDecoration(
                        hint: 'Cari unit kendaraan...',
                        icon: Icons.search_rounded,
                      ),
                      onChanged: (value) =>
                          setModalState(() => query = value.trim()),
                    ),
                  ),
                  Expanded(
                    child: vehicles.isEmpty
                        ? const _DpaDriverEmptyState(
                            icon: Icons.local_shipping_outlined,
                            title: 'Master kendaraan belum tersedia',
                            message:
                                'Sinkronkan master data atau pilih Unit Rental untuk mengisi manual.',
                          )
                        : filtered.isEmpty
                            ? const _DpaDriverEmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'Unit tidak ditemukan',
                                message:
                                    'Periksa nomor lambung atau plat polisi yang dicari.',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final vehicle = filtered[index];
                                  final selected =
                                      vehicle.id == _selectedVehicle?.id;
                                  final identifier = [
                                    if (vehicle.code.isNotEmpty) vehicle.code,
                                    if (vehicle.licensePlate.isNotEmpty)
                                      vehicle.licensePlate,
                                  ].join(' • ');
                                  final detail = [
                                    if (vehicle.name.isNotEmpty) vehicle.name,
                                    if (vehicle.type.isNotEmpty) vehicle.type,
                                    if (vehicle.company.isNotEmpty)
                                      vehicle.company,
                                  ].join(' • ');
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 5),
                                    leading: CircleAvatar(
                                      backgroundColor: selected
                                          ? const Color(0xFF1769E8)
                                          : const Color(0xFFEAF2FF),
                                      child: Icon(Icons.directions_car_rounded,
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFF1769E8)),
                                    ),
                                    title: Text(
                                        identifier.isEmpty
                                            ? 'Tanpa nomor unit'
                                            : identifier,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    subtitle:
                                        Text(detail.isEmpty ? '-' : detail),
                                    trailing: selected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: Color(0xFF1769E8))
                                        : const Icon(
                                            Icons.chevron_right_rounded),
                                    onTap: () =>
                                        Navigator.pop(context, vehicle),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _selectedVehicle = value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_isExternalDriver && _selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih NIK driver terlebih dahulu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_isRentalVehicle && _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih unit kendaraan terlebih dahulu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final missing = _sections
        .expand((section) => section.questions)
        .where((question) => !_ratings.containsKey(question))
        .length;
    if (missing > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lengkapi $missing penilaian driver terlebih dahulu.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final total = _ratings.values.fold<int>(0, (sum, score) => sum + score);
    final score = (total / (_ratings.length * 5) * 100).round();
    final driverName = _isExternalDriver
        ? _externalDriverController.text.trim()
        : '${_selectedDriver!.name} (${_selectedDriver!.nik})';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded,
            color: Color(0xFF16A34A), size: 52),
        title: const Text('Penilaian Tersimpan'),
        content: Text(
          'Penilaian $driverName berhasil disimpan dengan nilai $score/100. Data ini masih tersimpan sebagai mockup dan siap disambungkan ke database.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = PreferenceService.getProfile();
    final assessorNik = profile?.noNik?.trim().isNotEmpty == true
        ? profile!.noNik!
        : '24011950928';
    final assessorName = profile?.namaLengkap?.trim().isNotEmpty == true
        ? profile!.namaLengkap!
        : 'MUHAMMAD ALFIAN YUSTIANDA';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: const TopBar(title: 'Driver Performance Assessment'),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DpaInfoBanner(),
              const SizedBox(height: 18),
              _DpaTwoColumn(
                children: [
                  _DpaReadOnlyField(
                    label: 'NIK Penilai',
                    value: assessorNik,
                    icon: Icons.badge_rounded,
                  ),
                  _DpaReadOnlyField(
                    label: 'Nama Penilai',
                    value: assessorName,
                    icon: Icons.person_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DpaTwoColumn(
                children: [
                  _DpaLabeledField(
                    label: 'Nama Driver',
                    required: true,
                    helper: _isExternalDriver
                        ? 'Gunakan untuk driver vendor atau driver di luar Indexim.'
                        : 'Driver internal dipilih berdasarkan NIK master karyawan.',
                    child: Column(
                      children: [
                        _DpaSourceToggle(
                          firstLabel: 'Driver Internal',
                          secondLabel: 'Driver Eksternal',
                          secondSelected: _isExternalDriver,
                          onChanged: (value) =>
                              setState(() => _isExternalDriver = value),
                        ),
                        const SizedBox(height: 10),
                        if (_isExternalDriver)
                          TextFormField(
                            controller: _externalDriverController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _dpaInputDecoration(
                              hint: 'Masukkan nama driver eksternal',
                              icon: Icons.person_outline_rounded,
                            ),
                            validator: (value) => _isExternalDriver &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Nama driver eksternal wajib diisi'
                                : null,
                          )
                        else
                          _DpaSelectionTile(
                            icon: Icons.badge_rounded,
                            title: _selectedDriver?.nik ??
                                'Pilih NIK driver internal',
                            subtitle: _selectedDriver?.name,
                            onTap: _selectDriver,
                          ),
                      ],
                    ),
                  ),
                  _DpaLabeledField(
                    label: 'Tanggal Penilaian',
                    required: true,
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(13),
                      child: InputDecorator(
                        decoration: _dpaInputDecoration(
                          hint: '',
                          icon: Icons.calendar_month_rounded,
                          suffixIcon:
                              const Icon(Icons.date_range_rounded, size: 19),
                        ),
                        child: Text(
                            DateFormat('dd/MM/yyyy').format(_assessmentDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DpaThreeColumn(
                children: [
                  _DpaLabeledField(
                    label: 'Jenis Perjalanan',
                    required: true,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_tripType),
                      initialValue: _tripType,
                      decoration: _dpaInputDecoration(
                        hint: 'Pilih jenis...',
                        icon: Icons.signpost_rounded,
                      ),
                      items: const [
                        'Roster masuk',
                        'Roster keluar',
                        'Perjalanan cuti',
                        'Antar jemput operasional',
                        'Perjalanan dinas',
                      ]
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _tripType = value),
                      validator: (value) =>
                          value == null ? 'Pilih jenis perjalanan' : null,
                    ),
                  ),
                  _DpaLabeledField(
                    label: 'Rute Perjalanan',
                    child: TextFormField(
                      controller: _routeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dpaInputDecoration(
                        hint: 'Misal: Site – Banjarmasin',
                        icon: Icons.location_on_rounded,
                      ),
                    ),
                  ),
                  _DpaLabeledField(
                    label: 'Unit Kendaraan',
                    required: true,
                    helper: _isRentalVehicle
                        ? 'Isi nomor lambung atau nomor plat polisi unit rental.'
                        : 'Unit dipilih dari master kendaraan perusahaan.',
                    child: Column(
                      children: [
                        _DpaSourceToggle(
                          firstLabel: 'Unit Terdaftar',
                          secondLabel: 'Unit Rental',
                          secondSelected: _isRentalVehicle,
                          onChanged: (value) =>
                              setState(() => _isRentalVehicle = value),
                        ),
                        const SizedBox(height: 10),
                        if (_isRentalVehicle)
                          TextFormField(
                            controller: _vehicleController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _dpaInputDecoration(
                              hint: 'Nomor lambung atau plat polisi',
                              icon: Icons.pin_rounded,
                            ),
                            validator: (value) => _isRentalVehicle &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Nomor unit rental wajib diisi'
                                : null,
                          )
                        else
                          _DpaSelectionTile(
                            icon: Icons.directions_car_rounded,
                            title: _selectedVehicle == null
                                ? 'Pilih unit kendaraan'
                                : [
                                    if (_selectedVehicle!.code.isNotEmpty)
                                      _selectedVehicle!.code,
                                    if (_selectedVehicle!
                                        .licensePlate.isNotEmpty)
                                      _selectedVehicle!.licensePlate,
                                  ].join(' • '),
                            subtitle: _selectedVehicle == null
                                ? null
                                : [
                                    if (_selectedVehicle!.name.isNotEmpty)
                                      _selectedVehicle!.name,
                                    if (_selectedVehicle!.type.isNotEmpty)
                                      _selectedVehicle!.type,
                                  ].join(' • '),
                            onTap: _selectVehicle,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ..._sections.map((section) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _DpaAssessmentSection(
                      section: section,
                      expanded: _expandedSections.contains(section.number),
                      ratings: _ratings,
                      onToggle: () => setState(() {
                        if (!_expandedSections.add(section.number)) {
                          _expandedSections.remove(section.number);
                        }
                      }),
                      onRated: (question, score) => setState(() {
                        _ratings[question] = score;
                      }),
                    ),
                  )),
              _DpaLabeledField(
                label: 'Catatan / Komentar Tambahan',
                child: TextFormField(
                  controller: _notesController,
                  minLines: 4,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dpaInputDecoration(
                    hint:
                        'Tuliskan catatan tambahan mengenai performa driver...',
                    icon: Icons.chat_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded, size: 19),
                  label: const Text(
                    'KIRIM PENILAIAN DRIVER',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1769E8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

InputDecoration _dpaInputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
    prefixIcon: Icon(icon, color: const Color(0xFF1769E8), size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF0F4F9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFF1769E8), width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
  );
}

class _DpaSection {
  const _DpaSection({
    required this.number,
    required this.title,
    required this.color,
    required this.questions,
  });

  final int number;
  final String title;
  final Color color;
  final List<String> questions;
}

class _DpaDriver {
  const _DpaDriver({
    required this.id,
    required this.nik,
    required this.name,
    required this.position,
  });

  final int id;
  final String nik;
  final String name;
  final String position;
}

class _DpaVehicle {
  const _DpaVehicle({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.licensePlate,
    required this.company,
  });

  final int id;
  final String code;
  final String name;
  final String type;
  final String licensePlate;
  final String company;
}

class _DpaSourceToggle extends StatelessWidget {
  const _DpaSourceToggle({
    required this.firstLabel,
    required this.secondLabel,
    required this.secondSelected,
    required this.onChanged,
  });

  final String firstLabel;
  final String secondLabel;
  final bool secondSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF4),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DpaSourceOption(
              label: firstLabel,
              selected: !secondSelected,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _DpaSourceOption(
              label: secondLabel,
              selected: secondSelected,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _DpaSourceOption extends StatelessWidget {
  const _DpaSourceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFF1769E8) : Colors.blueGrey,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DpaSelectionTile extends StatelessWidget {
  const _DpaSelectionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F9),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1769E8), size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: subtitle == null
                          ? Colors.blueGrey.shade400
                          : const Color(0xFF1769E8),
                      fontSize: 12,
                      fontWeight:
                          subtitle == null ? FontWeight.w500 : FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _DpaDriverEmptyState extends StatelessWidget {
  const _DpaDriverEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.blueGrey.shade300),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 12,
                    height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _DpaInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(12),
        border:
            const Border(left: BorderSide(color: Color(0xFF0EA5E9), width: 4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, color: Color(0xFF0284C7), size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Evaluasi kompetensi, perilaku, dan kualitas berkendara driver berdasarkan pengalaman langsung selama perjalanan.',
              style: TextStyle(
                  color: Color(0xFF0369A1), fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DpaTwoColumn extends StatelessWidget {
  const _DpaTwoColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        return Column(
          children: [
            children[0],
            const SizedBox(height: 16),
            children[1],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 16),
          Expanded(child: children[1]),
        ],
      );
    });
  }
}

class _DpaThreeColumn extends StatelessWidget {
  const _DpaThreeColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 760) {
        return Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i < children.length - 1) const SizedBox(width: 16),
          ],
        ],
      );
    });
  }
}

class _DpaLabeledField extends StatelessWidget {
  const _DpaLabeledField({
    required this.label,
    required this.child,
    this.required = false,
    this.helper,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label.toUpperCase(),
            children: [
              if (required)
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .2),
        ),
        const SizedBox(height: 7),
        child,
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!,
              style: TextStyle(
                  color: Colors.blueGrey.shade500,
                  fontSize: 10.5,
                  height: 1.3)),
        ],
      ],
    );
  }
}

class _DpaReadOnlyField extends StatelessWidget {
  const _DpaReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _DpaLabeledField(
      label: label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F9),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1769E8), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DpaAssessmentSection extends StatelessWidget {
  const _DpaAssessmentSection({
    required this.section,
    required this.expanded,
    required this.ratings,
    required this.onToggle,
    required this.onRated,
  });

  final _DpaSection section;
  final bool expanded;
  final Map<String, int> ratings;
  final VoidCallback onToggle;
  final void Function(String question, int score) onRated;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              color: const Color(0xFFF6F8FB),
              child: Row(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: section.color,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('${section.number}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(section.title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                  Text('(${section.questions.length} Pertanyaan)',
                      style: TextStyle(
                          color: Colors.blueGrey.shade500, fontSize: 11)),
                  const SizedBox(width: 8),
                  Icon(expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Column(
                children: [
                  for (var i = 0; i < section.questions.length; i++)
                    _DpaQuestion(
                      number: i + 1,
                      question: section.questions[i],
                      selected: ratings[section.questions[i]],
                      onSelected: (score) =>
                          onRated(section.questions[i], score),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DpaQuestion extends StatelessWidget {
  const _DpaQuestion({
    required this.number,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int number;
  final String question;
  final int? selected;
  final ValueChanged<int> onSelected;

  static const _options = [
    (5, 'Sangat\nBaik'),
    (4, 'Baik'),
    (3, 'Cukup'),
    (2, 'Kurang'),
    (1, 'Sangat\nKurang'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5EAF1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. $question',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _options.length; i++) ...[
                Expanded(
                  child: Builder(builder: (context) {
                    final option = _options[i];
                    final isSelected = selected == option.$1;
                    return InkWell(
                      onTap: () => onSelected(option.$1),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 22,
                              height: 22,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF1769E8)
                                      : const Color(0xFFB8C2D1),
                                  width: isSelected ? 2 : 1.4,
                                ),
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? const Color(0xFF1769E8)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              option.$2,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF1769E8)
                                    : Colors.blueGrey.shade600,
                                fontSize: 10,
                                height: 1.05,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MockScaffold extends StatelessWidget {
  const _MockScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopBar(title: title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          Icon(icon, color: Colors.white, size: 52),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric(
      {required this.label, required this.actual, required this.target});

  final String label;
  final int actual;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = (actual / target).clamp(0.0, 1.0);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('$actual / $target',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(12)),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard(
      {required this.name, required this.score, required this.rank});

  final String name;
  final String score;
  final String rank;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: Colors.indigo.shade50,
              child: Text(rank,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(score,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.indigo)),
        ],
      ),
    );
  }
}

class _LeagueTile extends StatelessWidget {
  const _LeagueTile(
      {required this.rank,
      required this.name,
      required this.dept,
      required this.point,
      required this.trend});

  final String rank;
  final String name;
  final String dept;
  final String point;
  final String trend;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
            backgroundColor: Colors.amber.shade100,
            child: Text(rank,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(dept),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(point, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(trend,
                style: const TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.article});

  final IncidentArticle article;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncidentArticleDetailPage(article: article),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IncidentImage(imageUrl: article.imageUrl, height: 150),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${article.category}  |  ${article.date}',
                      style: TextStyle(
                          color: Colors.blueGrey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(article.title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(article.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.black87, height: 1.35)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Baca detail',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentImage extends StatelessWidget {
  const _IncidentImage({
    required this.imageUrl,
    required this.height,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(18)),
  });

  final String imageUrl;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        imageUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: double.infinity,
            color: Colors.indigo.shade50,
            child: Icon(
              Icons.image_not_supported_rounded,
              color: Colors.indigo.shade200,
              size: 46,
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: Colors.indigo),
      label: Text(label),
      backgroundColor: Colors.indigo.shade50,
      side: BorderSide(color: Colors.indigo.shade100),
    );
  }
}

class _ArticleMetaRow extends StatelessWidget {
  const _ArticleMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.indigo, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.blueGrey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.trailing});

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.day, required this.value});

  final String day;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.w700)),
          Chip(label: Text(value), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile(
      {required this.label,
      required this.value,
      required this.total,
      required this.color});

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = (value / total).clamp(0.0, 1.0);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('$value/$total',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
              value: progress,
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(12)),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}

class _ActionTimelineTile extends StatelessWidget {
  const _ActionTimelineTile({
    required this.title,
    required this.owner,
    required this.status,
    required this.progress,
    required this.color,
  });

  final String title;
  final String owner;
  final String status;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              Chip(
                  label: Text(status),
                  backgroundColor: color.withValues(alpha: .12),
                  labelStyle:
                      TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          Text(owner,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
              value: progress,
              color: color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(12)),
        ],
      ),
    );
  }
}
