import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/incident_news_model.dart';
import '../services/api.dart';
import '../services/preference.dart';

class SafetyUpdatesPage extends StatefulWidget {
  const SafetyUpdatesPage({super.key, this.selectedIncident});

  final IncidentNewsModel? selectedIncident;

  @override
  State<SafetyUpdatesPage> createState() => _SafetyUpdatesPageState();
}

class _SafetyUpdatesPageState extends State<SafetyUpdatesPage> {
  static const _primaryBlue = Color(0xFF155EEF);

  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<IncidentNewsModel> _allUpdates = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _category = 'Semua';
  String _searchQuery = '';

  final List<String> _categories = [
    'Semua',
    'Banner Informasi',
    'Near Miss',
    'Property Damage',
    'First Aid Injury',
    'Medical Treatment',
    'Kebakaran',
  ];

  bool _isBackgroundSyncing = false;

  @override
  void initState() {
    super.initState();
    
    // 1. Ambil data lokal terlebih dahulu agar halaman langsung tampil instan (0 ms)
    final cached = PreferenceService.getCachedSafetyUpdates();
    if (cached.isNotEmpty) {
      _allUpdates = cached;
      _isLoading = false;
    } else {
      _isLoading = true;
    }

    // 2. Tarik update terbaru secara background / incremental (hanya data baru jika sudah ada cache)
    _fetchUpdates(incremental: cached.isNotEmpty);

    // Jika dibuka langsung dari banner home, langsung tampilkan detail modal
    if (widget.selectedIncident != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIncidentDetail(widget.selectedIncident!);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUpdates({bool incremental = false, bool forceFullRefresh = false}) async {
    if (_allUpdates.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _isBackgroundSyncing = true;
    }

    try {
      int? sinceId;
      if (incremental && !forceFullRefresh && _allUpdates.isNotEmpty) {
        // Ambil ID terbesar di local cache untuk hanya meminta data baru
        sinceId = _allUpdates.fold<int>(0, (max, item) => item.id > max ? item.id : max);
      }

      // Ambil yang di-setting is_update = true atau ambil seluruh berita aktif
      final res = await _api.getIncidents(
        limit: 50,
        isUpdate: true,
        sinceId: sinceId,
      );

      res.fold(
        (err) {
          if (mounted) {
            setState(() {
              _isBackgroundSyncing = false;
              // Hanya tampilkan error layar penuh jika cache lokal benar-benar kosong
              if (_allUpdates.isEmpty) {
                _isLoading = false;
                _errorMessage = err['message']?.toString() ?? 'Gagal memuat safety updates';
              }
            });
          }
        },
        (data) async {
          if (mounted) {
            final incomingList = List<IncidentNewsModel>.from(data);

            List<IncidentNewsModel> finalList;
            if (sinceId != null && sinceId > 0) {
              // Mode Incremental: gabungkan berita baru dengan data lokal
              final map = <int, IncidentNewsModel>{
                for (var item in _allUpdates) item.id: item,
              };
              for (var item in incomingList) {
                map[item.id] = item;
              }
              finalList = map.values.toList();
            } else {
              // Full Refresh: ganti list secara keseluruhan
              finalList = incomingList;
            }

            // Jika ada selectedIncident dari banner yang di-klik dan belum ada di list
            if (widget.selectedIncident != null) {
              final exists = finalList.any((item) => item.id == widget.selectedIncident!.id);
              if (!exists) {
                finalList.insert(0, widget.selectedIncident!);
              }
            }

            // Urutkan dari kejadian/dibuat paling baru
            finalList.sort((a, b) {
              final aDate = a.tanggalKejadian ?? a.createdAt ?? DateTime(2000);
              final bDate = b.tanggalKejadian ?? b.createdAt ?? DateTime(2000);
              final cmp = bDate.compareTo(aDate);
              if (cmp != 0) return cmp;
              return b.id.compareTo(a.id);
            });

            setState(() {
              _allUpdates = finalList;
              _isLoading = false;
              _isBackgroundSyncing = false;
              _errorMessage = null;
            });

            // Simpan pembaruan ke memori lokal SharedPreferences secara offline
            await PreferenceService.setCachedSafetyUpdates(finalList);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBackgroundSyncing = false;
          if (_allUpdates.isEmpty) {
            _isLoading = false;
            _errorMessage = e.toString();
          }
        });
      }
    }
  }

  List<IncidentNewsModel> get _filteredUpdates {
    final list = _allUpdates.where((item) {
      // Buang data import excel placeholder / dummy jika ada
      final isDummy = item.dibuatOleh.toLowerCase().contains('system import') ||
          item.dibuatOleh.toLowerCase().contains('system') ||
          item.konten.trim().length < 15;
      if (isDummy) return false;

      final matchesCat = _category == 'Semua' ||
          item.kategori.toLowerCase().contains(_category.toLowerCase());
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          item.judul.toLowerCase().contains(q) ||
          item.konten.toLowerCase().contains(q) ||
          item.lokasi.toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();

    // Urutkan murni dari yang paling terbaru (berdasarkan tanggal kejadian atau waktu dibuat terbaru)
    list.sort((a, b) {
      final aDate = a.tanggalKejadian ?? a.createdAt ?? DateTime(2000);
      final bDate = b.tanggalKejadian ?? b.createdAt ?? DateTime(2000);
      final cmp = bDate.compareTo(aDate);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    return list;
  }

  String _formatImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    final base = _api.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return '$base$path';
  }

  String _formatDateTime(DateTime? dt, String? rawStr) {
    if (dt != null) {
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    }
    if (rawStr != null && rawStr.isNotEmpty) {
      final parsed = DateTime.tryParse(rawStr);
      if (parsed != null) {
        return DateFormat('dd MMM yyyy, HH:mm').format(parsed);
      }
      return rawStr;
    }
    return '-';
  }

  Color _getCategoryColor(String kategori) {
    final cat = kategori.toLowerCase();
    if (cat.contains('fatality') || cat.contains('kebakaran')) {
      return const Color(0xFFDC2626);
    } else if (cat.contains('near miss') || cat.contains('alert')) {
      return const Color(0xFFF59E0B);
    } else if (cat.contains('property damage')) {
      return const Color(0xFFEA580C);
    } else if (cat.contains('injury') || cat.contains('medical')) {
      return const Color(0xFFE11D48);
    } else if (cat.contains('banner')) {
      return const Color(0xFF2563EB);
    } else if (cat.contains('announcement') || cat.contains('mbs')) {
      return const Color(0xFF059669);
    }
    return const Color(0xFF4B5563);
  }

  IconData _getCategoryIcon(String kategori) {
    final cat = kategori.toLowerCase();
    if (cat.contains('fatality') || cat.contains('kebakaran')) {
      return Icons.local_fire_department_rounded;
    } else if (cat.contains('near miss') || cat.contains('alert')) {
      return Icons.warning_amber_rounded;
    } else if (cat.contains('property damage')) {
      return Icons.car_crash_rounded;
    } else if (cat.contains('injury') || cat.contains('medical')) {
      return Icons.health_and_safety_rounded;
    } else if (cat.contains('banner')) {
      return Icons.view_carousel_rounded;
    } else if (cat.contains('announcement') || cat.contains('mbs')) {
      return Icons.campaign_rounded;
    }
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final visibleItems = _filteredUpdates;
    final heroItem = visibleItems.isNotEmpty ? visibleItems.first : null;
    final listItems = visibleItems.length > 1 ? visibleItems.sublist(1) : <IncidentNewsModel>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _primaryBlue,
          onRefresh: () => _fetchUpdates(forceFullRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top Header Bar
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (canPop)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                elevation: 1,
                                shadowColor: Colors.black12,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => Navigator.pop(context),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 18,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Safety Updates',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _primaryBlue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_allUpdates.length} Info',
                                        style: const TextStyle(
                                          color: _primaryBlue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Berita keselamatan, peringatan, dan banner terkini',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search Bar
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x08000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: 'Cari judul, konten, atau lokasi...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isBackgroundSyncing)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
                      ),
                    ),
                  ),
                ),

              // Horizontal Category Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = cat == _category;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          showCheckmark: false,
                          side: BorderSide(
                            color: isSelected ? _primaryBlue : const Color(0xFFE2E8F0),
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: _primaryBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF475467),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onSelected: (_) => setState(() => _category = cat),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Content Body
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 12),
                        Text(
                          'Memuat berita keselamatan...',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF475467)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _fetchUpdates,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (visibleItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 54, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'Tidak ada berita atau update untuk filter ini',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Coba ganti kategori filter atau kata pencarian',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Hero / Featured Update (Item pertama)
                if (heroItem != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _buildHeroCard(heroItem),
                    ),
                  ),

                // Section Title
                if (listItems.isNotEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(18, 6, 18, 10),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Text(
                            'Update Terkait & Berita Lainnya',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // List of Updates
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: listItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = listItems[index];
                      return _buildUpdateCard(item);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(IncidentNewsModel item) {
    final catColor = _getCategoryColor(item.kategori);
    final catIcon = _getCategoryIcon(item.kategori);
    final imgUrl = _formatImageUrl(item.gambarUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _showIncidentDetail(item);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imgUrl.isNotEmpty)
                Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderBg(catColor, catIcon),
                )
              else
                _buildPlaceholderBg(catColor, catIcon),

              // Gradient Overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x20000000), Color(0xF0000000)],
                    stops: [0.2, 1.0],
                  ),
                ),
              ),

              // Content Inside Hero
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildBadge(
                          label: item.kategori.toUpperCase(),
                          icon: catIcon,
                          color: catColor,
                          isLight: true,
                        ),
                        if (item.isBanner) ...[
                          const SizedBox(width: 6),
                          _buildMiniTag('BANNER', const Color(0xFF2563EB)),
                        ],
                        if (item.isUpdate) ...[
                          const SizedBox(width: 6),
                          _buildMiniTag('UPDATE', const Color(0xFF059669)),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Text(
                      item.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.konten,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.lokasi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(item.tanggalKejadian, item.rawTanggal),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCard(IncidentNewsModel item) {
    final catColor = _getCategoryColor(item.kategori);
    final catIcon = _getCategoryIcon(item.kategori);
    final imgUrl = _formatImageUrl(item.gambarUrl);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _showIncidentDetail(item);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: imgUrl.isNotEmpty
                      ? Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildCardThumbnailFallback(catColor, catIcon),
                        )
                      : _buildCardThumbnailFallback(catColor, catIcon),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildBadge(
                          label: item.kategori.toUpperCase(),
                          icon: catIcon,
                          color: catColor,
                          isLight: false,
                        ),
                        if (item.isBanner) ...[
                          const SizedBox(width: 4),
                          _buildMiniTag('BANNER', const Color(0xFF2563EB)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.konten,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatDateTime(item.tanggalKejadian, item.rawTanggal),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.dibuatOleh,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 28),
                child: Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardThumbnailFallback(Color color, IconData icon) {
    return Container(
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  Widget _buildPlaceholderBg(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white24, size: 64),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isLight ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: isLight ? Colors.white : color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: isLight ? Colors.white : color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _showIncidentDetail(IncidentNewsModel item) {
    final catColor = _getCategoryColor(item.kategori);
    final catIcon = _getCategoryIcon(item.kategori);
    final imgUrl = _formatImageUrl(item.gambarUrl);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag Indicator Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    // Gambar Utama (Jika Ada)
                    if (imgUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 260),
                          width: double.infinity,
                          color: const Color(0xFF0F172A),
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180,
                              color: catColor.withValues(alpha: 0.1),
                              child: Center(
                                child: Icon(catIcon, size: 54, color: catColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Badges row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildBadge(
                          label: item.kategori.toUpperCase(),
                          icon: catIcon,
                          color: catColor,
                          isLight: false,
                        ),
                        if (item.isBanner)
                          _buildMiniTag('TAMPIL DI BANNER HOME', const Color(0xFF2563EB)),
                        if (item.isUpdate)
                          _buildMiniTag('SAFETY UPDATE MOBILE', const Color(0xFF059669)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      item.judul,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Metadata Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lokasi: ${item.lokasi}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Waktu Kejadian: ${_formatDateTime(item.tanggalKejadian, item.rawTanggal)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Dibuat oleh: ${item.dibuatOleh}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Konten Isi Berita
                    const Text(
                      'Detail Informasi:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.konten,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 14,
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
