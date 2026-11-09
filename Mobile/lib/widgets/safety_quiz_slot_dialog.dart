import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Item simbol pada roda/slot reel
class SlotSymbol {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String category;

  const SlotSymbol({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.category,
  });
}

/// Model soal kuis K3
class QuizQuestion {
  final String category;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int points;

  const QuizQuestion({
    required this.category,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.points = 100,
  });
}

/// Dialog Kuis K3 dengan Animasi Slot Berputar (Lucky Safety Slot)
/// Dikhususkan untuk NIK: 24051940986 (Lulus Bagos Hermawan)
class SafetyQuizSlotDialog extends StatefulWidget {
  final String userNik;
  final String userName;

  const SafetyQuizSlotDialog({
    super.key,
    required this.userNik,
    required this.userName,
  });

  /// Static helper untuk menampilkan dialog
  static Future<void> show(
    BuildContext context, {
    String userNik = '24051940986',
    String userName = 'Lulus Bagos Hermawan',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => SafetyQuizSlotDialog(
        userNik: userNik,
        userName: userName,
      ),
    );
  }

  @override
  State<SafetyQuizSlotDialog> createState() => _SafetyQuizSlotDialogState();
}

class _SafetyQuizSlotDialogState extends State<SafetyQuizSlotDialog>
    with TickerProviderStateMixin {
  // Daftar simbol slot bertema K3 Pertambangan MBS
  static const List<SlotSymbol> _symbols = [
    SlotSymbol(
      id: 'apd',
      title: 'APD & Hazard',
      icon: Icons.health_and_safety_rounded,
      color: Color(0xFF10B981),
      category: 'APD & HAZARD',
    ),
    SlotSymbol(
      id: 'loto',
      title: 'LOTO & Isolasi',
      icon: Icons.bolt_rounded,
      color: Color(0xFFF59E0B),
      category: 'LOTO & ISOLASI',
    ),
    SlotSymbol(
      id: 'hauling',
      title: 'Jalur Hauling',
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF3B82F6),
      category: 'LALU LINTAS & HAULING',
    ),
    SlotSymbol(
      id: 'height',
      title: 'Ketinggian',
      icon: Icons.terrain_rounded,
      color: Color(0xFF8B5CF6),
      category: 'KERJA KETINGGIAN',
    ),
    SlotSymbol(
      id: 'hotwork',
      title: 'Izin Kerja Panas',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFF97316),
      category: 'HOT WORK & FIRE',
    ),
    SlotSymbol(
      id: 'golden',
      title: 'Golden Rules',
      icon: Icons.verified_user_rounded,
      color: Color(0xFFEC4899),
      category: 'GOLDEN RULES MBS',
    ),
    SlotSymbol(
      id: 'jackpot',
      title: 'JACKPOT K3',
      icon: Icons.stars_rounded,
      color: Color(0xFFEAB308),
      category: 'JACKPOT K3',
    ),
  ];

  // Bank Soal K3 Tambang PT Indexim Coalindo
  static const List<QuizQuestion> _questionBank = [
    QuizQuestion(
      category: 'LALU LINTAS & HAULING',
      question:
          'Berapa jarak aman beriringan (following distance) antar dump truck di jalan hauling pada kondisi berdebu/licin?',
      options: [
        '15 meter',
        '30 meter',
        'Minimal 50 meter (atau 4x panjang unit)',
        '10 meter asal lampu menyala',
      ],
      correctIndex: 2,
      explanation:
          'Dalam standar keselamatan hauling MBS, saat visibilitas berdebu atau jalan licin jarak aman minimal adalah 50 meter guna menjamin jarak pengereman darurat.',
      points: 150,
    ),
    QuizQuestion(
      category: 'LALU LINTAS & HAULING',
      question:
          'Berapa batas kecepatan maksimal light vehicle (LV) saat melintas di area workshop dan persimpangan tambang?',
      options: [
        '10 km/jam',
        '20 km/jam',
        '40 km/jam',
        '50 km/jam',
      ],
      correctIndex: 1,
      explanation:
          'Batas kecepatan di area ramai/workshop adalah 20 km/jam untuk mencegah tabrakan dengan pejalan kaki maupun unit manuver.',
      points: 100,
    ),
    QuizQuestion(
      category: 'LOTO & ISOLASI',
      question:
          'Sebelum mekanik melakukan perbaikan pada sistem hidrolik atau mesin dump truck, apa tindakan awal yang wajib dilakukan?',
      options: [
        'Langsung melepas selang oli',
        'Pasang gembok LOTO pribadi, Danger Tag, & uji Zero Energy State',
        'Membunyikan klakson 3 kali',
        'Meminta pengawas mematikan radio komunikasi',
      ],
      correctIndex: 1,
      explanation:
          'Wajib isolasi energi (LOTO) dan lakukan tes de-energisasi (Zero Energy) sebelum kontak fisik dengan komponen mekanis bertekanan.',
      points: 150,
    ),
    QuizQuestion(
      category: 'KERJA KETINGGIAN',
      question:
          'Mulai dari ketinggian berapa pekerja wajib menggunakan Full Body Harness dengan double lanyard (100% tie-off)?',
      options: [
        'Ketinggian 1.0 meter',
        'Ketinggian 1.8 meter ke atas',
        'Ketinggian 4.0 meter ke atas',
        'Hanya saat berada di atas conveyor',
      ],
      correctIndex: 1,
      explanation:
          'Golden Rules K3: Bekerja pada ketinggian 1.8 meter atau lebih berpotensi jatuh fatal sehingga wajib menggunakan full body harness terpasang pada anchor point terverifikasi.',
      points: 120,
    ),
    QuizQuestion(
      category: 'APD & HAZARD',
      question:
          'Alat Pelindung Diri (APD) standar minimum apa yang wajib dikenakan setiap orang yang memasuki area operasional tambang aktif?',
      options: [
        'Safety Helmet, Safety Shoes, Rompi Reflektor, & Kacamata Safety',
        'Hanya kaos seragam dan sepatu kets',
        'Safety shoes dan topi biasa',
        'Cukup membawa radio HT',
      ],
      correctIndex: 0,
      explanation:
          'Kombinasi APD wajib di area tambang aktif adalah Helm, Safety Shoes sol bergerigi, Rompi dengan pita pemantul (hi-vis), dan Safety Glasses.',
      points: 100,
    ),
    QuizQuestion(
      category: 'HOT WORK & FIRE',
      question:
          'Sebelum melakukan pekerjaan pengelasan/pemotongan (Hot Work) di workshop, apa yang wajib disiapkan?',
      options: [
        'Cukup segelas air mineral',
        'Izin Kerja Panas (Hot Work Permit) aktif & APAR siap pakai di radius 5 meter',
        'Hanya menyalakan exhaust fan',
        'Menunggu pengawas datang setelah selesai',
      ],
      correctIndex: 1,
      explanation:
          'Pekerjaan panas wajib dilengkapi izin resmi (Hot Work Permit) dan standby fire watch serta APAR dengan kondisi siap pakai.',
      points: 150,
    ),
    QuizQuestion(
      category: 'GOLDEN RULES MBS',
      question:
          'Apa prinsip utama dari Pelaporan Bahaya K3 (Hazard & Observation) dalam Menuju Budaya Safety (MBS)?',
      options: [
        'Mencari kesalahan rekan kerja agar dihukum',
        'Identifikasi dini potensi bahaya secara proaktif untuk mencegah insiden berulang',
        'Hanya dilaporkan jika ada kerusakan bernilai miliaran rupiah',
        'Disimpan dan dilaporkan setiap akhir tahun',
      ],
      correctIndex: 1,
      explanation:
          'Filosofi MBS adalah pencegahan aktif. Setiap temuan perilaku dan kondisi tidak aman harus segera dilaporkan dan ditindaklanjuti tuntas.',
      points: 200,
    ),
    QuizQuestion(
      category: 'JACKPOT K3',
      question:
          'BONUS SUPER JACKPOT K3: Apa makna komitmen "Semangat Pagi" dalam budaya kerja K3 PT Indexim Coalindo?',
      options: [
        'Sekadar sapaan di awal waktu kerja',
        'Energi, fokus, dan komitmen keselamatan prima tanpa kenal lelah sepanjang jam kerja',
        'Tanda jam istirahat dimulai',
        'Hanya diucapkan saat briefing pagi',
      ],
      correctIndex: 1,
      explanation:
          'Semangat Pagi mencerminkan antusiasme dan komitmen zero incident yang selalu segar dan waspada dari awal hingga akhir shift!',
      points: 300,
    ),
  ];

  // Controllers untuk 3 Slot Reels
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  // Indeks simbol saat ini untuk 3 reel
  int _reelIndex1 = 0;
  int _reelIndex2 = 2;
  int _reelIndex3 = 4;

  // Status permainan
  bool _isSpinning = false;
  bool _hasSpunOnce = false;
  bool _isJackpot = false;

  // Soal yang sedang aktif
  QuizQuestion? _currentQuestion;
  int? _selectedAnswerIndex;
  bool _hasAnswered = false;
  bool _isAnswerCorrect = false;

  // Skor dan statistik pemain
  int _totalScore = 0;
  int _streakCount = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadSavedScore();

    // Animasi putaran slot: 2600 milidetik dengan kurva deakselerasi realistis
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _spinAnimation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutCubic,
    );

    _spinAnimation.addListener(_onSpinTick);
    _spinAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSpinFinished();
      }
    });

    // Auto putar slot pertama kali agar langsung interaktif dan memukau
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spinSlot();
    });
  }

  @override
  void dispose() {
    _spinAnimation.removeListener(_onSpinTick);
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _totalScore = prefs.getInt('kuis_slot_score_${widget.userNik}') ?? 250;
        _streakCount = prefs.getInt('kuis_slot_streak_${widget.userNik}') ?? 1;
      });
    } catch (_) {}
  }

  Future<void> _saveScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('kuis_slot_score_${widget.userNik}', _totalScore);
      await prefs.setInt('kuis_slot_streak_${widget.userNik}', _streakCount);
    } catch (_) {}
  }

  void _onSpinTick() {
    final progress = _spinAnimation.value;

    // Reel 1 berhenti duluan (progress > 0.65)
    if (progress < 0.65) {
      _reelIndex1 = (_reelIndex1 + 1) % _symbols.length;
    }

    // Reel 2 berhenti di tengah (progress > 0.85)
    if (progress < 0.85) {
      _reelIndex2 = (_reelIndex2 + 1) % _symbols.length;
    }

    // Reel 3 berputar hingga akhir
    if (progress < 1.0) {
      _reelIndex3 = (_reelIndex3 + 1) % _symbols.length;
    }

    // Taptic feedback saat reel sedang berputar cepat
    if (_random.nextInt(6) == 0) {
      HapticFeedback.selectionClick();
    }

    setState(() {});
  }

  void _spinSlot() {
    if (_isSpinning) return;

    HapticFeedback.heavyImpact();

    setState(() {
      _isSpinning = true;
      _hasSpunOnce = true;
      _selectedAnswerIndex = null;
      _hasAnswered = false;
      _isAnswerCorrect = false;
      _currentQuestion = null;
    });

    _spinController.reset();
    _spinController.forward();
  }

  void _onSpinFinished() {
    HapticFeedback.vibrate();

    // Tentukan hasil akhir reel dengan algoritma menyenangkan
    // Ada 35% kemungkinan dapat 3 simbol sama (Jackpot!)
    final willJackpot = _random.nextDouble() < 0.35;
    if (willJackpot) {
      final luckyIndex = _random.nextInt(_symbols.length);
      _reelIndex1 = luckyIndex;
      _reelIndex2 = luckyIndex;
      _reelIndex3 = luckyIndex;
      _isJackpot = true;
    } else {
      _reelIndex1 = _random.nextInt(_symbols.length);
      _reelIndex2 = _random.nextInt(_symbols.length);
      _reelIndex3 = _random.nextInt(_symbols.length);
      _isJackpot = (_reelIndex1 == _reelIndex2 && _reelIndex2 == _reelIndex3);
    }

    // Ambil kategori dari reel tengah
    final winningSymbol = _symbols[_reelIndex2];

    // Cari soal yang relevan atau ambil acak dari bank soal
    final matchingQuestions = _questionBank
        .where((q) => q.category == winningSymbol.category)
        .toList();

    QuizQuestion picked;
    if (matchingQuestions.isNotEmpty) {
      picked = matchingQuestions[_random.nextInt(matchingQuestions.length)];
    } else {
      picked = _questionBank[_random.nextInt(_questionBank.length)];
    }

    setState(() {
      _isSpinning = false;
      _currentQuestion = picked;
    });

    // Getar ganda untuk mengumumkan reel berhenti
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.mediumImpact();
    });
  }

  void _answerQuestion(int index) {
    if (_hasAnswered || _currentQuestion == null) return;

    final isCorrect = (index == _currentQuestion!.correctIndex);

    setState(() {
      _selectedAnswerIndex = index;
      _hasAnswered = true;
      _isAnswerCorrect = isCorrect;

      if (isCorrect) {
        final earned = _currentQuestion!.points * (_isJackpot ? 2 : 1);
        _totalScore += earned;
        _streakCount += 1;
        HapticFeedback.heavyImpact();
      } else {
        _streakCount = 0;
        HapticFeedback.vibrate();
      }
    });

    _saveScore();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isJackpot ? const Color(0xFFF59E0B) : const Color(0xFF334155),
            width: _isJackpot ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isJackpot
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                  : const Color(0xFF3B82F6).withValues(alpha: 0.2),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Arcade Cyberpunk K3
                _buildHeader(),

                // Slot Machine Wheels Section
                _buildSlotMachineBox(),

                // Question or Winner Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    children: [
                      if (_isSpinning) ...[
                        const SizedBox(height: 20),
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '🎰 Mengacak Kategori Tantangan K3...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else if (_currentQuestion != null) ...[
                        _buildQuestionCard(),
                      ],

                      const SizedBox(height: 16),

                      // Spin Button / Re-spin Button
                      _buildActionButtons(),
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

  /// Header mewah dengan NIK badge & skor
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.casino_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'LUCKY SAFETY SLOT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        widget.userNik,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Halo Pak ${widget.userName.split(' ').first} • Uji Ketangkasan K3',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          // Score Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded,
                    color: Color(0xFFF59E0B), size: 15),
                const SizedBox(width: 4),
                Text(
                  '$_totalScore',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF94A3B8), size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Mesin Slot 3 Reel dengan Efek Bezel Chrome & Marquee Lights
  Widget _buildSlotMachineBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isJackpot ? const Color(0xFFF59E0B) : const Color(0xFF475569),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Lampu LED Marquee atas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              8,
              (index) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSpinning
                      ? (index % 2 == 0
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981))
                      : const Color(0xFFF59E0B),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3 Roda Slot Reel
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildSingleReel(
                          _symbols[_reelIndex1], 'Reel 1', _isSpinning)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildSingleReel(
                          _symbols[_reelIndex2], 'Reel 2', _isSpinning)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildSingleReel(
                          _symbols[_reelIndex3], 'Reel 3', _isSpinning)),
                ],
              ),
              // Garis Payline / Garis Laser Kemenangan di Tengah
              IgnorePointer(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        (_isJackpot
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF06B6D4))
                            .withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isJackpot
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF06B6D4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Banner Status Hasil Putaran
          if (_isJackpot && !_isSpinning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '🎉 JACKPOT! 3X REEL MATCH (POIN x2)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else if (!_isSpinning && _hasSpunOnce)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _symbols[_reelIndex2].color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_symbols[_reelIndex2].icon,
                      color: _symbols[_reelIndex2].color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Kategori Terpilih: ${_symbols[_reelIndex2].title}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _symbols[_reelIndex2].color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Desain Reel Satuan dengan Inset 3D
  Widget _buildSingleReel(SlotSymbol symbol, String tag, bool isSpinning) {
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: symbol.color.withValues(alpha: 0.15),
              border: Border.all(
                color: symbol.color.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: symbol.color.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              symbol.icon,
              color: symbol.color,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            symbol.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isSpinning ? Colors.white60 : Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Soal Kuis K3 Interaktif
  Widget _buildQuestionCard() {
    final q = _currentQuestion!;
    final pointsEarned = q.points * (_isJackpot ? 2 : 1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Soal & Poin
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  q.category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF60A5FA),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded,
                      size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 3),
                  Text(
                    '+$pointsEarned Poin',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Pertanyaan
          Text(
            q.question,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // 4 Opsi Jawaban
          ...List.generate(q.options.length, (index) {
            final optionText = q.options[index];
            final isSelected = (_selectedAnswerIndex == index);
            final isCorrect = (index == q.correctIndex);

            Color bgColor = const Color(0xFF1E293B);
            Color borderColor = const Color(0xFF334155);
            Color textColor = const Color(0xFFE2E8F0);
            IconData? trailingIcon;

            if (_hasAnswered) {
              if (isCorrect) {
                bgColor = const Color(0xFF10B981).withValues(alpha: 0.2);
                borderColor = const Color(0xFF10B981);
                textColor = Colors.white;
                trailingIcon = Icons.check_circle_rounded;
              } else if (isSelected) {
                bgColor = const Color(0xFFEF4444).withValues(alpha: 0.2);
                borderColor = const Color(0xFFEF4444);
                textColor = Colors.white;
                trailingIcon = Icons.cancel_rounded;
              }
            }

            final optionLabel = String.fromCharCode(65 + index); // A, B, C, D

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _hasAnswered ? null : () => _answerQuestion(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? (_isAnswerCorrect
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444))
                                : const Color(0xFF334155),
                          ),
                          child: Text(
                            optionLabel,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            optionText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected || (_hasAnswered && isCorrect)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: textColor,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            trailingIcon,
                            size: 18,
                            color: isCorrect
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Box Penjelasan setelah menjawab
          if (_hasAnswered) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_isAnswerCorrect
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_isAnswerCorrect
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444))
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isAnswerCorrect
                        ? Icons.emoji_events_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: _isAnswerCorrect
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_isAnswerCorrect ? "Hebat, Jawaban Benar! 🎉" : "Kurang Tepat."} ${q.explanation}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isAnswerCorrect
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFECACA),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tombol Spin & Tindakan
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Tombol Putar Lagi / Putar Slot
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 6,
                shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSpinning ? null : _spinSlot,
              icon: _isSpinning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0F172A),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                _isSpinning
                    ? 'Sedang Memutar...'
                    : (_hasSpunOnce ? '🎰 Putar Slot Lagi' : '🎰 Putar Slot Sekarang'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Tombol Tutup
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
              side: const BorderSide(color: Color(0xFF334155)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Selesai',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

