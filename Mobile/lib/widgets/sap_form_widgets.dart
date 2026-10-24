import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database.dart';
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
    super.key,
  });

  final int? initialCompanyId;
  final String? initialCompanyName;
  final ValueChanged<int?> onChanged;

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
    final rows = await _db.rawQuery('''select id, "name"
      from enum_masters
      where deleted_at is null and type='company'
      order by "name"''');
    if (!mounted) return;

    final databaseCompanies = rows
        .where((row) => row['id'] != null && row['name'] != null)
        .map((row) => MapEntry(row['id'] as int, '${row['name']}'))
        .toList();
    final byName = <String, MapEntry<int, String>>{
      for (final company in databaseCompanies)
        _normalize(company.value): company,
    };

    MapEntry<int, String> baseCompany(
      int fallbackId,
      String name,
      bool Function(String normalized) matches,
    ) {
      return databaseCompanies.firstWhere(
        (company) => matches(_normalize(company.value)),
        orElse: () => MapEntry(fallbackId, name),
      );
    }

    final indexim = baseCompany(
      -10001,
      'PT INDEXIM COALINDO',
      (name) => name.contains('indexim coalindo'),
    );
    final udu = baseCompany(
      -10002,
      'PT UNGGUL DINAMIKA UTAMA',
      (name) => name.contains('unggul dinamika utama') || name == 'udu',
    );
    byName[_normalize(indexim.value)] = indexim;
    byName[_normalize(udu.value)] = udu;

    final companies = byName.values.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    MapEntry<int, String>? selected;
    for (final company in companies) {
      if (company.key == widget.initialCompanyId) {
        selected = company;
        break;
      }
    }
    if (selected == null &&
        widget.initialCompanyName?.trim().isNotEmpty == true) {
      final initialName = _normalize(widget.initialCompanyName!);
      for (final company in companies) {
        if (_normalize(company.value).contains(initialName) ||
            initialName.contains(_normalize(company.value))) {
          selected = company;
          break;
        }
      }
    }
    selected ??= indexim;

    setState(() {
      _companies
        ..clear()
        ..addAll(companies);
      _selectedId = selected!.key;
      _loading = false;
    });
    widget.onChanged(_selectedId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Perusahaan / Mitra Kerja',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          key: ValueKey('company-${_selectedId ?? 'loading'}'),
          initialValue: _selectedId,
          isExpanded: true,
          decoration: InputDecoration(
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
                },
        ),
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

