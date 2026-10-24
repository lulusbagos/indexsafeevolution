import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/profile_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../utils/routers.dart';
import '../../widgets/top_bar.dart';
import '../safety_updates_page.dart';
import 'department_employee_league_page.dart';

export 'sap_quality_page.dart';
export 'action_tracker_page.dart';
export 'department_employee_league_page.dart';
export 'dpa_page.dart';
export '../safety_updates_page.dart';

class AchievementSapPage extends StatefulWidget {
  final int initialTabIndex;
  const AchievementSapPage({super.key, this.initialTabIndex = 0});

  @override
  State<AchievementSapPage> createState() => _AchievementSapPageState();
}

class _AchievementSapPageState extends State<AchievementSapPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  ProfileModel? _profile = PreferenceService.getProfile();
  late TabController _tabController;

  bool _isRefreshing = false;
  bool _isLoadingLeague = false;
  List<Map<String, dynamic>> _departments = List.from(_defaultCuratedDepts);
  String _leaguePeriod = 'Oktober 2026';
  int _totalClubs = _defaultCuratedDepts.length;
  String _companyName = 'PT INDEXIM COALINDO';
  String _searchQuery = '';
  final Set<String> _expandedDepts = {};

  static final List<Map<String, dynamic>> _defaultCuratedDepts = [
    {
      'rank': 1,
      'departmentName': 'SHIPLOADER & PORT OPERATION',
      'initials': 'SP',
      'shieldColor': '#991b1b',
      'employeeCount': 11,
      'totalScore': 88.71,
      'mtdAchievementRate': 91.9,
      'mtdCloseRate': 100.0,
      'mtdHazardRate': 90.4,
      'mtdInspeksiRate': 90.2,
      'mtdSafetyTalkRate': 93.8,
      'mtdObservasiRate': 93.4,
      'mtdCoachingRate': 93.3,
      'mtdP5mRate': 100.0,
      'ptsClose': 30.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 32.17,
      'ptsBeban': 1.54,
      'hazardActual': 94, 'hazardTarget': 104,
      'inspeksiActual': 46, 'inspeksiTarget': 51,
      'safetyTalkActual': 197, 'safetyTalkTarget': 210,
      'observasiActual': 42, 'observasiTarget': 45,
      'coachingActual': 28, 'coachingTarget': 30,
      'p5mActual': 80, 'p5mTarget': 80,
      'apTotal': 15, 'apClosed': 15,
    },
    {
      'rank': 2,
      'departmentName': 'MINING SURVEYOR',
      'initials': 'MS',
      'shieldColor': '#0d9488',
      'employeeCount': 11,
      'totalScore': 86.49,
      'mtdAchievementRate': 82.8,
      'mtdCloseRate': 100.0,
      'mtdHazardRate': 81.4,
      'mtdInspeksiRate': 81.2,
      'mtdSafetyTalkRate': 81.5,
      'mtdObservasiRate': 87.5,
      'mtdCoachingRate': 78.6,
      'mtdP5mRate': 81.8,
      'ptsClose': 30.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 28.98,
      'ptsBeban': 2.51,
      'hazardActual': 79, 'hazardTarget': 97,
      'inspeksiActual': 39, 'inspeksiTarget': 48,
      'safetyTalkActual': 163, 'safetyTalkTarget': 200,
      'observasiActual': 35, 'observasiTarget': 40,
      'coachingActual': 22, 'coachingTarget': 28,
      'p5mActual': 59, 'p5mTarget': 67,
      'apTotal': 8, 'apClosed': 8,
    },
    {
      'rank': 3,
      'departmentName': 'NORTH BLOCK & JOIN OPERATION',
      'initials': 'NB',
      'shieldColor': '#15803d',
      'employeeCount': 11,
      'totalScore': 85.03,
      'mtdAchievementRate': 76.0,
      'mtdCloseRate': 100.0,
      'mtdHazardRate': 83.3,
      'mtdInspeksiRate': 74.4,
      'mtdSafetyTalkRate': 71.4,
      'mtdObservasiRate': 69.2,
      'mtdCoachingRate': 90.9,
      'mtdP5mRate': 90.9,
      'ptsClose': 30.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 26.60,
      'ptsBeban': 3.43,
      'hazardActual': 80, 'hazardTarget': 96,
      'inspeksiActual': 32, 'inspeksiTarget': 43,
      'safetyTalkActual': 145, 'safetyTalkTarget': 203,
      'observasiActual': 27, 'observasiTarget': 39,
      'coachingActual': 20, 'coachingTarget': 22,
      'p5mActual': 72, 'p5mTarget': 92,
      'apTotal': 12, 'apClosed': 12,
    },
    {
      'rank': 4,
      'departmentName': 'EXPLORATION',
      'initials': 'EX',
      'shieldColor': '#7c3aed',
      'employeeCount': 59,
      'totalScore': 84.51,
      'mtdAchievementRate': 71.9,
      'mtdCloseRate': 97.2,
      'mtdHazardRate': 76.2,
      'mtdInspeksiRate': 64.9,
      'mtdSafetyTalkRate': 68.6,
      'mtdObservasiRate': 70.1,
      'mtdCoachingRate': 93.1,
      'mtdP5mRate': 91.5,
      'ptsClose': 29.16,
      'ptsKualitas': 25.00,
      'ptsCapaian': 25.17,
      'ptsBeban': 5.18,
      'hazardActual': 419, 'hazardTarget': 550,
      'inspeksiActual': 179, 'inspeksiTarget': 276,
      'safetyTalkActual': 741, 'safetyTalkTarget': 1080,
      'observasiActual': 164, 'observasiTarget': 234,
      'coachingActual': 108, 'coachingTarget': 116,
      'p5mActual': 294, 'p5mTarget': 394,
      'apTotal': 36, 'apClosed': 35,
    },
    {
      'rank': 5,
      'departmentName': 'SYSTEM INTEGRATIONS',
      'initials': 'SI',
      'shieldColor': '#059669',
      'employeeCount': 6,
      'totalScore': 83.42,
      'mtdAchievementRate': 68.8,
      'mtdCloseRate': 100.0,
      'mtdHazardRate': 50.0,
      'mtdInspeksiRate': 50.0,
      'mtdSafetyTalkRate': 75.0,
      'mtdObservasiRate': 70.0,
      'mtdCoachingRate': 100.0,
      'mtdP5mRate': 16.7,
      'ptsClose': 30.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 24.08,
      'ptsBeban': 4.34,
      'hazardActual': 26, 'hazardTarget': 52,
      'inspeksiActual': 13, 'inspeksiTarget': 26,
      'safetyTalkActual': 81, 'safetyTalkTarget': 108,
      'observasiActual': 14, 'observasiTarget': 20,
      'coachingActual': 12, 'coachingTarget': 12,
      'p5mActual': 40, 'p5mTarget': 52,
      'apTotal': 6, 'apClosed': 6,
    },
    {
      'rank': 6,
      'departmentName': 'LEGAL & LICENSING',
      'initials': 'LL',
      'shieldColor': '#b91c1c',
      'employeeCount': 10,
      'totalScore': 83.09,
      'mtdAchievementRate': 76.1,
      'mtdCloseRate': 100.0,
      'mtdHazardRate': 60.0,
      'mtdInspeksiRate': 75.0,
      'mtdSafetyTalkRate': 69.6,
      'mtdObservasiRate': 91.7,
      'mtdCoachingRate': 90.0,
      'mtdP5mRate': 70.0,
      'ptsClose': 30.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 26.64,
      'ptsBeban': 1.45,
      'hazardActual': 54, 'hazardTarget': 90,
      'inspeksiActual': 33, 'inspeksiTarget': 44,
      'safetyTalkActual': 126, 'safetyTalkTarget': 181,
      'observasiActual': 33, 'observasiTarget': 36,
      'coachingActual': 18, 'coachingTarget': 20,
      'p5mActual': 78, 'p5mTarget': 79,
      'apTotal': 5, 'apClosed': 5,
    },
    {
      'rank': 7,
      'departmentName': 'COAL LABORATORY',
      'initials': 'CL',
      'shieldColor': '#92400e',
      'employeeCount': 24,
      'totalScore': 81.77,
      'mtdAchievementRate': 78.7,
      'mtdCloseRate': 84.8,
      'mtdHazardRate': 72.7,
      'mtdInspeksiRate': 91.4,
      'mtdSafetyTalkRate': 73.3,
      'mtdObservasiRate': 75.9,
      'mtdCoachingRate': 82.6,
      'mtdP5mRate': 91.7,
      'ptsClose': 25.44,
      'ptsKualitas': 25.00,
      'ptsCapaian': 27.55,
      'ptsBeban': 3.78,
      'hazardActual': 152, 'hazardTarget': 209,
      'inspeksiActual': 95, 'inspeksiTarget': 104,
      'safetyTalkActual': 318, 'safetyTalkTarget': 434,
      'observasiActual': 70, 'observasiTarget': 92,
      'coachingActual': 38, 'coachingTarget': 46,
      'p5mActual': 177, 'p5mTarget': 195,
      'apTotal': 33, 'apClosed': 28,
    },
    {
      'rank': 8,
      'departmentName': 'SECURITY',
      'initials': 'SE',
      'shieldColor': '#1e40af',
      'employeeCount': 8,
      'totalScore': 81.08,
      'mtdAchievementRate': 80.6,
      'mtdCloseRate': 83.9,
      'mtdHazardRate': 90.5,
      'mtdInspeksiRate': 69.6,
      'mtdSafetyTalkRate': 82.6,
      'mtdObservasiRate': 78.3,
      'mtdCoachingRate': 87.5,
      'mtdP5mRate': 100.0,
      'ptsClose': 25.17,
      'ptsKualitas': 25.00,
      'ptsCapaian': 28.21,
      'ptsBeban': 2.70,
      'hazardActual': 67, 'hazardTarget': 74,
      'inspeksiActual': 25, 'inspeksiTarget': 36,
      'safetyTalkActual': 119, 'safetyTalkTarget': 144,
      'observasiActual': 25, 'observasiTarget': 32,
      'coachingActual': 14, 'coachingTarget': 16,
      'p5mActual': 40, 'p5mTarget': 58,
      'apTotal': 31, 'apClosed': 26,
    },
    {
      'rank': 9,
      'departmentName': 'FIXED PLANT',
      'initials': 'FP',
      'shieldColor': '#3f6212',
      'employeeCount': 70,
      'totalScore': 81.07,
      'mtdAchievementRate': 69.8,
      'mtdCloseRate': 87.4,
      'mtdHazardRate': 60.8,
      'mtdInspeksiRate': 74.6,
      'mtdSafetyTalkRate': 62.1,
      'mtdObservasiRate': 76.8,
      'mtdCoachingRate': 82.8,
      'mtdP5mRate': 78.6,
      'ptsClose': 26.22,
      'ptsKualitas': 25.00,
      'ptsCapaian': 24.43,
      'ptsBeban': 5.42,
      'hazardActual': 395, 'hazardTarget': 650,
      'inspeksiActual': 242, 'inspeksiTarget': 324,
      'safetyTalkActual': 801, 'safetyTalkTarget': 1290,
      'observasiActual': 215, 'observasiTarget': 280,
      'coachingActual': 116, 'coachingTarget': 140,
      'p5mActual': 431, 'p5mTarget': 466,
      'apTotal': 87, 'apClosed': 76,
    },
    {
      'rank': 10,
      'departmentName': 'COMPLIANCE & CONTROL',
      'initials': 'CC',
      'shieldColor': '#0369a1',
      'employeeCount': 6,
      'totalScore': 79.81,
      'mtdAchievementRate': 69.6,
      'mtdCloseRate': 100.0,
      'mtdHazardRate': 66.7,
      'mtdInspeksiRate': 55.6,
      'mtdSafetyTalkRate': 68.8,
      'mtdObservasiRate': 77.8,
      'mtdCoachingRate': 83.3,
      'mtdP5mRate': 100.0,
      'ptsClose': 30.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 24.36,
      'ptsBeban': 0.45,
      'hazardActual': 36, 'hazardTarget': 54,
      'inspeksiActual': 15, 'inspeksiTarget': 27,
      'safetyTalkActual': 77, 'safetyTalkTarget': 112,
      'observasiActual': 14, 'observasiTarget': 18,
      'coachingActual': 10, 'coachingTarget': 12,
      'p5mActual': 36, 'p5mTarget': 47,
      'apTotal': 4, 'apClosed': 4,
    },
    {
      'rank': 11,
      'departmentName': 'OCCUPATIONAL, HEALTH & SAFETY',
      'initials': 'OH',
      'shieldColor': '#be123c',
      'employeeCount': 27,
      'totalScore': 77.42,
      'mtdAchievementRate': 77.1,
      'mtdCloseRate': 71.4,
      'mtdHazardRate': 77.8,
      'mtdInspeksiRate': 73.5,
      'mtdSafetyTalkRate': 75.3,
      'mtdObservasiRate': 76.5,
      'mtdCoachingRate': 92.0,
      'mtdP5mRate': 77.8,
      'ptsClose': 21.42,
      'ptsKualitas': 25.00,
      'ptsCapaian': 26.99,
      'ptsBeban': 4.01,
      'hazardActual': 189, 'hazardTarget': 243,
      'inspeksiActual': 89, 'inspeksiTarget': 121,
      'safetyTalkActual': 366, 'safetyTalkTarget': 486,
      'observasiActual': 85, 'observasiTarget': 111,
      'coachingActual': 48, 'coachingTarget': 52,
      'p5mActual': 160, 'p5mTarget': 202,
      'apTotal': 28, 'apClosed': 20,
    },
    {
      'rank': 12,
      'departmentName': 'PROCUREMENT & LOGISTIC',
      'initials': 'PL',
      'shieldColor': '#0284c7',
      'employeeCount': 16,
      'totalScore': 75.28,
      'mtdAchievementRate': 53.8,
      'mtdCloseRate': 100.0,
      'mtdHazardRate': 21.9,
      'mtdInspeksiRate': 69.7,
      'mtdSafetyTalkRate': 69.7,
      'mtdObservasiRate': 48.5,
      'mtdCoachingRate': 64.3,
      'mtdP5mRate': 81.2,
      'ptsClose': 30.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 18.83,
      'ptsBeban': 1.45,
      'hazardActual': 31, 'hazardTarget': 144,
      'inspeksiActual': 51, 'inspeksiTarget': 73,
      'safetyTalkActual': 201, 'safetyTalkTarget': 288,
      'observasiActual': 31, 'observasiTarget': 64,
      'coachingActual': 18, 'coachingTarget': 28,
      'p5mActual': 55, 'p5mTarget': 123,
      'apTotal': 14, 'apClosed': 14,
    },
    {
      'rank': 13,
      'departmentName': 'BUILDING & LV MAINTENANCE',
      'initials': 'BL',
      'shieldColor': '#4d7c0f',
      'employeeCount': 14,
      'totalScore': 72.56,
      'mtdAchievementRate': 65.1,
      'mtdCloseRate': 79.1,
      'mtdHazardRate': 55.6,
      'mtdInspeksiRate': 66.7,
      'mtdSafetyTalkRate': 61.0,
      'mtdObservasiRate': 71.8,
      'mtdCoachingRate': 78.6,
      'mtdP5mRate': 78.6,
      'ptsClose': 23.73,
      'ptsKualitas': 25.00,
      'ptsCapaian': 22.79,
      'ptsBeban': 1.04,
      'hazardActual': 70, 'hazardTarget': 126,
      'inspeksiActual': 42, 'inspeksiTarget': 63,
      'safetyTalkActual': 154, 'safetyTalkTarget': 252,
      'observasiActual': 39, 'observasiTarget': 54,
      'coachingActual': 22, 'coachingTarget': 28,
      'p5mActual': 83, 'p5mTarget': 107,
      'apTotal': 43, 'apClosed': 34,
    },
    {
      'rank': 14,
      'departmentName': 'MINING ENGINEERING SOUTH',
      'initials': 'ME',
      'shieldColor': '#9f1239',
      'employeeCount': 13,
      'totalScore': 71.91,
      'mtdAchievementRate': 83.3,
      'mtdCloseRate': 50.0,
      'mtdHazardRate': 76.0,
      'mtdInspeksiRate': 88.2,
      'mtdSafetyTalkRate': 82.4,
      'mtdObservasiRate': 82.4,
      'mtdCoachingRate': 94.1,
      'mtdP5mRate': 100.0,
      'ptsClose': 15.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 29.16,
      'ptsBeban': 2.75,
      'hazardActual': 89, 'hazardTarget': 117,
      'inspeksiActual': 52, 'inspeksiTarget': 59,
      'safetyTalkActual': 193, 'safetyTalkTarget': 234,
      'observasiActual': 43, 'observasiTarget': 52,
      'coachingActual': 24, 'coachingTarget': 26,
      'p5mActual': 86, 'p5mTarget': 97,
      'apTotal': 6, 'apClosed': 3,
    },
    {
      'rank': 15,
      'departmentName': 'COAL CHAIN MANAGEMENT',
      'initials': 'CC',
      'shieldColor': '#15803d',
      'employeeCount': 37,
      'totalScore': 69.09,
      'mtdAchievementRate': 74.1,
      'mtdCloseRate': 47.1,
      'mtdHazardRate': 71.9,
      'mtdInspeksiRate': 70.5,
      'mtdSafetyTalkRate': 68.5,
      'mtdObservasiRate': 82.1,
      'mtdCoachingRate': 82.9,
      'mtdP5mRate': 83.8,
      'ptsClose': 14.13,
      'ptsKualitas': 25.00,
      'ptsCapaian': 25.94,
      'ptsBeban': 4.02,
      'hazardActual': 239, 'hazardTarget': 333,
      'inspeksiActual': 117, 'inspeksiTarget': 166,
      'safetyTalkActual': 456, 'safetyTalkTarget': 666,
      'observasiActual': 121, 'observasiTarget': 148,
      'coachingActual': 61, 'coachingTarget': 74,
      'p5mActual': 240, 'p5mTarget': 278,
      'apTotal': 17, 'apClosed': 8,
    },
    {
      'rank': 16,
      'departmentName': 'FINANCE, ACCOUNTING & IT',
      'initials': 'FA',
      'shieldColor': '#1e3a8a',
      'employeeCount': 11,
      'totalScore': 68.09,
      'mtdAchievementRate': 80.3,
      'mtdCloseRate': 50.0,
      'mtdHazardRate': 90.0,
      'mtdInspeksiRate': 78.6,
      'mtdSafetyTalkRate': 75.0,
      'mtdObservasiRate': 78.6,
      'mtdCoachingRate': 90.0,
      'mtdP5mRate': 90.9,
      'ptsClose': 15.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 28.11,
      'ptsBeban': -0.02,
      'hazardActual': 89, 'hazardTarget': 99,
      'inspeksiActual': 39, 'inspeksiTarget': 50,
      'safetyTalkActual': 149, 'safetyTalkTarget': 198,
      'observasiActual': 34, 'observasiTarget': 43,
      'coachingActual': 20, 'coachingTarget': 22,
      'p5mActual': 66, 'p5mTarget': 83,
      'apTotal': 4, 'apClosed': 2,
    },
    {
      'rank': 17,
      'departmentName': 'CORPORATE SOCIAL RESPONSIBILITY (CSR)',
      'initials': 'CS',
      'shieldColor': '#047857',
      'employeeCount': 19,
      'totalScore': 67.95,
      'mtdAchievementRate': 82.9,
      'mtdCloseRate': 42.9,
      'mtdHazardRate': 100.0,
      'mtdInspeksiRate': 89.3,
      'mtdSafetyTalkRate': 67.9,
      'mtdObservasiRate': 92.9,
      'mtdCoachingRate': 88.2,
      'mtdP5mRate': 78.9,
      'ptsClose': 12.87,
      'ptsKualitas': 25.00,
      'ptsCapaian': 29.02,
      'ptsBeban': 1.06,
      'hazardActual': 171, 'hazardTarget': 171,
      'inspeksiActual': 76, 'inspeksiTarget': 85,
      'safetyTalkActual': 232, 'safetyTalkTarget': 342,
      'observasiActual': 71, 'observasiTarget': 76,
      'coachingActual': 33, 'coachingTarget': 37,
      'p5mActual': 126, 'p5mTarget': 144,
      'apTotal': 7, 'apClosed': 3,
    },
    {
      'rank': 18,
      'departmentName': 'ENVIRONMENTAL',
      'initials': 'EN',
      'shieldColor': '#065f46',
      'employeeCount': 20,
      'totalScore': 67.78,
      'mtdAchievementRate': 79.1,
      'mtdCloseRate': 38.5,
      'mtdHazardRate': 73.6,
      'mtdInspeksiRate': 81.8,
      'mtdSafetyTalkRate': 69.6,
      'mtdObservasiRate': 87.3,
      'mtdCoachingRate': 90.0,
      'mtdP5mRate': 95.0,
      'ptsClose': 11.55,
      'ptsKualitas': 25.00,
      'ptsCapaian': 27.69,
      'ptsBeban': 3.54,
      'hazardActual': 132, 'hazardTarget': 180,
      'inspeksiActual': 74, 'inspeksiTarget': 90,
      'safetyTalkActual': 251, 'safetyTalkTarget': 360,
      'observasiActual': 70, 'observasiTarget': 80,
      'coachingActual': 36, 'coachingTarget': 40,
      'p5mActual': 149, 'p5mTarget': 150,
      'apTotal': 13, 'apClosed': 5,
    },
    {
      'rank': 19,
      'departmentName': 'HUMAN CAPITAL & GENERAL SERVICES',
      'initials': 'HC',
      'shieldColor': '#334155',
      'employeeCount': 32,
      'totalScore': 67.45,
      'mtdAchievementRate': 69.0,
      'mtdCloseRate': 59.0,
      'mtdHazardRate': 68.5,
      'mtdInspeksiRate': 72.1,
      'mtdSafetyTalkRate': 67.8,
      'mtdObservasiRate': 71.4,
      'mtdCoachingRate': 78.0,
      'mtdP5mRate': 75.0,
      'ptsClose': 17.70,
      'ptsKualitas': 25.00,
      'ptsCapaian': 24.15,
      'ptsBeban': 0.60,
      'hazardActual': 197, 'hazardTarget': 288,
      'inspeksiActual': 104, 'inspeksiTarget': 144,
      'safetyTalkActual': 389, 'safetyTalkTarget': 576,
      'observasiActual': 91, 'observasiTarget': 128,
      'coachingActual': 50, 'coachingTarget': 64,
      'p5mActual': 163, 'p5mTarget': 240,
      'apTotal': 78, 'apClosed': 46,
    },
    {
      'rank': 20,
      'departmentName': 'MINING PRODUCTION',
      'initials': 'MP',
      'shieldColor': '#b45309',
      'employeeCount': 21,
      'totalScore': 65.17,
      'mtdAchievementRate': 66.0,
      'mtdCloseRate': 51.9,
      'mtdHazardRate': 64.2,
      'mtdInspeksiRate': 68.5,
      'mtdSafetyTalkRate': 62.1,
      'mtdObservasiRate': 69.8,
      'mtdCoachingRate': 73.0,
      'mtdP5mRate': 71.4,
      'ptsClose': 15.57,
      'ptsKualitas': 25.00,
      'ptsCapaian': 23.10,
      'ptsBeban': 1.50,
      'hazardActual': 121, 'hazardTarget': 189,
      'inspeksiActual': 65, 'inspeksiTarget': 95,
      'safetyTalkActual': 235, 'safetyTalkTarget': 378,
      'observasiActual': 59, 'observasiTarget': 84,
      'coachingActual': 31, 'coachingTarget': 42,
      'p5mActual': 113, 'p5mTarget': 157,
      'apTotal': 27, 'apClosed': 14,
    },
    {
      'rank': 21,
      'departmentName': 'GEOTECHNICAL, HYDROLOGY & PIT PROJECT DEVELOPMENT',
      'initials': 'GH',
      'shieldColor': '#0284c7',
      'employeeCount': 14,
      'totalScore': 62.15,
      'mtdAchievementRate': 63.0,
      'mtdCloseRate': 40.0,
      'mtdHazardRate': 61.2,
      'mtdInspeksiRate': 64.8,
      'mtdSafetyTalkRate': 60.5,
      'mtdObservasiRate': 66.7,
      'mtdCoachingRate': 71.4,
      'mtdP5mRate': 67.9,
      'ptsClose': 12.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 22.05,
      'ptsBeban': 3.10,
      'hazardActual': 77, 'hazardTarget': 126,
      'inspeksiActual': 41, 'inspeksiTarget': 63,
      'safetyTalkActual': 152, 'safetyTalkTarget': 252,
      'observasiActual': 37, 'observasiTarget': 56,
      'coachingActual': 20, 'coachingTarget': 28,
      'p5mActual': 70, 'p5mTarget': 105,
      'apTotal': 5, 'apClosed': 2,
    },
    {
      'rank': 22,
      'departmentName': 'SITE MANAGEMENT',
      'initials': 'SM',
      'shieldColor': '#475569',
      'employeeCount': 9,
      'totalScore': 60.09,
      'mtdAchievementRate': 58.0,
      'mtdCloseRate': 45.8,
      'mtdHazardRate': 55.6,
      'mtdInspeksiRate': 60.0,
      'mtdSafetyTalkRate': 56.4,
      'mtdObservasiRate': 61.1,
      'mtdCoachingRate': 66.7,
      'mtdP5mRate': 63.0,
      'ptsClose': 13.74,
      'ptsKualitas': 25.00,
      'ptsCapaian': 20.30,
      'ptsBeban': 1.05,
      'hazardActual': 45, 'hazardTarget': 81,
      'inspeksiActual': 24, 'inspeksiTarget': 40,
      'safetyTalkActual': 91, 'safetyTalkTarget': 162,
      'observasiActual': 22, 'observasiTarget': 36,
      'coachingActual': 12, 'coachingTarget': 18,
      'p5mActual': 41, 'p5mTarget': 68,
      'apTotal': 24, 'apClosed': 11,
    },
    {
      'rank': 23,
      'departmentName': 'SHIPPING & PORT',
      'initials': 'SP',
      'shieldColor': '#0284c7',
      'employeeCount': 4,
      'totalScore': 57.32,
      'mtdAchievementRate': 48.0,
      'mtdCloseRate': 50.0,
      'mtdHazardRate': 60.0,
      'mtdInspeksiRate': 50.0,
      'mtdSafetyTalkRate': 50.0,
      'mtdObservasiRate': 38.5,
      'mtdCoachingRate': 28.6,
      'mtdP5mRate': 40.0,
      'ptsClose': 15.00,
      'ptsKualitas': 25.00,
      'ptsCapaian': 16.80,
      'ptsBeban': 0.52,
      'hazardActual': 15, 'hazardTarget': 25,
      'inspeksiActual': 13, 'inspeksiTarget': 26,
      'safetyTalkActual': 8, 'safetyTalkTarget': 16,
      'observasiActual': 10, 'observasiTarget': 26,
      'coachingActual': 2, 'coachingTarget': 7,
      'p5mActual': 12, 'p5mTarget': 30,
      'apTotal': 2, 'apClosed': 1,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    if (_profile?.company != null && _profile!.company!.isNotEmpty) {
      _companyName = _profile!.company!;
    }
    // Jika user bukan dari Indexim (companyId != 1), jangan tampilkan default Indexim,
    // biarkan list kosong sementara menunggu respons dari API perusahaannya
    if (_profile?.companyId != null && _profile!.companyId != 1) {
      _departments = [];
      _totalClubs = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _loadDepartmentLeague();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final res = await _api.getProfile();
      res.fold((error) {
        debugPrint('Error fetching profile for AchievementSapPage: ${error['message']}');
      }, (profile) async {
        await PreferenceService.setProfile(profile);
        if (mounted) {
          final isCompanyChanged = _profile?.companyId != profile.companyId;
          setState(() {
            _profile = profile;
            if (profile.company != null && profile.company!.isNotEmpty) {
              _companyName = profile.company!;
            }
          });
          // Muat ulang klasemen departemen jika profil/perusahaan baru diperbarui
          if (isCompanyChanged) {
            _loadDepartmentLeague();
          }
        }
      });
    } catch (e) {
      debugPrint('Exception in AchievementSapPage._loadProfile: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadDepartmentLeague() async {
    if (_isLoadingLeague) return;
    setState(() => _isLoadingLeague = true);
    try {
      final now = DateTime.now();
      final compId = _profile?.companyId ?? 1;
      final res = await _api.getDepartmentLeague(year: now.year, month: now.month, companyId: compId);
      res.fold((err) {
        debugPrint('Error fetching department league: ${err['message']}');
        _fallbackToCuratedLeague();
      }, (data) {
        final rawData = data['data'];
        if (rawData is Map) {
          final list = rawData['departments'];
          if (list is List && list.isNotEmpty) {
            if (mounted) {
              setState(() {
                _departments = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                _leaguePeriod = rawData['period']?.toString() ?? 'Oktober 2026';
                if (rawData['companyName'] != null && rawData['companyName'].toString().isNotEmpty) {
                  _companyName = rawData['companyName'].toString();
                }
                _totalClubs = (rawData['totalClubs'] is int)
                    ? rawData['totalClubs'] as int
                    : _departments.length;
              });
            }
            return;
          }
        }
        _fallbackToCuratedLeague();
      });
    } catch (e) {
      debugPrint('Exception in _loadDepartmentLeague: $e');
      _fallbackToCuratedLeague();
    } finally {
      if (mounted) setState(() => _isLoadingLeague = false);
    }
  }

  void _fallbackToCuratedLeague() {
    if (mounted) {
      setState(() {
        if (_profile == null || _profile?.companyId == 1) {
          _departments = List.from(_defaultCuratedDepts);
          _totalClubs = _defaultCuratedDepts.length;
        }
      });
    }
  }

  String _getDeptInitials(String name) {
    if (name.isEmpty) return 'GEN';
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return (clean.length >= 2 ? clean.substring(0, 2) : clean).toUpperCase();
  }

  Color _getDeptColor(String name) {
    if (name.isEmpty) return const Color(0xFF1E3A8A);
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    const colors = [
      Color(0xFF1E3A8A),
      Color(0xFFB91C1C),
      Color(0xFF047857),
      Color(0xFF6D28D9),
      Color(0xFFA21CAF),
      Color(0xFFC2410C),
      Color(0xFF0369A1),
      Color(0xFF15803D),
      Color(0xFFBE123C),
      Color(0xFF4D7C0F),
    ];
    final idx = hash.abs() % colors.length;
    return colors[idx];
  }

  Color _getRateColor(double rate) {
    if (rate < 0) return const Color(0xFF64748B);
    if (rate >= 80) return const Color(0xFF16A34A); // Hijau Patuh
    if (rate >= 40) return const Color(0xFFDC2626); // Merah Perhatian
    return const Color(0xFF0F172A); // Hitam Degradasi
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(
        title: 'Pencapaian SAP',
      ),
      body: Column(
        children: [
          // TAB BAR MODERN (Pencapaian Saya vs Urutan Departemen)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF0F172A),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_pin_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Capaian Saya'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Urutan Departemen'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // TAB CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIndividualTab(),
                _buildDepartmentLeagueTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: PENCAPAIAN SAYA (BERAPA PERSEN & MODUL)
  // ==========================================
  Widget _buildIndividualTab() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final periodStr = '1 - $lastDay ${months[now.month]} ${now.year}';

    final depart = _profile?.depart?.trim() ?? 'Operasional Tambang';
    final nik = _profile?.noNik?.trim() ?? '-';
    final nama = _profile?.namaLengkap?.trim() ?? 'Karyawan Indexsafe';

    // Modul 1: Hazard Report
    final int targetHazard = _profile?.targetHazardReport ?? 0;
    final int actualHazard = _profile?.myHazards ?? 0;

    // Modul 2: Inspeksi K3
    final int targetInspeksi = _profile?.targetInspeksi ?? 0;
    final int actualInspeksi = _profile?.myInspections ?? 0;

    // Modul 3: Safety Talk
    final int targetSafetyTalk = _profile?.targetSafetyTalk ?? 0;
    final int actualSafetyTalk = _profile?.mySafetyTalks ?? 0;

    // Modul 4: Observasi / BBS
    final int targetObservasi = _profile?.targetObservasi ?? 0;
    final int actualObservasi = _profile?.myObservasi ?? 0;

    // Modul 5: Coaching
    final int targetCoaching = _profile?.targetCoaching ?? 0;
    final int actualCoaching = _profile?.myCoaching ?? 0;

    // Modul 6: P5M
    final int targetP5m = _profile?.targetP5m ?? 0;
    final int actualP5m = _profile?.myP5ms ?? 0;

    final int totalTarget = _profile?.totalTarget ??
        (targetHazard + targetInspeksi + targetSafetyTalk + targetObservasi + targetCoaching + targetP5m);

    final int totalActualCapped =
        (actualHazard > targetHazard ? targetHazard : actualHazard) +
        (actualInspeksi > targetInspeksi ? targetInspeksi : actualInspeksi) +
        (actualSafetyTalk > targetSafetyTalk ? targetSafetyTalk : actualSafetyTalk) +
        (actualObservasi > targetObservasi ? targetObservasi : actualObservasi) +
        (actualCoaching > targetCoaching ? targetCoaching : actualCoaching) +
        (actualP5m > targetP5m ? targetP5m : actualP5m);

    final int totalSubmissions =
        actualHazard + actualInspeksi + actualSafetyTalk + actualObservasi + actualCoaching + actualP5m;

    final double complianceRate = _profile?.complianceRate != null && _profile!.complianceRate! > 0
        ? _profile!.complianceRate!
        : (totalTarget > 0 ? ((totalActualCapped / totalTarget) * 100) : 100.0);

    final bool isCompliant = complianceRate >= 100;
    final Color statusColor = isCompliant
        ? const Color(0xFF10B981)
        : (complianceRate >= 75 ? const Color(0xFF009688) : const Color(0xFFF59E0B));

    final int sisaTarget = (totalTarget - totalActualCapped).clamp(0, 999);

    return RefreshIndicator(
      color: const Color(0xFF009688),
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // COMPACT CONTEXT HEADER (Departemen & Periode Berjalan - Tanpa Full Profile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.corporate_fare_rounded, size: 18, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          depart.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$nama • NIK $nik',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          periodStr,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // HERO PERSENTASE PENCAPAIAN SAP
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular Arc Progress Persentase
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 78,
                            height: 78,
                            child: CircularProgressIndicator(
                              value: totalTarget > 0 ? (totalActualCapped / totalTarget).clamp(0.0, 1.0) : 1.0,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${complianceRate.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const Text(
                                'CAPAIAN',
                                style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                              ),
                              child: Text(
                                isCompliant ? 'TARGET TERPENUHI ✓' : 'SEDANG BERJALAN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Capaian Kepatuhan SAP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Realisasi $totalSubmissions input ($totalActualCapped terhitung target dari $totalTarget SAP)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalTarget > 0 ? (totalActualCapped / totalTarget).clamp(0.0, 1.0) : 1.0,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3 Metric Stat Pill (Target, Aktual, Sisa)
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricPill(
                          label: 'Total Target',
                          value: '$totalTarget',
                          unit: 'SAP',
                          color: const Color(0xFF38BDF8),
                          icon: Icons.flag_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricPill(
                          label: 'Realisasi',
                          value: '$totalActualCapped',
                          unit: 'SAP',
                          color: const Color(0xFF34D399),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricPill(
                          label: 'Sisa Target',
                          value: '$sisaTarget',
                          unit: 'SAP',
                          color: sisaTarget == 0 ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          icon: Icons.hourglass_bottom_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // DUAL SHORTCUT BANNERS (KLASEMEN DEPARTEMEN & KLASEMEN KARYAWAN)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _tabController.animateTo(1),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 14),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF059669), size: 14),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Klasemen Dept',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Urutan ${_totalClubs > 0 ? _totalClubs : _departments.length} Divisi',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DepartmentEmployeeLeaguePage(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF7DD3FC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0284C7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.groups_rounded, color: Colors.white, size: 14),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0284C7), size: 14),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Klasemen Karyawan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Skor & Audit Skuad',
                            style: TextStyle(fontSize: 10, color: Color(0xFF0284C7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ACTION PLAN DUAL ACCOUNTABILITY (50:50) INSIGHT CARD
            InkWell(
              onTap: () => routePage(context, '/sap_action_plan'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFFD97706), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Action Plan & Close Rate (Dual Accountability)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            '50% sisi Pelapor SAP + 50% sisi PIC Tugas • Pantau di Action Tracker',
                            style: TextStyle(fontSize: 10, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFD97706), size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // SECTION TITLE RINCIAN 6 MODUL SAP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rincian Modul SAP Individu',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Aktual vs Target',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 1. Hazard Report
            _buildSapModuleCard(
              context: context,
              label: 'Hazard Report',
              description: 'Laporan temuan bahaya KTA/TTA lapangan',
              actual: actualHazard,
              target: targetHazard,
              color: const Color(0xFFF59E0B),
              icon: Icons.warning_amber_rounded,
              route: '/hazard_report',
            ),
            const SizedBox(height: 10),

            // 2. Inspeksi K3
            _buildSapModuleCard(
              context: context,
              label: 'Inspeksi K3',
              description: 'Inspeksi terencana area dan peralatan operasional',
              actual: actualInspeksi,
              target: targetInspeksi,
              color: const Color(0xFF009688),
              icon: Icons.checklist_rounded,
              route: '/inspection',
            ),
            const SizedBox(height: 10),

            // 3. Safety Talk
            _buildSapModuleCard(
              context: context,
              label: 'Safety Talk',
              description: 'Briefing K3 keselamatan kerja sebelum bertugas',
              actual: actualSafetyTalk,
              target: targetSafetyTalk,
              color: const Color(0xFF6366F1),
              icon: Icons.record_voice_over_rounded,
              route: '/safety_talk',
            ),
            const SizedBox(height: 10),

            // 4. Observasi (BBS)
            _buildSapModuleCard(
              context: context,
              label: 'Observasi (BBS)',
              description: 'Observasi tugas dan perilaku keselamatan pekerja',
              actual: actualObservasi,
              target: targetObservasi,
              color: const Color(0xFF8B5CF6),
              icon: Icons.remove_red_eye_rounded,
              route: '/observation',
            ),
            const SizedBox(height: 10),

            // 5. Coaching K3
            _buildSapModuleCard(
              context: context,
              label: 'Coaching K3',
              description: 'Bimbingan dan pembinaan penerapan K3 karyawan',
              actual: actualCoaching,
              target: targetCoaching,
              color: const Color(0xFF0284C7),
              icon: Icons.supervisor_account_rounded,
              route: '/coaching',
            ),
            const SizedBox(height: 10),

            // 6. P5M
            _buildSapModuleCard(
              context: context,
              label: 'P5M (Pertemuan 5 Menit)',
              description: 'Pemeriksaan kesiapan kerja dan kesehatan kru harian',
              actual: actualP5m,
              target: targetP5m,
              color: const Color(0xFF10B981),
              icon: Icons.groups_rounded,
              route: '/p5m',
            ),

            const SizedBox(height: 18),

            // INFO ROSTER & PENYESUAIAN TARGET
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Target SAP dihitung otomatis oleh sistem dan disesuaikan proporsional sesuai roster kerja onsite lapangan.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: Color(0xFF64748B),
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

  // ==========================================
  // TAB 2: URUTAN DEPARTEMEN (LEADERBOARD / PERFORMANCE LEAGUE)
  // ==========================================
  Widget _buildDepartmentLeagueTab() {
    final filtered = _departments.where((d) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (d['departmentName'] ?? '').toString().toLowerCase();
      final initials = (d['initials'] ?? '').toString().toLowerCase();
      return name.contains(q) || initials.contains(q);
    }).toList();

    final userDeptName = _profile?.depart?.trim().toUpperCase() ?? '';

    // Cari peringkat departemen pengguna
    Map<String, dynamic>? myDeptData;
    int myDeptRank = 0;
    for (int i = 0; i < _departments.length; i++) {
      final name = (_departments[i]['departmentName'] ?? '').toString().trim().toUpperCase();
      if (userDeptName.isNotEmpty && (name == userDeptName || name.contains(userDeptName) || userDeptName.contains(name))) {
        myDeptData = _departments[i];
        myDeptRank = (myDeptData['rank'] is int) ? myDeptData['rank'] as int : (i + 1);
        break;
      }
    }

    return RefreshIndicator(
      color: const Color(0xFF009688),
      onRefresh: _loadDepartmentLeague,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HERO PODIUM TOP 3 (CHAMPIONS ZONE)
            if (_departments.length >= 3 && _searchQuery.isEmpty) ...[
              _buildChampionsPodium(),
              const SizedBox(height: 16),
            ],

            // MY DEPARTMENT PINNED BANNER (JIKA DITEMUKAN)
            if (myDeptData != null && _searchQuery.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF065F46).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text(
                          '#$myDeptRank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34D399),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'DEPARTEMEN ANDA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF064E3B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (myDeptData['departmentName'] ?? userDeptName).toString().toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Skor: ${(myDeptData['totalScore'] ?? 0)} PTS • Capaian: ${(myDeptData['mtdAchievementRate'] ?? 0)}%',
                            style: const TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // SEARCH BAR & STAT HEADER
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Cari departemen...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_departments.length} DEPARTEMEN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // LEADERBOARD TABLE HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text(
                      'POS',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DEPARTEMEN',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      'SKOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      'CAPAIAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                    ),
                  ),
                  SizedBox(width: 6),
                  SizedBox(
                    width: 68,
                    child: Text(
                      'FORM',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // LEADERBOARD LIST
            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: const Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                    SizedBox(height: 8),
                    Text(
                      'Departemen tidak ditemukan',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, idx) {
                  final d = filtered[idx];
                  return _buildDepartmentRow(d, idx, userDeptName);
                },
              ),

            const SizedBox(height: 18),

            // FORM DOTS LEGEND
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keterangan Klasemen & Form (5 Program SAP):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildDotPill('W', const Color(0xFF10B981), 'Win (≥80%)'),
                      const SizedBox(width: 10),
                      _buildDotPill('D', const Color(0xFFF59E0B), 'Draw (40-79%)'),
                      const SizedBox(width: 10),
                      _buildDotPill('L', const Color(0xFFEF4444), 'Loss (<40%)'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Form Dots berurutan: Hazard, Inspeksi, Safety Talk, Observasi, Coaching.',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CHAMPIONS PODIUM WIDGET (TOP 3)
  // ==========================================
  Widget _buildChampionsPodium() {
    final first = _departments[0];
    final second = _departments.length > 1 ? _departments[1] : null;
    final third = _departments.length > 2 ? _departments[2] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'CHAMPIONS ZONE • $_companyName • $_leaguePeriod'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFDE68A),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2nd Place (Silver)
              if (second != null)
                Expanded(
                  child: _buildPodiumStep(
                    data: second,
                    rank: 2,
                    medal: '🥈',
                    height: 110,
                    badgeColor: const Color(0xFF94A3B8),
                  ),
                ),
              const SizedBox(width: 8),

              // 1st Place (Gold Champion)
              Expanded(
                child: _buildPodiumStep(
                  data: first,
                  rank: 1,
                  medal: '🥇',
                  height: 135,
                  badgeColor: const Color(0xFFF59E0B),
                  isCenter: true,
                ),
              ),
              const SizedBox(width: 8),

              // 3rd Place (Bronze)
              if (third != null)
                Expanded(
                  child: _buildPodiumStep(
                    data: third,
                    rank: 3,
                    medal: '🥉',
                    height: 95,
                    badgeColor: const Color(0xFFB45309),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumStep({
    required Map<String, dynamic> data,
    required int rank,
    required String medal,
    required double height,
    required Color badgeColor,
    bool isCenter = false,
  }) {
    final name = (data['departmentName'] ?? '').toString();
    final initials = (data['initials'] ?? _getDeptInitials(name)).toString();
    final score = data['totalScore'] ?? 0;
    final rate = data['mtdAchievementRate'] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Football Shield
        Container(
          width: isCenter ? 44 : 36,
          height: isCenter ? 44 : 36,
          decoration: BoxDecoration(
            color: _getDeptColor(name),
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor, width: isCenter ? 2.5 : 1.5),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: isCenter ? 14 : 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isCenter ? 11 : 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          '$rate%',
          style: TextStyle(
            fontSize: isCenter ? 11.5 : 10,
            fontWeight: FontWeight.w900,
            color: _getRateColor((rate is num) ? rate.toDouble() : 0.0),
          ),
        ),
        const SizedBox(height: 6),
        // Podium Bar
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                badgeColor.withValues(alpha: 0.35),
                badgeColor.withValues(alpha: 0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                medal,
                style: TextStyle(fontSize: isCenter ? 22 : 18),
              ),
              Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$score PTS',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // DEPARTMENT LEAGUE ROW & EXPANDABLE DETAILS
  // ==========================================
  Widget _buildDepartmentRow(Map<String, dynamic> d, int idx, String userDeptName) {
    final rank = d['rank'] ?? (idx + 1);
    final name = (d['departmentName'] ?? '').toString();
    final initials = (d['initials'] ?? _getDeptInitials(name)).toString();
    final shieldColor = _getDeptColor(name);
    final empCount = d['employeeCount'] ?? 0;
    final totalScore = (d['totalScore'] is num) ? (d['totalScore'] as num).toDouble() : 0.0;
    final rate = (d['mtdAchievementRate'] is num) ? (d['mtdAchievementRate'] as num).toDouble() : 0.0;

    final hRate = (d['mtdHazardRate'] is num) ? (d['mtdHazardRate'] as num).toDouble() : 100.0;
    final iRate = (d['mtdInspeksiRate'] is num) ? (d['mtdInspeksiRate'] as num).toDouble() : 100.0;
    final stRate = (d['mtdSafetyTalkRate'] is num) ? (d['mtdSafetyTalkRate'] as num).toDouble() : 100.0;
    final oRate = (d['mtdObservasiRate'] is num) ? (d['mtdObservasiRate'] as num).toDouble() : 100.0;
    final cRate = (d['mtdCoachingRate'] is num) ? (d['mtdCoachingRate'] as num).toDouble() : 100.0;

    final isMyDept = userDeptName.isNotEmpty &&
        (name.toUpperCase() == userDeptName || name.toUpperCase().contains(userDeptName) || userDeptName.contains(name.toUpperCase()));

    final bool isTop3 = (rank is int && rank <= 3);
    final bool isRelegation = (rank is int && rank >= _departments.length - 1 && _departments.length > 5) || (rate == 0);

    final isExpanded = _expandedDepts.contains(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isMyDept ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyDept
              ? const Color(0xFF10B981)
              : (isTop3
                  ? const Color(0xFFFDE68A)
                  : (isRelegation ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0))),
          width: isMyDept ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedDepts.remove(name);
            } else {
              _expandedDepts.add(name);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  // Rank Pill
                  SizedBox(
                    width: 38,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isTop3
                              ? (rank == 1
                                  ? const Color(0xFFFEF3C7)
                                  : (rank == 2 ? const Color(0xFFF1F5F9) : const Color(0xFFFFEDD5)))
                              : (isRelegation ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isTop3
                                ? const Color(0xFFF59E0B)
                                : (isRelegation ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1)),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isTop3 ? (rank == 1 ? '🥇 1' : (rank == 2 ? '🥈 2' : '🥉 3')) : '#$rank',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isTop3
                                ? const Color(0xFF92400E)
                                : (isRelegation ? const Color(0xFFB91C1C) : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Football Shield & Dept Name
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: shieldColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isMyDept ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  if (isMyDept) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'TIM SAYA',
                                        style: TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '$empCount Skuad',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Total Skor PTS Pill
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isTop3 ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          totalScore.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Capaian MTD %
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${rate.toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _getRateColor(rate),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 5 Form Dots (Hazard, Inspeksi, Safety Talk, Observasi, Coaching)
                  SizedBox(
                    width: 68,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDot(hRate),
                        const SizedBox(width: 2),
                        _buildDot(iRate),
                        const SizedBox(width: 2),
                        _buildDot(stRate),
                        const SizedBox(width: 2),
                        _buildDot(oRate),
                        const SizedBox(width: 2),
                        _buildDot(cRate),
                      ],
                    ),
                  ),
                ],
              ),

              // EXPANDED DETAIL BREAKDOWN
              if (isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                _buildDepartmentExpandedDetails(d),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentExpandedDetails(Map<String, dynamic> d) {
    final deptName = (d['departmentName'] ?? 'Departemen').toString();
    final ptsClose = (d['ptsClose'] is num) ? (d['ptsClose'] as num).toDouble() : 0.0;
    final ptsKualitas = (d['ptsKualitas'] is num) ? (d['ptsKualitas'] as num).toDouble() : 0.0;
    final ptsCapaian = (d['ptsCapaian'] is num) ? (d['ptsCapaian'] as num).toDouble() : 0.0;
    final ptsBeban = (d['ptsBeban'] is num) ? (d['ptsBeban'] as num).toDouble() : 0.0;
    final totalScore = (d['totalScore'] is num) ? (d['totalScore'] as num).toDouble() : 0.0;
    final closeRate = (d['mtdCloseRate'] is num) ? (d['mtdCloseRate'] as num).toDouble() : 100.0;

    final hAct = d['hazardActual'] ?? 0;
    final hTgt = d['hazardTarget'] ?? 0;
    final iAct = d['inspeksiActual'] ?? 0;
    final iTgt = d['inspeksiTarget'] ?? 0;
    final stAct = d['safetyTalkActual'] ?? 0;
    final stTgt = d['safetyTalkTarget'] ?? 0;
    final oAct = d['observasiActual'] ?? 0;
    final oTgt = d['observasiTarget'] ?? 0;
    final cAct = d['coachingActual'] ?? 0;
    final cTgt = d['coachingTarget'] ?? 0;
    final pAct = d['p5mActual'] ?? 0;
    final pTgt = d['p5mTarget'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4-Pillar Score Cards (Web /Performance/League Formula)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Evaluasi Kinerja 4 Pilar PTS:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    'Total: ${totalScore.toStringAsFixed(2)} PTS',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildPtsItem('Capaian SAP (35%)', '+${ptsCapaian.toStringAsFixed(2)}', const Color(0xFF3B82F6))),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPtsItem('Action Plan (30%)', '+${ptsClose.toStringAsFixed(2)}', const Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _buildPtsItem('Kualitas AI (25%)', '+${ptsKualitas.toStringAsFixed(2)}', const Color(0xFFF59E0B))),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPtsItem('Beban Target (10%)', '+${ptsBeban.toStringAsFixed(2)}', const Color(0xFF8B5CF6))),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Grid Rincian Realisasi 6 Modul
        const Text(
          'Realisasi vs Target Modul SAP:',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildModuleMiniStat('Hazard', '$hAct/$hTgt', const Color(0xFFF59E0B))),
            const SizedBox(width: 4),
            Expanded(child: _buildModuleMiniStat('Inspeksi', '$iAct/$iTgt', const Color(0xFF009688))),
            const SizedBox(width: 4),
            Expanded(child: _buildModuleMiniStat('Safety Talk', '$stAct/$stTgt', const Color(0xFF6366F1))),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _buildModuleMiniStat('Observasi', '$oAct/$oTgt', const Color(0xFF8B5CF6))),
            const SizedBox(width: 4),
            Expanded(child: _buildModuleMiniStat('Coaching', '$cAct/$cTgt', const Color(0xFF0284C7))),
            const SizedBox(width: 4),
            Expanded(child: _buildModuleMiniStat('P5M', '$pAct/$pTgt', const Color(0xFF10B981))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Close Rate Action Plan:', style: TextStyle(fontSize: 10, color: Color(0xFF065F46))),
              Text(
                '${closeRate.toStringAsFixed(1)}% (${d['apClosed'] ?? 0}/${d['apTotal'] ?? 0} Closed)',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DepartmentEmployeeLeaguePage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.groups_rounded, size: 15, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Buka Klasemen Karyawan Skuad $deptName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF0284C7)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPtsItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleMiniStat(String name, String stat, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(stat, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildDot(double val) {
    String letter = 'W';
    Color bg = const Color(0xFF10B981);
    if (val < 0 || val >= 80) {
      letter = 'W';
      bg = const Color(0xFF10B981);
    } else if (val >= 40) {
      letter = 'D';
      bg = const Color(0xFFF59E0B);
    } else {
      letter = 'L';
      bg = const Color(0xFFEF4444);
    }

    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDotPill(String letter, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(letter, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ==========================================
  // HELPER CARDS UNTUK TAB INDIVIDU
  // ==========================================
  Widget _buildMetricPill({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSapModuleCard({
    required BuildContext context,
    required String label,
    required String description,
    required int actual,
    required int target,
    required Color color,
    required IconData icon,
    required String route,
  }) {
    final bool isDone = target == 0 || actual >= target;
    final double progress = target > 0 ? (actual / target).clamp(0.0, 1.0) : 1.0;
    final int kurang = target > actual ? target - actual : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? color.withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            routePage(context, route);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isDone ? 'Tercapai ✓' : 'Kurang $kurang',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDone ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Baris Angka Aktual vs Target & Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Realisasi Modul',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$actual',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDone ? color : const Color(0xFF1E293B),
                            ),
                          ),
                          TextSpan(
                            text: ' / $target SAP',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Linear Progress Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SapLeaguePage extends StatelessWidget {
  const SapLeaguePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AchievementSapPage(initialTabIndex: 1);
  }
}

class IncidentInformationPage extends StatelessWidget {
  const IncidentInformationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafetyUpdatesPage();
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

// ActionTrackerPage is implemented in action_tracker_page.dart

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
