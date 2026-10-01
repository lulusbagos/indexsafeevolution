import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
                _loading ? 'Memuat master perusahaan...' : 'Pilih perusahaan',
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
      if (!silent && context.mounted) {
        SnackBarMsg.danger(
          context,
          'Aktifkan izin lokasi untuk mengambil koordinat GPS.',
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (!context.mounted) return;
    controller.text =
        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    onChanged();
    if (!silent && context.mounted) {
      SnackBarMsg.success(context, 'Koordinat GPS berhasil diambil.');
    }
  } catch (e) {
    if (!silent && context.mounted) {
      SnackBarMsg.danger(context, 'Gagal mengambil lokasi GPS.');
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
      return AlertDialog(
        title: const Text('Tambah Lokasi Custom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gunakan fitur ini jika benchmark/detail lokasi belum tersedia di list.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nama Lokasi / Benchmark',
                hintText: 'Contoh: Workshop Mitra KM 12',
                prefixIcon: Icon(Icons.add_location_alt_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final id = -DateTime.now().millisecondsSinceEpoch;
              await db.insert('enum_masters', {
                'id': id,
                'code': 'CUSTOM-$id',
                'name': name,
                'type': 'location',
                'flag': 'custom-mobile',
                'ref_id': areaId,
                'created_at': DateTime.now().toString(),
                'updated_at': DateTime.now().toString(),
              });
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, MapEntry(id, name));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      );
    },
  );

  if (result != null && context.mounted) {
    SnackBarMsg.success(context, 'Lokasi custom berhasil ditambahkan.');
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
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_location_alt_rounded, size: 18),
        label: const Text('Tambah Lokasi Custom'),
      ),
    );
  }
}
