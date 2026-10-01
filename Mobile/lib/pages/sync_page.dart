import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../models/profile_model.dart';
import '../services/api.dart';
import '../services/database.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;
import '../utils/helpers.dart';
import 'home_page.dart';

class SyncPage extends StatefulWidget {
  const SyncPage(this.profile, {super.key});

  final ProfileModel? profile;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final _progress = ValueNotifier(0);
  final _db = DatabaseService();
  final _api = ApiService();
  final _dataSync = PreferenceService.getDataSync();
  final _masters = [
    'enum',
    'bridges',
    'inspection',
    'hazard',
    'coaching',
    'k3',
    'observation',
    'p2h',
    'p5m',
    'safety',
    'employee',
    'vehicle'
  ];

  static const Map<String, ({String label, IconData icon, String desc})> _masterInfo = {
    'enum': (
      label: 'Kategori & Parameter K3',
      icon: Icons.category_rounded,
      desc: 'Konfigurasi tipe bahaya & parameter sistem'
    ),
    'bridges': (
      label: 'Struktur Relasi Master',
      icon: Icons.hub_rounded,
      desc: 'Pemetaan relasi data & hierarki operasional'
    ),
    'inspection': (
      label: 'Checklist Formulir Inspeksi',
      icon: Icons.fact_check_rounded,
      desc: 'Daftar periksa & formulir inspeksi K3'
    ),
    'hazard': (
      label: 'Katalog Bahaya & Hazard',
      icon: Icons.warning_amber_rounded,
      desc: 'Klasifikasi risiko & temuan keselamatan'
    ),
    'coaching': (
      label: 'Modul Coaching & Konseling',
      icon: Icons.psychology_rounded,
      desc: 'Format pembinaan & bimbingan keselamatan'
    ),
    'k3': (
      label: 'Standar Keselamatan Kerja',
      icon: Icons.health_and_safety_rounded,
      desc: 'SOP, Golden Rules, dan standar K3'
    ),
    'observation': (
      label: 'Form Pengamatan Keselamatan',
      icon: Icons.visibility_rounded,
      desc: 'Lembar observasi perilaku aman & tidak aman'
    ),
    'p2h': (
      label: 'Pemeriksaan Harian (P2H)',
      icon: Icons.checklist_rtl_rounded,
      desc: 'Formulir inspeksi pra-operasi unit sarana'
    ),
    'p5m': (
      label: 'Materi Pembinaan P5M',
      icon: Icons.groups_rounded,
      desc: 'Bahan pengarahan 5 menit sebelum kerja'
    ),
    'safety': (
      label: 'Prosedur Safety Lapangan',
      icon: Icons.security_rounded,
      desc: 'Protokol darurat & keselamatan operasional'
    ),
    'employee': (
      label: 'Otoritas & Pengawas Lapangan',
      icon: Icons.verified_user_rounded,
      desc: 'Validasi otoritas pengawasan & tanggung jawab K3'
    ),
    'vehicle': (
      label: 'Data Unit & Kendaraan',
      icon: Icons.directions_car_rounded,
      desc: 'Nomor lambung, plat nomor, & spesifikasi'
    ),
  };

  String _name = '';
  String _table = '...';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    globals.currentPage = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(
          () => _name = (widget.profile?.namaLengkap?.split(' ')[0] ?? ''));
      try {
        final master = <String, int>{};
        for (int idx = 0; idx < _masters.length; idx++) {
          final name = _masters[idx];
          if (!mounted) return;
          setState(() {
            _table = name;
            _currentIndex = idx + 1;
          });

          var table = '';
          switch (name) {
            case 'employee':
              table = 'employees';
              break;
            case 'bridges':
              table = 'enum_bridges';
              break;
            case 'vehicle':
              table = 'vehicle_masters';
              break;
            default:
              table = '${name}_masters';
              break;
          }

          try {
            final res = await _api.getMaster(name);
            await res.fold(
              (error) async {
                debugPrint('[SyncPage] Error getMaster $name: ${error['message']}');
              },
              (response) async {
                final items = (response['data'] as List?) ?? [];
                for (var item in items) {
                  if (item is Map<String, dynamic>) {
                    var row = Map<String, dynamic>.from(item);
                    row.remove('created_by');
                    row.remove('updated_by');
                    row.remove('deleted_by');
                    await _db.insert(table, row);
                  }
                }
              },
            );
          } catch (e) {
            debugPrint('[SyncPage] Exception syncing $name: $e');
          }

          master[name] = 1;
          await PreferenceService.setDataSync(master);
          _progress.value = (((idx + 1) / _masters.length) * 100).toInt();
          await Future.delayed(const Duration(milliseconds: 60));
        }

        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 500));
        _complete();
      } catch (e) {
        debugPrint('[SyncPage] Error in sync process: $e');
        if (mounted) _complete();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _complete() async {
    globals.reSync = false;
    if (!mounted) return;
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeInfo = _masterInfo[_table];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // --- HEADER BRANDING ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.blue.shade100, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync_rounded,
                                  size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'INDEXSAFE SYNC ENGINE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- ILUSTRASI MODERN DENGAN CONTAINER ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                            color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/data-sync.gif',
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- GREETING & INFO CARD ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                            color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Halo ${_name.isNotEmpty ? titleCase(_name) : "Rekan"}, Semangat Pagi!',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('👋', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (globals.reSync == true)
                                ? 'Sedang melakukan pembaruan data awal sistem keselamatan kerja agar konfigurasi lokal selalu mutakhir.'
                                : (_dataSync != null &&
                                        _dataSync!.length < _masters.length)
                                    ? 'Melanjutkan sinkronisasi data awal sistem keselamatan kerja.'
                                    : 'Sedang melakukan sinkronisasi data awal sebelum aplikasi berjalan, mohon tunggu sebentar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey.shade600,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- CARD PROGRES & STATUS DETAIL ---
                    ValueListenableBuilder<int>(
                      valueListenable: _progress,
                      builder: (context, progressVal, _) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F2563EB),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFFBFDBFE),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Baris Angka Persentase & Label
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PROGRES SINKRONISASI',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.1,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _currentIndex > 0
                                            ? 'Modul $_currentIndex dari ${_masters.length}'
                                            : 'Menyiapkan modul...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueGrey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$progressVal%',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E3A8A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Linear Progress Bar yang Elegan
                              LinearPercentIndicator(
                                padding: EdgeInsets.zero,
                                barRadius: const Radius.circular(10),
                                lineHeight: 12,
                                percent: (progressVal / 100).clamp(0.0, 1.0),
                                backgroundColor: const Color(0xFFE2E8F0),
                                linearGradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF06B6D4)
                                  ],
                                ),
                                animation: true,
                                animateFromLastPercent: true,
                                animationDuration: 250,
                              ),

                              const SizedBox(height: 16),

                              // Status Modul yang Sedang Diunduh
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                      width: 0.8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade600,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        activeInfo?.icon ?? Icons.sync_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeInfo?.label ??
                                                'Memulai Pengunduhan...',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            activeInfo?.desc ??
                                                'Menyinkronkan data ke perangkat...',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blueGrey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (progressVal < 100)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF2563EB)),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // --- FOOTER KETERANGAN ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_clock_outlined,
                          size: 14,
                          color: Colors.blueGrey.shade400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Mohon jangan tutup aplikasi selama proses berlangsung',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

