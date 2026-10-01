import 'package:flutter/material.dart';

import '../pages/coaching/coaching_form_page.dart';
import '../pages/coaching/coaching_page.dart';
import '../pages/coming_soon_page.dart';
import '../pages/daily/daily_form_page.dart';
import '../pages/daily/daily_page.dart';
import '../pages/hazard/hazard_form_page.dart';
import '../pages/hazard/hazard_page.dart';
import '../pages/induction/induction_form_page.dart';
import '../pages/induction/induction_page.dart';
import '../pages/inspeksi/inspeksi_form_page.dart';
import '../pages/inspeksi/inspeksi_page.dart';
import '../pages/observation/observation_form_page.dart';
import '../pages/observation/observation_page.dart';
import '../pages/p2h/p2h_form_page.dart';
import '../pages/p2h/p2h_page.dart';
import '../pages/p5m/p5m_form_page.dart';
import '../pages/p5m/p5m_page.dart';
import '../pages/performance/performance_hub_pages.dart';
import '../pages/safetytalk/safetytalk_form_page.dart';
import '../pages/safetytalk/safetytalk_page.dart';
import '../pages/sap_report_page.dart';
import '../pages/simama/simama_form_page.dart';
import '../pages/simama/simama_page.dart';
import 'enums.dart';

void routePage(BuildContext ctx, String route, {String? title}) {
  if (route == '/sap_report') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const SapReportPage(),
      ),
    );
  }
  if (route == '/sap_achievement') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const AchievementSapPage(),
      ),
    );
  }
  if (route == '/sap_league') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const SapLeaguePage(),
      ),
    );
  }
  if (route == '/sap_action_plan') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const ActionTrackerPage(),
      ),
    );
  }
  if (route == '/sap_incident_information') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const IncidentInformationPage(),
      ),
    );
  }
  if (route == '/sap_quality') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const SapQualityPage(),
      ),
    );
  }
  if (route == '/sap_work_roster') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const WorkRosterPage(),
      ),
    );
  }
  if (route == '/dpa') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const DriverPerformanceAssessmentPage(),
      ),
    );
  }
  if (route == '/inspection') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const InspeksiPage(Module.inspection),
      ),
    );
  }
  if (route == '/hazard_report') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const HazardPage(),
      ),
    );
  }
  if (route == '/coaching') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const CoachingPage(),
      ),
    );
  }
  if (route == '/observation') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const ObservationPage(),
      ),
    );
  }
  if (route == '/safety_talk') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const SafetyTalkPage(),
      ),
    );
  }
  if (route == '/daily_inspection') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const DailyPage(Module.inspectionDaily),
      ),
    );
  }
  if (route == '/weekly_inspection') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const InspeksiPage(Module.inspectionWeekly),
      ),
    );
  }
  if (route == '/simama') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const SimamaPage(Module.simama),
      ),
    );
  }
  if (route == '/p5m') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const P5MPage(),
      ),
    );
  }
  if (route == '/kesehatan_kerja') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/take5') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/incident_investigation') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/nearmiss') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/izin_kerja_khusus') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/hygiene') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/enviroment') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/p2h') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const P2HPage(),
      ),
    );
  }
  if (route == '/lv_maintenane') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/paper_corporate') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/document_management') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/training_certification') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/maaeting_schedule') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/smkp_csms') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/commisioning') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/permit_simper') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => ComingSoonPage(title),
      ),
    );
  }
  if (route == '/induction') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const InductionPage(),
      ),
    );
  }
  if (route == '/form_inspection') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const InspeksiFormPage(Module.inspection),
      ),
    );
  }
  if (route == '/form_daily_inspection') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const DailyFormPage(Module.inspectionDaily),
      ),
    );
  }
  if (route == '/form_weekly_inspection') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const InspeksiFormPage(Module.inspectionWeekly),
      ),
    );
  }
  if (route == '/form_simama') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const SimamaFormPage(Module.simama),
      ),
    );
  }
  if (route == '/form_hazard_report') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const HazardFormPage(),
      ),
    );
  }
  if (route == '/form_coaching') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const CoachingFormPage(),
      ),
    );
  }
  if (route == '/form_observation') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const ObservationFormPage(),
      ),
    );
  }
  if (route == '/form_safety_talk') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const SafetyTalkFormPage(),
      ),
    );
  }
  if (route == '/form_p5m') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const P5MFormPage(),
      ),
    );
  }
  if (route == '/form_p2h') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const P2HFormPage(),
      ),
    );
  }
  if (route == '/form_induction') {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => const InductionFormPage(),
      ),
    );
  }
}
