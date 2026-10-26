import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database.dart';
import '../services/api.dart';
import '../services/preference.dart';
import 'snackbar_msg.dart';

class SapFormIntroCard extends StatelessWidget {
  const SapFormIntroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, .24)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .18),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SapFormSectionTitle extends StatelessWidget {
  const SapFormSectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color = const Color(0xFF2563EB),
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyDropdown extends StatefulWidget {
  const CompanyDropdown({
    required this.onChanged,
    this.initialCompanyId,
    this.initialCompanyName,
    this.onChangedFull,
    this.decoration,
    this.hideLabel = false,
    super.key,
  });

  final int? initialCompanyId;
  final String? initialCompanyName;
  final ValueChanged<int?> onChanged;
  final void Function(int? id, String? name)? onChangedFull;
  final InputDecoration? decoration;
  final bool hideLabel;

  @override
  State<CompanyDropdown> createState() => _CompanyDropdownState();
}

class _CompanyDropdownState extends State<CompanyDropdown> {
  final _db = DatabaseService();
  final List<MapEntry<int, String>> _companies = [];
  int? _selectedId;
  bool _loading = true;

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('.', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    // 1. Fetch from SQLite first
    var rows = await _db.rawQuery('''select id, "name"
      from enum_masters
      where deleted_at is null and type='company'
      order by "name"''');

    // 2. Fetch all companies from server API to sync database
    try {
      final apiList = await ApiService().getCompanies();
      if (apiList.isNotEmpty) {
        for (final item in apiList) {
          final cid = item['id'] is int ? item['id'] as int : int.tryParse('${item['id']}') ?? 0;
          final cname = '${item['nama'] ?? item['name'] ?? ''}'.trim();
          if (cid != 0 && cname.isNotEmpty) {
            await _db.insert('enum_masters', {
              'id': cid,
              'name': cname,
              'type': 'company',
            });
          }
        }
        rows = await _db.rawQuery('''select id, "name"
          from enum_masters
          where deleted_at is null and type='company'
          order by "name"''');
      }
    } catch (_) {}

    if (!mounted) return;

    final databaseCompanies = rows
        .where((row) => row['id'] != null && row['name'] != null)
        .map((row) => MapEntry(row['id'] as int, '${row['name']}'))
        .toList();

    final byName = <String, MapEntry<int, String>>{
      for (final company in databaseCompanies)
        _normalize(company.value): company,
    };

    // Baseline mining contractors in Indexim area if SQLite empty
    final fallbackList = [
      const MapEntry(-10001, 'PT INDEXIM COALINDO'),
      const MapEntry(-10002, 'PT UNGGUL DINAMIKA UTAMA'),
      const MapEntry(-10003, 'PT CIPTA KRIDATAMA'),
      const MapEntry(-10004, 'PT BUKIT MAKMUR MANDIRI UTAMA'),
      const MapEntry(-10005, 'PT PAMAPERSADA NUSANTARA'),
      const MapEntry(-10006, 'PT MADHANI TALATAH NUSANTARA'),
      const MapEntry(-10007, 'PT RICOBANA ABADI'),
      const MapEntry(-10008, 'PT KALIMANTAN PRIMA PERSADA'),
      const MapEntry(-10009, 'PT PETROSEA TBK'),
      const MapEntry(-10010, 'PT THIESS CONTRACTORS INDONESIA'),
      const MapEntry(-10011, 'PT MACMAHON MINING SERVICES'),
      const MapEntry(-10012, 'PT UNITED TRACTORS'),
      const MapEntry(-10013, 'PT HEXINDO ADIPERKASA'),
      const MapEntry(-10014, 'PT TRAKTOR NUSANTARA'),
      const MapEntry(-10015, 'PT SANGGAR SARANA BAJA'),
      const MapEntry(-10016, 'PT JENDAR FAMILY KARYA'),
      const MapEntry(-10017, 'PT KANANI ENERGI'),
    ];

    for (final fb in fallbackList) {
      final key = _normalize(fb.value);
      if (!byName.containsKey(key)) {
        byName[key] = fb;
      }
    }

    final companies = byName.values.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Auto-detect login user's company
    final profile = PreferenceService.getProfile();
    final loginCompName = profile?.company ?? 'PT INDEXIM COALINDO';
    final loginCompId = profile?.companyId;

    MapEntry<int, String>? selected;
    // Match by initialCompanyId
    if (widget.initialCompanyId != null) {
      for (final company in companies) {
        if (company.key == widget.initialCompanyId) {
          selected = company;
          break;
        }
      }
    }
    // Match by initialCompanyName
    if (selected == null && widget.initialCompanyName?.trim().isNotEmpty == true) {
      final initialName = _normalize(widget.initialCompanyName!);
      for (final company in companies) {
        if (_normalize(company.value).contains(initialName) ||
            initialName.contains(_normalize(company.value))) {
          selected = company;
          break;
        }
      }
    }
    // Match by login user's company
    if (selected == null && loginCompId != null) {
      for (final company in companies) {
        if (company.key == loginCompId) {
          selected = company;
          break;
        }
      }
    }
    if (selected == null && loginCompName.trim().isNotEmpty) {
      final initialName = _normalize(loginCompName);
      for (final company in companies) {
        if (_normalize(company.value).contains(initialName) ||
            initialName.contains(_normalize(company.value))) {
          selected = company;
          break;
        }
      }
    }
    selected ??= companies.firstWhere(
      (c) => _normalize(c.value).contains('indexim'),
      orElse: () => companies.first,
    );

    setState(() {
      _companies
        ..clear()
        ..addAll(companies);
      _selectedId = selected!.key;
      _loading = false;
    });
    widget.onChanged(_selectedId);
    widget.onChangedFull?.call(_selectedId, selected.value);
  }

  @override
  Widget build(BuildContext context) {
    final dropdown = DropdownButtonFormField<int>(
      key: ValueKey('company-${_selectedId ?? 'loading'}'),
      initialValue: _selectedId,
      isExpanded: true,
      decoration: widget.decoration ??
          InputDecoration(
            hintText:
                _loading ? 'Memuat daftar perusahaan...' : 'Pilih perusahaan',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(Icons.apartment_rounded, size: 24),
            ),
          ),
      items: _companies
          .map((company) => DropdownMenuItem<int>(
                value: company.key,
                child: Text(
                  company.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: _loading
          ? null
          : (value) {
              setState(() => _selectedId = value);
              widget.onChanged(value);
              final found = _companies.firstWhere(
                (c) => c.key == value,
                orElse: () => MapEntry(value ?? 0, ''),
              );
              widget.onChangedFull?.call(value, found.value);
            },
    );

    if (widget.hideLabel) return dropdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Perusahaan / Mitra Kerja',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        dropdown,
        const SizedBox(height: 15),
      ],
    );
  }
}

Future<void> fillGpsCoordinate(
  BuildContext context,
  TextEditingController controller,
  VoidCallback onChanged, {
  bool silent = false,
}) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final prefs = await SharedPreferences.getInstance();
      final cachedGps = prefs.getString('last_known_gps_coord');
      if (cachedGps != null &&
          cachedGps.isNotEmpty &&
          controller.text.isEmpty) {
        controller.text = cachedGps;
        onChanged();
      }
      if (!silent && context.mounted) {
        SnackBarMsg.warning(
          context,
          'Aktifkan layanan lokasi perangkat agar koordinat terisi otomatis.',
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final prefs = await SharedPreferences.getInstance();
      final cachedGps = prefs.getString('last_known_gps_coord');
      if (cachedGps != null &&
          cachedGps.isNotEmpty &&
          controller.text.isEmpty) {
        controller.text = cachedGps;
        onChanged();
      }
      if (!silent && context.mounted) {
        SnackBarMsg.danger(
          context,
          'Aktifkan izin lokasi untuk mengambil koordinat GPS.',
        );
      }
      return;
    }

    // 1. Cepat: Ambil Last Known Position dari sensor perangkat (0 ms, 100% bekerja offline tanpa sinyal internet)
    Position? pos = await Geolocator.getLastKnownPosition();
    if (pos != null && controller.text.isEmpty) {
      if (context.mounted) {
        controller.text =
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        onChanged();
      }
    }

    // 2. Akurat: Ambil posisi satelit hardware aktual langsung dengan timeout 5 detik
    try {
      final freshPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      pos = freshPos;
      if (context.mounted) {
        controller.text =
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        onChanged();
      }
    } catch (_) {
      // Timeout satelit offline: posisi last known tetap dipakai
    }

    if (pos != null) {
      // Simpan koordinat ke SharedPreferences agar bisa digunakan offline sewaktu-waktu
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_known_gps_coord',
        '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
      );
      if (!silent && context.mounted) {
        SnackBarMsg.success(
            context, 'Koordinat GPS satelit berhasil dideteksi.');
      }
    } else {
      // 3. Fallback: Ambil dari penyimpanan lokal aplikasi jika perangkat baru restart tanpa cache OS
      final prefs = await SharedPreferences.getInstance();
      final cachedGps = prefs.getString('last_known_gps_coord');
      if (cachedGps != null &&
          cachedGps.isNotEmpty &&
          controller.text.isEmpty) {
        controller.text = cachedGps;
        onChanged();
        if (!silent && context.mounted) {
          SnackBarMsg.info(
              context, 'Menggunakan titik koordinat GPS tersimpan sebelumnya.');
        }
      } else if (!silent && context.mounted) {
        SnackBarMsg.warning(context, 'Sedang mencari sinyal satelit GPS...');
      }
    }
  } catch (e) {
    if (!silent && context.mounted) {
      SnackBarMsg.danger(context, 'Gagal mengambil lokasi GPS: $e');
    }
  }
}

InputDecoration gpsInputDecoration({
  required BuildContext context,
  required VoidCallback onPressed,
  Color iconColor = const Color(0xFF4F46E5),
}) {
  return InputDecoration(
    hintText: 'Koordinat GPS akan terisi otomatis',
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Icon(
        Icons.location_on,
        size: 24,
        color: iconColor,
      ),
    ),
    suffixIcon: IconButton(
      tooltip: 'Perbarui koordinat GPS',
      icon: const Icon(Icons.gps_fixed_rounded),
      color: Theme.of(context).colorScheme.primary,
      onPressed: onPressed,
    ),
  );
}

Future<MapEntry<int, String>?> showAddCustomLocationDialog({
  required BuildContext context,
  required DatabaseService db,
  required int? areaId,
}) async {
  if (areaId == null) {
    SnackBarMsg.warning(context, 'Pilih Area Utama terlebih dahulu.');
    return null;
  }

  final controller = TextEditingController();
  final result = await showDialog<MapEntry<int, String>>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_location_alt_rounded,
                    color: Color(0xFF2563EB), size: 27),
              ),
              const SizedBox(height: 18),
              const Text('Tambah lokasi baru',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'Tambahkan detail lokasi atau benchmark yang belum tersedia pada daftar.',
                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 22),
              const Text('NAMA LOKASI / BENCHMARK',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: Color(0xFF475569))),
              const SizedBox(height: 8),
              TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Contoh: Workshop Mitra KM 12',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.place_outlined,
                      color: Color(0xFF475569)),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFF2563EB), width: 1.25),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                SnackBarMsg.warning(
                    dialogContext, 'Masukkan nama lokasi terlebih dahulu.');
                return;
              }
              // Gunakan ID lokal yang unik dan positif. Sebagian versi SQLite
              // mengembalikan hasil insert negatif sebagai gagal ketika id
              // negatif dipakai, sehingga lokasi custom tidak pernah tampil.
              final id = DateTime.now().microsecondsSinceEpoch;
              final inserted = await db.insert('enum_masters', {
                'id': id,
                'code': 'CUSTOM-$id',
                'name': name,
                'type': 'location',
                'flag': 'custom-mobile',
                'ref_id': areaId,
                'created_at': DateTime.now().toString(),
                'updated_at': DateTime.now().toString(),
              });
              if (inserted <= 0) {
                if (dialogContext.mounted) {
                  SnackBarMsg.danger(
                      dialogContext, 'Lokasi belum dapat ditambahkan.');
                }
                return;
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, MapEntry(id, name));
              }
            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Tambahkan', maxLines: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (result != null && context.mounted) {
    SnackBarMsg.success(context, 'Lokasi baru berhasil ditambahkan.');
  }
  return result;
}

class AddCustomLocationButton extends StatelessWidget {
  const AddCustomLocationButton({
    required this.onPressed,
    super.key,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_location_alt_rounded, size: 17),
        label: const Text('Tambah lokasi baru', maxLines: 1,
            overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2563EB),
          side: const BorderSide(color: Color(0xFFBFDBFE)),
          backgroundColor: const Color(0xFFEFF6FF),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class SapHeaderCard extends StatelessWidget {
  const SapHeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor = const Color(0xFFEA580C),
    this.badgeBgColor = const Color(0xFFFFF7ED),
    this.badgeBorderColor = const Color(0xFFFFEDD5),
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color badgeBgColor;
  final Color badgeBorderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeBorderColor),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SapSectionCard extends StatelessWidget {
  const SapSectionCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.children,
    super.key,
  });

  final String stepNumber;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stepNumber,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: accentColor),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class SapDatePickerTile extends StatelessWidget {
  const SapDatePickerTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.badgeText,
    super.key,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badgeText != null)
              Text(
                badgeText!,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SapTimePickerTile extends StatelessWidget {
  const SapTimePickerTile({
    required this.label,
    required this.timeText,
    required this.onTap,
    super.key,
  });

  final String label;
  final String timeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeText,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SapEmployeeItem {
  final String nik;
  final String nama;
  final String departemen;
  final String jabatan;
  final String perusahaan;
  final int? perusahaanId;
  final String? foto;

  SapEmployeeItem({
    required this.nik,
    required this.nama,
    this.departemen = '',
    this.jabatan = '',
    this.perusahaan = '',
    this.perusahaanId,
    this.foto,
  });

  String get displayName => '$nama ($nik)';
}

class SapEmployeeAvatar extends StatefulWidget {
  final String? photo;
  final String name;
  final String nik;
  final double radius;
  final Color? fallbackBg;
  final Color? fallbackFg;

  const SapEmployeeAvatar({
    super.key,
    required this.photo,
    required this.name,
    required this.nik,
    this.radius = 18,
    this.fallbackBg,
    this.fallbackFg,
  });

  @override
  State<SapEmployeeAvatar> createState() => _SapEmployeeAvatarState();
}

class _SapEmployeeAvatarState extends State<SapEmployeeAvatar> {
  int _attempt = 0;

  String? _getUrl(int attempt) {
    final baseUrl = ApiService().baseUrl;
    final photo = widget.photo?.trim();
    if (attempt == 0) {
      if (photo != null && photo.isNotEmpty) {
        if (photo.startsWith('http://') || photo.startsWith('https://')) return photo;
        if (photo.startsWith('/uploads/') || photo.startsWith('/')) return '$baseUrl$photo';
        return '$baseUrl/api/image/${Uri.encodeComponent(photo)}';
      }
      if (widget.nik.isNotEmpty) {
        return '$baseUrl/api/image/${Uri.encodeComponent(widget.nik)}.jpg';
      }
      return null;
    } else if (attempt == 1) {
      if (widget.nik.isNotEmpty && photo != '${widget.nik}.jpg') {
        return '$baseUrl/api/image/${Uri.encodeComponent(widget.nik)}.jpg';
      }
      return null;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant SapEmployeeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo || oldWidget.nik != widget.nik) {
      _attempt = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.trim().isNotEmpty ? widget.name.trim()[0].toUpperCase() : 'U';
    final bg = widget.fallbackBg ?? const Color(0xFFE0F2FE);
    final fg = widget.fallbackFg ?? const Color(0xFF0284C7);

    final url = _getUrl(_attempt);
    if (url == null || _attempt >= 2) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bg,
        child: Text(
          initial,
          style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: widget.radius * 0.85),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: widget.radius * 2,
        height: widget.radius * 2,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _attempt < 2) {
                setState(() => _attempt++);
              }
            });
            return CircleAvatar(
              radius: widget.radius,
              backgroundColor: bg,
              child: Text(
                initial,
                style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: widget.radius * 0.85),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return CircleAvatar(
              radius: widget.radius,
              backgroundColor: bg,
              child: Text(
                initial,
                style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: widget.radius * 0.85),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SapEmployeePickerModal {
  static Future<SapEmployeeItem?> show(BuildContext context, {String title = 'Pilih PIC Penanggung Jawab'}) async {
    return showModalBottomSheet<SapEmployeeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SapEmployeePickerSheet(title: title),
    );
  }
}

class _SapEmployeePickerSheet extends StatefulWidget {
  final String title;
  const _SapEmployeePickerSheet({required this.title});

  @override
  State<_SapEmployeePickerSheet> createState() => _SapEmployeePickerSheetState();
}

class _SapEmployeePickerSheetState extends State<_SapEmployeePickerSheet> {
  final _searchCtrl = TextEditingController();
  List<SapEmployeeItem> _results = [];
  bool _isLoading = true;
  late String _userCompany;
  late int _userCompanyId;

  @override
  void initState() {
    super.initState();
    final profile = PreferenceService.getProfile();
    _userCompany = (profile?.company ?? '').trim();
    _userCompanyId = profile?.companyId ?? 0;
    _search('');
  }

  bool _isMyCompany(String perush, int? compId) {
    if (_userCompanyId > 0 && compId != null && compId == _userCompanyId) return true;
    if (_userCompany.isNotEmpty) {
      final cu = _userCompany.toLowerCase();
      final cp = perush.toLowerCase();
      return cp == cu || cp.contains(cu) || cu.contains(cp);
    }
    return false;
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    final cleanQ = query.trim();
    final safeQ = cleanQ.replaceAll("'", "''");
    final safeComp = _userCompany.replaceAll("'", "''");
    final list = <SapEmployeeItem>[];

    try {
      final db = await DatabaseService().database;
      final String sql;
      if (cleanQ.isEmpty) {
        sql = '''
          SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan, foto, company_id 
          FROM employees 
          WHERE no_nik IS NOT NULL AND nama_lengkap IS NOT NULL AND nama_lengkap != ''
          ORDER BY 
            CASE 
              WHEN ($_userCompanyId > 0 AND company_id = $_userCompanyId) OR (perusahaan IS NOT NULL AND perusahaan = '$safeComp') THEN 0 
              WHEN ('$safeComp' != '' AND perusahaan LIKE '%$safeComp%') THEN 1 
              ELSE 2 
            END,
            nama_lengkap ASC
          LIMIT 60
        ''';
      } else {
        sql = '''
          SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan, foto, company_id 
          FROM employees 
          WHERE (no_nik LIKE '%$safeQ%' OR nama_lengkap LIKE '%$safeQ%' OR depart LIKE '%$safeQ%' OR departemen LIKE '%$safeQ%' OR jabatan LIKE '%$safeQ%' OR posisi LIKE '%$safeQ%' OR perusahaan LIKE '%$safeQ%')
            AND nama_lengkap IS NOT NULL AND nama_lengkap != ''
          ORDER BY 
            CASE 
              WHEN ($_userCompanyId > 0 AND company_id = $_userCompanyId) OR (perusahaan IS NOT NULL AND perusahaan = '$safeComp') THEN 0 
              WHEN ('$safeComp' != '' AND perusahaan LIKE '%$safeComp%') THEN 1 
              ELSE 2 
            END,
            nama_lengkap ASC
          LIMIT 60
        ''';
      }
      final rows = await db.rawQuery(sql);

      for (final r in rows) {
        final rawCompId = r['company_id'];
        final int? compId = rawCompId is int ? rawCompId : int.tryParse(rawCompId?.toString() ?? '');
        list.add(SapEmployeeItem(
          nik: r['no_nik']?.toString().trim() ?? '',
          nama: r['nama_lengkap']?.toString().trim() ?? '',
          departemen: (r['departemen'] ?? r['depart'])?.toString().trim() ?? '',
          jabatan: (r['jabatan'] ?? r['posisi'])?.toString().trim() ?? '',
          perusahaan: r['perusahaan']?.toString().trim() ?? '',
          perusahaanId: compId,
          foto: r['foto']?.toString().trim(),
        ));
      }
    } catch (_) {}

    // Online fallback if empty or few
    if (list.length < 5 && cleanQ.isNotEmpty) {
      try {
        final res = await ApiService().searchPja(cleanQ, lintasPerusahaan: true);
        res.fold((_) {}, (serverData) {
          for (final item in serverData) {
            final nik = item['nik']?.toString().trim() ?? '';
            final nama = item['nama']?.toString().trim() ?? '';
            if (nik.isNotEmpty && nama.isNotEmpty && !list.any((x) => x.nik == nik)) {
              list.add(SapEmployeeItem(
                nik: nik,
                nama: nama,
                departemen: (item['departemen'] ?? item['depart'])?.toString().trim() ?? '',
                jabatan: (item['jabatan'] ?? item['posisi'])?.toString().trim() ?? '',
                perusahaan: item['perusahaan']?.toString().trim() ?? '',
                perusahaanId: item['perusahaanId'] is int ? item['perusahaanId'] : int.tryParse(item['perusahaanId']?.toString() ?? ''),
                foto: item['foto']?.toString().trim(),
              ));
            }
          }
        });
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _results = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      Text(
                        _userCompany.isNotEmpty ? 'Prioritas: $_userCompany (Bisa cari semua)' : 'Data karyawan & pengawas perusahaan',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Cari Nama, NIK, atau Perusahaan...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0D5C75)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchCtrl.clear(); _search(''); })
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _search,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('Tidak ada karyawan ditemukan', style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (ctx, i) {
                          final emp = _results[i];
                          final isMyComp = _isMyCompany(emp.perusahaan, emp.perusahaanId);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: SapEmployeeAvatar(
                              photo: emp.foto,
                              name: emp.nama,
                              nik: emp.nik,
                              radius: 20,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(emp.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                ),
                                if (isMyComp) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Perusahaan Anda', style: TextStyle(color: Color(0xFF166534), fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              'NIK: ${emp.nik}${emp.departemen.isNotEmpty ? ' • ${emp.departemen}' : ''}${emp.jabatan.isNotEmpty ? ' • ${emp.jabatan}' : ''} • ${emp.perusahaan}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () => Navigator.pop(context, emp),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class SapPicField extends StatelessWidget {
  final String label;
  final String? picText;
  final SapEmployeeItem? selectedEmployee;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final VoidCallback? onAutoRecommend;

  const SapPicField({
    super.key,
    this.label = 'PIC Penanggung Jawab Tindak Lanjut',
    required this.picText,
    this.selectedEmployee,
    required this.onTap,
    this.onClear,
    this.onAutoRecommend,
  });

  @override
  Widget build(BuildContext context) {
    final hasVal = (picText != null && picText!.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF0D5C75)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (onAutoRecommend != null)
              InkWell(
                onTap: onAutoRecommend,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5C75).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF0D5C75).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF0D5C75)),
                      SizedBox(width: 3),
                      Text('Auto Rekomendasi', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0D5C75))),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasVal ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasVal ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                if (selectedEmployee != null)
                  SapEmployeeAvatar(
                    photo: selectedEmployee!.foto,
                    name: selectedEmployee!.nama,
                    nik: selectedEmployee!.nik,
                    radius: 20,
                    fallbackBg: const Color(0xFFDCFCE7),
                    fallbackFg: const Color(0xFF16A34A),
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: hasVal ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                    child: Icon(
                      hasVal ? Icons.person_rounded : Icons.person_search_rounded,
                      color: hasVal ? const Color(0xFF16A34A) : const Color(0xFF0D5C75),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasVal ? (selectedEmployee?.nama ?? picText!) : 'Pilih PIC dari Data Karyawan',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: hasVal ? const Color(0xFF14532D) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasVal
                            ? (selectedEmployee != null
                                ? 'NIK: ${selectedEmployee!.nik}${selectedEmployee!.departemen.isNotEmpty ? ' • ${selectedEmployee!.departemen}' : ''}'
                                : 'PIC Terpilih')
                            : 'Ketuk untuk mencari nama atau NIK pengawas...',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: hasVal ? const Color(0xFF166534) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasVal && onClear != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                    onPressed: onClear,
                    tooltip: 'Hapus PIC',
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF0D5C75), size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SapGpsLocationCard extends StatefulWidget {
  final TextEditingController latController;
  final TextEditingController lngController;
  final TextEditingController? lokasiController;
  final Color primaryColor;

  const SapGpsLocationCard({
    super.key,
    required this.latController,
    required this.lngController,
    this.lokasiController,
    this.primaryColor = const Color(0xFF0D5C75),
  });

  @override
  State<SapGpsLocationCard> createState() => _SapGpsLocationCardState();
}

class _SapGpsLocationCardState extends State<SapGpsLocationCard> {
  bool _isLoading = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    if (widget.latController.text.trim().isEmpty || widget.lngController.text.trim().isEmpty) {
      _autoFetchGps();
    }
  }

  Future<void> _autoFetchGps() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusText = 'Mendeteksi koordinat GPS...';
    });

    try {
      // 1. Instant check with last known position
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        widget.latController.text = lastPos.latitude.toStringAsFixed(6);
        widget.lngController.text = lastPos.longitude.toStringAsFixed(6);
      }

      // 2. Accurate current position
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() { _isLoading = false; _statusText = 'GPS tidak aktif'; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() { _isLoading = false; _statusText = 'Izin GPS ditolak'; });
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (mounted) {
        setState(() {
          widget.latController.text = pos.latitude.toStringAsFixed(6);
          widget.lngController.text = pos.longitude.toStringAsFixed(6);
          if (widget.lokasiController != null && widget.lokasiController!.text.isEmpty) {
            widget.lokasiController!.text = 'GPS: ${widget.latController.text}, ${widget.lngController.text}';
          }
          _isLoading = false;
          _statusText = 'GPS Terkunci Otomatis (Akurat)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = widget.latController.text.isNotEmpty ? 'GPS Terkunci' : 'Gagal mendeteksi GPS';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = widget.latController.text.isNotEmpty && widget.lngController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasCoords ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCoords ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                size: 18,
                color: hasCoords ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Koordinat GPS Lokasi (Otomatis)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                )
              else
                InkWell(
                  onTap: _autoFetchGps,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF0369A1)),
                        SizedBox(width: 4),
                        Text('Perbarui', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Latitude', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        widget.latController.text.isNotEmpty ? widget.latController.text : '- - -',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Longitude', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        widget.lngController.text.isNotEmpty ? widget.lngController.text : '- - -',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_statusText != null) ...[
            const SizedBox(height: 6),
            Text(
              _statusText!,
              style: TextStyle(
                fontSize: 11,
                color: hasCoords ? const Color(0xFF059669) : const Color(0xFFE11D48),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

