import 'package:flutter/material.dart';

import '../models/link_model.dart';

List<LinkNewsModel> listNews() {
  return [
    LinkNewsModel(
      image: 'assets/images/info1.jpg',
      title: '',
      url: '#',
      description: '',
    ),
    LinkNewsModel(
      image: 'assets/images/info2.jpg',
      title: '',
      url: '#',
      description: '',
    ),
    LinkNewsModel(
      image: 'assets/images/info3.jpg',
      title: '',
      url: '#',
      description: '',
    ),
    LinkNewsModel(
      image: 'assets/images/info4.jpg',
      title: '',
      url: '#',
      description: '',
    ),
  ];
}

List<LinkMenuModel> listMenuSap = <LinkMenuModel>[
  LinkMenuModel(
    title: 'SAP Report',
    icon: Icons.manage_search_sharp,
    image: 'assets/icons/sap-01.png',
    route: '/sap_report',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Inspection',
    icon: Icons.manage_search_sharp,
    image: 'assets/icons/sap-02.png',
    route: '/inspection',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Hazard\nReport',
    icon: Icons.warning_amber_rounded,
    image: 'assets/icons/sap-03.png',
    route: '/hazard_report',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Observation',
    icon: Icons.content_paste_search_rounded,
    image: 'assets/icons/sap-04.png',
    route: '/observation',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Safety Talk',
    icon: Icons.health_and_safety_outlined,
    image: 'assets/icons/sap-05.png',
    route: '/safety_talk',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Coaching',
    icon: Icons.hail_rounded,
    image: 'assets/icons/sap-06.png',
    route: '/coaching',
    opacity: 1,
  ),
];

List<LinkMenuModel> listMenuOhs1 = <LinkMenuModel>[
  LinkMenuModel(
    title: 'Management\nInspection',
    icon: Icons.manage_search_sharp,
    image: 'assets/icons/ohs-01.png',
    route: '/inspection',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Daily\nInspection',
    icon: Icons.fact_check_rounded,
    image: 'assets/icons/ohs-02.png',
    route: '/daily_inspection',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Fit to Work\nP5M',
    icon: Icons.health_and_safety_rounded,
    image: 'assets/icons/ohs-03.png',
    route: '/p5m',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'SiMaMa',
    icon: Icons.nightlight_round,
    image: 'assets/icons/ohs-01.png',
    route: '/simama',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'P2H',
    icon: Icons.car_repair_rounded,
    image: 'assets/icons/extra-03.png',
    route: '/p2h',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'DPA',
    icon: Icons.drive_eta_rounded,
    image: '',
    route: '/dpa',
    opacity: 1,
  ),
];

List<LinkMenuModel> listMenuOhs2 = <LinkMenuModel>[];

List<LinkMenuModel> listMenuExtra = <LinkMenuModel>[
  LinkMenuModel(
    title: 'Pencapaian\nSAP',
    icon: Icons.track_changes_rounded,
    image: '',
    route: '/sap_achievement',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Klasemen\nLeague SAP',
    icon: Icons.emoji_events_rounded,
    image: '',
    route: '/sap_league',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Roster Kerja',
    icon: Icons.calendar_month_rounded,
    image: '',
    route: '/sap_work_roster',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Kualitas SAP',
    icon: Icons.verified_rounded,
    image: '',
    route: '/sap_quality',
    opacity: 1,
  ),
  LinkMenuModel(
    title: 'Action\nTracker',
    icon: Icons.assignment_turned_in_rounded,
    image: '',
    route: '/sap_action_plan',
    opacity: 1,
  ),
];
