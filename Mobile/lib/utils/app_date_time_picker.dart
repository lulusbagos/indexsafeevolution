import 'package:flutter/material.dart';

/// Helper terpusat untuk menampilkan dialog Date Picker dan Time Picker
/// dengan tampilan modern, corporate, dan standar tema IndexSafe MBS SAP.
class AppDateTimePicker {
  /// Warna tema standar IndexSafe
  static const Color primaryBlue = Color(0xFF1D4ED8); // Royal Blue
  static const Color navyDark = Color(0xFF1E3A8A); // Deep Navy
  static const Color slateText = Color(0xFF0F172A);
  static const Color slateSubtext = Color(0xFF64748B);
  static const Color surfaceBg = Colors.white;

  /// Global ThemeData untuk DatePicker
  static final DatePickerThemeData datePickerThemeData = DatePickerThemeData(
    backgroundColor: surfaceBg,
    surfaceTintColor: Colors.transparent,
    elevation: 16,
    shadowColor: const Color(0x330F172A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    headerBackgroundColor: navyDark,
    headerForegroundColor: Colors.white,
    headerHeadlineStyle: const TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    headerHelpStyle: const TextStyle(
      color: Color(0xFF93C5FD),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
    weekdayStyle: const TextStyle(
      color: slateSubtext,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    dayStyle: const TextStyle(
      color: slateText,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return const Color(0xFFCBD5E1);
      if (states.contains(WidgetState.selected)) return Colors.white;
      return slateText;
    }),
    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return primaryBlue;
      return Colors.transparent;
    }),
    todayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return primaryBlue;
    }),
    todayBorder: const BorderSide(color: primaryBlue, width: 1.5),
    yearStyle: const TextStyle(
      color: slateText,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    yearForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return slateText;
    }),
    yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return primaryBlue;
      return Colors.transparent;
    }),
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: slateSubtext,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    confirmButtonStyle: FilledButton.styleFrom(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
    ),
  );

  /// Global ThemeData untuk TimePicker
  static final TimePickerThemeData timePickerThemeData = TimePickerThemeData(
    backgroundColor: surfaceBg,
    elevation: 16,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    hourMinuteShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFDBEAFE), width: 1.2),
    ),
    hourMinuteColor: const Color(0xFFEFF6FF),
    hourMinuteTextColor: navyDark,
    hourMinuteTextStyle: const TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    dialBackgroundColor: const Color(0xFFF1F5F9),
    dialHandColor: primaryBlue,
    dialTextColor: slateText,
    dialTextStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    dayPeriodShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    dayPeriodColor: const Color(0xFFEFF6FF),
    dayPeriodTextColor: navyDark,
    dayPeriodTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    helpTextStyle: const TextStyle(
      color: navyDark,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    ),
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: slateSubtext,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    confirmButtonStyle: FilledButton.styleFrom(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
    ),
  );

  /// Tema dialog Date Picker modern & profesional dengan context
  static ThemeData getDatePickerTheme(BuildContext context) {
    final baseTheme = Theme.of(context);
    return baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: primaryBlue,
        onPrimary: Colors.white,
        surface: surfaceBg,
        onSurface: slateText,
      ),
      datePickerTheme: datePickerThemeData,
    );
  }

  /// Tema dialog Time Picker modern & profesional dengan context
  static ThemeData getTimePickerTheme(BuildContext context) {
    final baseTheme = Theme.of(context);
    return baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: primaryBlue,
        onPrimary: Colors.white,
        surface: surfaceBg,
        onSurface: slateText,
      ),
      timePickerTheme: timePickerThemeData,
    );
  }

  /// Menampilkan Date Picker profesional dengan batasan backdate (default maks 3 hari terakhir)
  static Future<DateTime?> showDatePickerDialog({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
    bool restrict3DaysBack = true,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final calculatedFirstDate = firstDate ??
        (restrict3DaysBack
            ? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 3))
            : DateTime(now.year - 1));

    final calculatedLastDate = lastDate ?? today;

    var cur = initialDate ?? now;
    if (cur.isBefore(calculatedFirstDate)) cur = calculatedFirstDate;
    if (cur.isAfter(calculatedLastDate)) cur = calculatedLastDate;

    return showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: calculatedFirstDate,
      lastDate: calculatedLastDate,
      helpText: helpText ?? (restrict3DaysBack ? 'PILIH TANGGAL (MAKS. 3 HARI TERAKHIR)' : 'PILIH TANGGAL'),
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (ctx, child) {
        return Theme(
          data: getDatePickerTheme(ctx),
          child: child ?? const SizedBox(),
        );
      },
    );
  }

  /// Menampilkan Time Picker profesional
  static Future<TimeOfDay?> showTimePickerDialog({
    required BuildContext context,
    TimeOfDay? initialTime,
    String? helpText,
  }) async {
    return showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      helpText: helpText ?? 'PILIH WAKTU KEGIATAN',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (ctx, child) {
        return Theme(
          data: getTimePickerTheme(ctx),
          child: child ?? const SizedBox(),
        );
      },
    );
  }

  /// Format tanggal Indonesia ramah pengguna: "Rabu, 04 Nov 2026"
  static String formatIndonesianDate(DateTime date, {bool includeDayName = false}) {
    const hari = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const bulan = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = bulan[date.month];
    final yearStr = date.year.toString();

    if (includeDayName) {
      final hariStr = hari[date.weekday % 7];
      return '$hariStr, $dayStr $monthStr $yearStr';
    }
    return '$dayStr $monthStr $yearStr';
  }
}

/// Widget Card Pemilih Tanggal Modern untuk Form
class ModernDateSelectorTile extends StatelessWidget {
  const ModernDateSelectorTile({
    required this.date,
    required this.onTap,
    this.label = 'Tanggal Kegiatan',
    this.badgeText = 'Maks. H-3',
    this.accentColor = const Color(0xFF1D4ED8),
    this.showDayName = false,
    super.key,
  });

  final DateTime date;
  final VoidCallback onTap;
  final String label;
  final String? badgeText;
  final Color accentColor;
  final bool showDayName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.calendar_month_rounded, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFDBEAFE), width: 0.8),
                          ),
                          child: Text(
                            badgeText!,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppDateTimePicker.formatIndonesianDate(date, includeDayName: showDayName),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

/// Widget Card Pemilih Waktu Modern untuk Form
class ModernTimeSelectorTile extends StatelessWidget {
  const ModernTimeSelectorTile({
    required this.timeText,
    required this.onTap,
    this.label = 'Jam Kegiatan',
    this.accentColor = const Color(0xFF1D4ED8),
    this.zoneSuffix = 'WITA',
    super.key,
  });

  final String timeText;
  final VoidCallback onTap;
  final String label;
  final Color accentColor;
  final String? zoneSuffix;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.schedule_rounded, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        timeText,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (zoneSuffix != null && zoneSuffix!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          zoneSuffix!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
