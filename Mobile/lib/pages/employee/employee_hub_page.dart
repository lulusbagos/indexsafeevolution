import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../services/preference.dart';

class EmployeeHubPage extends StatefulWidget {
  const EmployeeHubPage({super.key});

  @override
  State<EmployeeHubPage> createState() => _EmployeeHubPageState();
}

class _EmployeeHubPageState extends State<EmployeeHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  ProfileModel? _profile;

  String _nama = 'LULUS BAGOS HERMAWAN';
  String _nik = '24051940986';
  String _dept = 'SYSTEM INTEGRATIONS';
  String _perusahaan = 'PT INDEXIM COALINDO';
  String _posisi = 'OFFICER PRODUCT & SYSTEM DEVELOPMENT';

  @override
  void initState() {
    super.initState();
    _profile = PreferenceService.getProfile();
    if (_profile != null) {
      _nama = _profile!.namaLengkap ?? _nama;
      _nik = _profile!.noNik ?? _nik;
      _dept = _profile!.depart ?? _dept;
      _perusahaan = _profile!.company ?? _perusahaan;
      _posisi = _profile!.jabatan ?? _posisi;
    }

    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6366F1); // Indigo HR Accent

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee & HR Hub',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '$_perusahaan • $_nama',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buat Pengajuan Cuti / Izin',
            icon: const Icon(Icons.post_add_rounded, color: primaryColor),
            onPressed: _showLeaveRequestDialog,
          ),
          IconButton(
            tooltip: 'Kontak HR',
            icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF64748B)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Layanan HR Helpdesk siap melayani konsultasi kekaryawanan.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.badge_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Profil Karyawan'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.event_note_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Pengajuan Cuti & Izin'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.medical_services_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('MCU & Kesehatan'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Kompetensi & POP'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Regulasi & PKB'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildProfileBiodataTab(),
          _buildLeaveRequestsTab(),
          _buildMcuHealthTab(),
          _buildCompetencyTab(),
          _buildPkbRegulationsTab(),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: BIODATA & PROFIL KARYAWAN
  // --------------------------------------------------------------------------
  Widget _buildProfileBiodataTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Digital ID Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4338CA), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KARTU IDENTITAS KARYAWAN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'PT INDEXIM COALINDO',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFFC7D2FE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'STATUS AKTIF',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _nama,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'NIK: $_nik • $_posisi',
                style: const TextStyle(fontSize: 12, color: Color(0xFFE0E7FF), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIdCardPill('Departemen', _dept),
                    _buildIdCardPill('Status Kerja', 'PKWTT / Permanen'),
                    _buildIdCardPill('Lokasi Kerja', 'Kaliorang Site'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Informasi Personal & Kekaryawanan',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),

        _buildInfoTile('Nomor Induk Kependudukan (KTP)', '350409********0001', Icons.credit_card_rounded),
        _buildInfoTile('No. BPJS Ketenagakerjaan', '24051940986-TK', Icons.health_and_safety_rounded),
        _buildInfoTile('No. BPJS Kesehatan', '0002451940986', Icons.local_hospital_rounded),
        _buildInfoTile('Kontak Darurat (Emergency)', 'Keluarga Inti (0812-3456-7890)', Icons.contact_phone_rounded),
        _buildInfoTile('Tanggal Mulai Bergabung', '01 Agustus 2021 (Masa Kerja: 5+ Tahun)', Icons.calendar_today_rounded),
      ],
    );
  }

  Widget _buildIdCardPill(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFFA5B4FC))),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: PENGAJUAN CUTI & IZIN
  // --------------------------------------------------------------------------
  Widget _buildLeaveRequestsTab() {
    final leaveHistory = [
      {
        'jenis': 'Cuti Tahunan (Annual Leave)',
        'periode': '12 - 16 Des 2026 (5 Hari)',
        'alasan': 'Keperluan keluarga di luar kota',
        'status': 'Disetujui HR & Atasan',
        'statusColor': const Color(0xFF10B981),
      },
      {
        'jenis': 'Izin Dinas Luar / Offsite',
        'periode': '20 - 22 Nov 2026 (3 Hari)',
        'alasan': 'Koordinasi sistem integrasi data tambang di HO Jakarta',
        'status': 'Selesai Dilaksanakan',
        'statusColor': const Color(0xFF0284C7),
      },
      {
        'jenis': 'Cuti Bersama Operasional',
        'periode': '25 Des 2026 (1 Hari)',
        'alasan': 'Hari Libur Nasional Hari Raya Natal',
        'status': 'Terjadwal',
        'statusColor': const Color(0xFF8B5CF6),
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Kuota Cuti Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saldo & Kuota Cuti Periode 2026',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Periode Aktif',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildLeaveBox('Hak Cuti', '12 Hari', const Color(0xFF6366F1)),
                  const SizedBox(width: 10),
                  _buildLeaveBox('Sudah Dipakai', '4 Hari', const Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  _buildLeaveBox('Sisa Cuti', '8 Hari', const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showLeaveRequestDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Ajukan Cuti / Izin Baru',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Riwayat Pengajuan Cuti & Izin',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),

        ...leaveHistory.map((l) => _buildLeaveHistoryCard(l)),
      ],
    );
  }

  Widget _buildLeaveBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveHistoryCard(Map<String, dynamic> item) {
    final statusColor = item['statusColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['jenis'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item['status'] as String,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                item['periode'] as String,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Keterangan: ${item['alasan']}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 3: MCU & KESEHATAN KERJA
  // --------------------------------------------------------------------------
  Widget _buildMcuHealthTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status MCU Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STATUS MEDICAL CHECK UP (MCU)',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFA7F3D0), letterSpacing: 0.5),
                  ),
                  Text(
                    'KATEGORI: FIT FOR DUTY',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Layak Bekerja di Area Tambang (FIT)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              SizedBox(height: 4),
              Text(
                'MCU Berkala Tahun 2026 telah selesai dilakukan oleh Occupational Health Centre PT Indexim Coalindo. Berlaku hingga Agustus 2027.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFFECFDF5), height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Rekapitulasi Riwayat Kesehatan Kerja',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),

        _buildHealthItem('MCU Berkala Periode 2026', 'Kategori FIT • Tekanan Darah Normal • Audiometri Normal', 'Agustus 2026', Icons.check_circle_rounded, const Color(0xFF10B981)),
        _buildHealthItem('Skrining Narkoba & Alkohol (Drug Test)', 'Hasil: Negatif (Memenuhi Syarat K3 Tambang)', 'Agustus 2026', Icons.science_rounded, const Color(0xFF0284C7)),
        _buildHealthItem('Vaksinasi & Imunisasi Tambang', 'Vaksinasi Lengkap (Hepatitis B & Tetanus)', 'Terverifikasi', Icons.vaccines_rounded, const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _buildHealthItem(String title, String desc, String date, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 4: KOMPETENSI & POP
  // --------------------------------------------------------------------------
  Widget _buildCompetencyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Matriks Kompetensi & Sertifikasi Tambang', 'Sertifikasi KESDM, POP/POM & Lisensi Keselamatan'),
        const SizedBox(height: 12),

        _buildCompetencyCard(
          title: 'Pengawas Operasional Pertama (POP) Panas Bumi & Minerba',
          penerbit: 'Kementerian ESDM Republik Indonesia (BNSP)',
          masaBerlaku: 'Berlaku s/d: Desember 2028',
          status: 'Tersertifikasi',
          icon: Icons.military_tech_rounded,
          color: const Color(0xFFD97706),
        ),
        _buildCompetencyCard(
          title: 'Mine Permit Indexim Coalindo (Full Pit Access)',
          penerbit: 'HSE Dept • PT Indexim Coalindo',
          masaBerlaku: 'Berlaku s/d: 13 Agustus 2027',
          status: 'Aktif (Sisa 259 Hari)',
          icon: Icons.credit_card_rounded,
          color: const Color(0xFF059669),
        ),
        _buildCompetencyCard(
          title: 'SIMPER / KIMPER Light Vehicle (LV 4x4 Tambang)',
          penerbit: 'Safety Operational • Site Kaliorang',
          masaBerlaku: 'Berlaku s/d: 18 Agustus 2027',
          status: 'Aktif Valid',
          icon: Icons.directions_car_rounded,
          color: const Color(0xFF0284C7),
        ),
        _buildCompetencyCard(
          title: 'Sertifikasi Auditor Sistem Manajemen K3 Pertambangan (SMKP)',
          penerbit: 'Pusdiklat Minerba KESDM',
          masaBerlaku: 'Berlaku Permanen',
          status: 'Kompeten',
          icon: Icons.verified_rounded,
          color: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildCompetencyCard({
    required String title,
    required String penerbit,
    required String masaBerlaku,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lembaga: $penerbit',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  masaBerlaku,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 5: REGULASI & PKB
  // --------------------------------------------------------------------------
  Widget _buildPkbRegulationsTab() {
    final pkbItems = [
      {'title': 'Perjanjian Kerja Bersama (PKB) Periode 2025-2027', 'pages': '142 Halaman PDF', 'type': 'PKB Resmi'},
      {'title': 'Buku Saku Tata Tertib & Disiplin Karyawan Tambang', 'pages': '48 Halaman PDF', 'type': 'Employee Handbook'},
      {'title': 'Pedoman Hak Cuti, Kompensasi & Tunjangan Site', 'pages': '24 Halaman PDF', 'type': 'HR Guidelines'},
      {'title': 'Prosedur Whistleblowing & Saluran Konseling Karyawan', 'pages': '16 Halaman PDF', 'type': 'Ethics & Compliance'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Dokumen Regulasi, PKB & Buku Panduan', 'Pedoman Hak & Kewajiban Karyawan PT Indexim Coalindo'),
        const SizedBox(height: 12),

        ...pkbItems.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['title']!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p['type']} • ${p['pages']}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Color(0xFF0284C7), size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Mengunduh dokumen: ${p['title']}')),
                      );
                    },
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  void _showLeaveRequestDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.event_available_rounded, color: Color(0xFF6366F1), size: 24),
                SizedBox(width: 8),
                Text(
                  'Formulir Pengajuan Cuti / Izin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Pengajuan akan diteruskan ke atasan langsung dan HR Site untuk verifikasi.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sisa saldo cuti tahunan Anda saat ini: 8 Hari Kerja.',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF3730A3)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text('Jenis Pengajuan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: 'Cuti Tahunan',
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'Cuti Tahunan', child: Text('Cuti Tahunan (Annual Leave)')),
                DropdownMenuItem(value: 'Cuti Lapangan / Roster', child: Text('Cuti Lapangan / Roster (Offsite)')),
                DropdownMenuItem(value: 'Cuti Khusus', child: Text('Cuti Khusus (Menikah, Melahirkan, Duka)')),
                DropdownMenuItem(value: 'Izin Sakit', child: Text('Izin Sakit (Disertai Surat Dokter)')),
              ],
              onChanged: (_) {},
            ),

            const SizedBox(height: 14),
            const Text('Alasan Pengajuan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tuliskan keperluan pengajuan cuti...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pengajuan berhasil dikirimkan ke atasan dan sistem HR!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Kirim Pengajuan Sekarang',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
