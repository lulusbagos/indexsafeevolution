import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/inspect_detail_model.dart';

String appName = '';
String packageName = '';
String version = '';
String buildNumber = '';
String os = '';
String osVersion = '';
String deviceId = '';
String deviceVersion = '';
bool goHome = false;
bool reSync = false;
int currentPage = 0;
Position? position;
InspectDetailModel? checkList;
Map<int, int> onsite = {};
Map<int, String> yesNo = {0: 'TIDAK', 1: 'YA', 2: 'N/A'};
Map<int, String> goodBad = {0: 'BAD', 1: 'GOOD', 2: 'N/A'};
Map<int, String> status = {0: 'OPEN', 1: 'PROGRESS', 2: 'COMPLETE', 3: 'CLOSE'};
Map<int, MaterialColor> statusColor = {
  0: Colors.red,
  1: Colors.orange,
  2: Colors.green,
  3: Colors.blue
};
