import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/link_model.dart';
import '../utils/links.dart';
import '../utils/routers.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _selectedCategory = 'Semua';

  final List<LinkMenuModel> _allModules = [
    ...listMenuSap,
    ...listMenuOhs1,
    ...listMenuOhs2,
    ...listMenuExtra,
  ];

  static const List<String> _categories = [
    'Semua',
    'Modul SAP',
    'Modul OHS',
    'Performance Hub',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  ({String name, Color color, String desc}) _getMenuMeta(LinkMenuModel menu) {
    if (listMenuSap.contains(menu)) {
      String desc = 'Aktivitas keselamatan dan pelaporan SAP';
      if (menu.route.contains('hazard')) desc = 'Lapor temuan bahaya & pantau status tindakan';
      if (menu.route.contains('inspection')) desc = 'Inspeksi berkala dan checklist kepatuhan';
      if (menu.route.contains('observation')) desc = 'Pengamatan perilaku dan kondisi aman';
      if (menu.route.contains('safety_talk')) desc = 'Materi dan absensi briefing safety';
      if (menu.route.contains('coaching')) desc = 'Bimbingan keselamatan tatap muka';
      if (menu.route.contains('bbs')) desc = 'Behavior Based Safety - observasi perilaku';
      if (menu.route.contains('ci')) desc = 'Critical Indicator Condition Assessment';
      return (name: 'Modul SAP', color: const Color(0xFF1D4ED8), desc: desc);
    } else if (listMenuOhs1.contains(menu) || listMenuOhs2.contains(menu)) {
      String desc = 'Pemeriksaan operasional & kesiapan kerja OHS';
      if (menu.route.contains('p2h')) desc = 'Pemeriksaan harian sarana & kendaraan operasional';
      if (menu.route.contains('p5m')) desc = 'Fit to Work & evaluasi kesehatan sebelum kerja';
      if (menu.route.contains('daily')) desc = 'Pemeriksaan harian area kerja & sarana';
      if (menu.route.contains('simama')) desc = 'Monitoring keselamatan shift malam';
      if (menu.route.contains('dpa')) desc = 'Driver Permit & Kepatuhan berkendara';
      return (name: 'Modul OHS', color: const Color(0xFF0F9F8F), desc: desc);
    } else {
      String desc = 'Kinerja, jadwal, dan pencapaian karyawan';
      if (menu.route.contains('roster')) desc = 'Jadwal kerja, shift lapangan & approval roster';
      if (menu.route.contains('league')) desc = 'Klasemen perolehan poin & peringkat keselamatan';
      if (menu.route.contains('incident')) desc = 'Buletin keselamatan & informasi insiden tambang';
      if (menu.route.contains('achievement')) desc = 'Pencapaian KPI safety individu dan tim';
      if (menu.route.contains('quality')) desc = 'Indeks kualitas pelaporan SAP';
      if (menu.route.contains('action')) desc = 'Pelacakan penyelesaian rekomendasi tindakan';
      return (name: 'Performance Hub', color: const Color(0xFFF08A00), desc: desc);
    }
  }

  bool _matchesQuery(LinkMenuModel item, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final title = item.title.replaceAll('\n', ' ').toLowerCase();
    if (title.contains(q)) return true;

    final meta = _getMenuMeta(item);
    if (meta.desc.toLowerCase().contains(q)) return true;
    if (meta.name.toLowerCase().contains(q)) return true;

    // Smart Indonesian keyword mapping
    if (q.contains('bahaya') || q.contains('hazard') || q.contains('temuan')) {
      return item.route.contains('hazard');
    }
    if (q.contains('inspeksi') || q.contains('periksa') || q.contains('cek') || q.contains('audit')) {
      return item.route.contains('inspection');
    }
    if (q.contains('mobil') || q.contains('kendaraan') || q.contains('unit') || q.contains('truk') || q.contains('p2h') || q.contains('sarana')) {
      return item.route.contains('p2h') || item.route.contains('dpa');
    }
    if (q.contains('roster') || q.contains('shift') || q.contains('jadwal') || q.contains('off') || q.contains('libur')) {
      return item.route.contains('roster');
    }
    if (q.contains('p5m') || q.contains('sehat') || q.contains('fit') || q.contains('tensi')) {
      return item.route.contains('p5m');
    }
    if (q.contains('peringkat') || q.contains('skor') || q.contains('league') || q.contains('poin') || q.contains('juara')) {
      return item.route.contains('league') || item.route.contains('achievement');
    }
    if (q.contains('insiden') || q.contains('kecelakaan') || q.contains('berita') || q.contains('kabar')) {
      return item.route.contains('incident') || item.route.contains('information');
    }
    if (q.contains('bbs') || q.contains('perilaku') || q.contains('behavior')) {
      return item.route.contains('bbs');
    }
    if (q.contains('ci') || q.contains('kondisi') || q.contains('condition') || q.contains('kritis')) {
      return item.route.contains('ci');
    }
    if (q.contains('coaching') || q.contains('bimbingan')) {
      return item.route.contains('coaching');
    }
    if (q.contains('observasi') || q.contains('observation')) {
      return item.route.contains('observation');
    }
    if (q.contains('talk') || q.contains('briefing') || q.contains('safety talk')) {
      return item.route.contains('safety_talk');
    }
    if (q.contains('action') || q.contains('tindakan') || q.contains('tracker')) {
      return item.route.contains('action');
    }

    return false;
  }

  List<LinkMenuModel> _getFilteredList() {
    final query = _searchCtrl.text;
    return _allModules.where((item) {
      final meta = _getMenuMeta(item);
      if (_selectedCategory != 'Semua' && meta.name != _selectedCategory) {
        return false;
      }
      return _matchesQuery(item, query);
    }).toList();
  }

  void _openModule(LinkMenuModel item) {
    HapticFeedback.selectionClick();
    _focusNode.unfocus();
    Navigator.pop(context);
    routePage(context, item.route, title: item.title);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final results = _getFilteredList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: const Color(0xFF0F172A),
                    tooltip: 'Kembali',
                  ),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE2E8F0),
                          width: _focusNode.hasFocus ? 1.5 : 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          if (results.isNotEmpty) {
                            _openModule(results.first);
                          }
                        },
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari modul, inspeksi, hazard, p2h...',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF2563EB),
                            size: 21,
                          ),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    size: 19,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Results or Quick Access
          Expanded(
            child: query.isEmpty && _selectedCategory == 'Semua'
                ? _buildQuickAccessSection()
                : _buildResultsList(results, query),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    final quickModules = [
      _allModules.firstWhere((m) => m.route.contains('hazard')),
      _allModules.firstWhere((m) => m.route.contains('p2h')),
      _allModules.firstWhere((m) => m.route.contains('inspection')),
      _allModules.firstWhere((m) => m.route.contains('roster')),
      _allModules.firstWhere((m) => m.route.contains('p5m')),
      _allModules.firstWhere((m) => m.route.contains('league')),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10, left: 2),
          child: Row(
            children: [
              Icon(Icons.flash_on_rounded, size: 17, color: Color(0xFFF59E0B)),
              SizedBox(width: 6),
              Text(
                'Menu Populer & Sering Digunakan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        ...quickModules.map((item) => _buildModuleCard(item)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Row(
            children: [
              const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Semua Modul Tersedia (${listMenuSap.length + listMenuOhs1.length + listMenuExtra.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        ..._allModules.map((item) => _buildModuleCard(item)),
      ],
    );
  }

  Widget _buildResultsList(List<LinkMenuModel> results, String query) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Modul tidak ditemukan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                query.isNotEmpty
                    ? 'Tidak ada hasil yang sesuai dengan kata kunci "$query". Coba cari kata kunci lain seperti hazard, p2h, inspeksi, atau roster.'
                    : 'Tidak ada modul dalam kategori ini.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _buildModuleCard(results[index]);
      },
    );
  }

  Widget _buildModuleCard(LinkMenuModel item) {
    final meta = _getMenuMeta(item);
    final cleanTitle = item.title.replaceAll('\n', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openModule(item),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: meta.color,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              cleanTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: meta.color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              meta.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: meta.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta.desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
