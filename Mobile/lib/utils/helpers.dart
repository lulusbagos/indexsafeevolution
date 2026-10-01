import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/globals.dart' as globals;
import '../widgets/snackbar_msg.dart';
import 'enums.dart';
import 'routers.dart';

Future<File?> pickImage({ImageSource? source}) async {
  if (source == null) return null;

  try {
    final canProceed = await _ensureMediaPermission(source: source);
    if (!canProceed) return null;

    final imgPicker = ImagePicker();
    final imgPicked = await imgPicker.pickImage(
      source: source,
      imageQuality: 15,
    );
    if (imgPicked == null) return null;

    return File(imgPicked.path);
  } catch (e) {
    debugPrint(e.toString());
    return null;
  }
}

Future<bool> _ensureMediaPermission({
  required ImageSource source,
  bool includeMicrophone = false,
}) async {
  if (source == ImageSource.gallery) {
    if (Platform.isIOS) {
      final photosStatus = await Permission.photos.request();
      return photosStatus.isGranted || photosStatus.isLimited;
    }

    return true;
  }

  if (Platform.isIOS) {
    final iosInfo = await DeviceInfoPlugin().iosInfo;
    if (!iosInfo.isPhysicalDevice) {
      return true;
    }
  }

  final cameraStatus = await Permission.camera.request();
  if (!cameraStatus.isGranted) {
    return false;
  }

  if (includeMicrophone) {
    final microphoneStatus = await Permission.microphone.request();
    if (!microphoneStatus.isGranted) {
      return false;
    }
  }

  return true;
}

String? validator(String? val) {
  if (val == null || val.isEmpty) {
    return 'Please enter value';
  }
  return null;
}

Future<void> permissionStorage() async {
  if (!await Permission.storage.isGranted) {
    await Permission.storage.request();
  } else if (!await Permission.accessMediaLocation.isGranted) {
    await Permission.accessMediaLocation.request();
  } else if (!await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }
}

void requestGeolocator(BuildContext context) {
  Geolocator.requestPermission().then((LocationPermission permission) {
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      SnackBarMsg.danger(
        context,
        'To ensure your account security, please enable your locaton',
      );
      return;
    }

    currentPosition(context);
  });
}

void currentPosition(BuildContext context) {
  try {
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).then((Position position) {
      globals.position = position;
    });

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    ).listen((Position position) {
      globals.position = position;
    });
  } catch (e) {
    SnackBarMsg.danger(
      context,
      'To ensure your account security, please enable your locaton',
    );
    return;
  }
}

void openPage(BuildContext ctx, Module module) {
  switch (module) {
    case Module.inspection:
      routePage(ctx, '/form_inspection');
      break;
    case Module.inspectionDaily:
      routePage(ctx, '/form_daily_inspection');
      break;
    case Module.inspectionWeekly:
      routePage(ctx, '/form_weekly_inspection');
      break;
    case Module.simama:
      routePage(ctx, '/form_simama');
      break;
    case Module.hazard:
      routePage(ctx, '/form_hazard_report');
      break;
    case Module.coaching:
      routePage(ctx, '/form_coaching');
      break;
    case Module.observation:
      routePage(ctx, '/form_observation');
      break;
    case Module.p2h:
      routePage(ctx, '/form_p2h');
      break;
    case Module.p5m:
      routePage(ctx, '/form_p5m');
      break;
    case Module.safety:
      routePage(ctx, '/form_safety_talk');
      break;
    case Module.induction:
      routePage(ctx, '/form_induction');
      break;
  }
}

String pageTitle(Module module) {
  switch (module) {
    case Module.inspection:
      return 'Inspection';
    case Module.inspectionDaily:
      return 'Daily Inspection';
    case Module.inspectionWeekly:
      return 'Weekly Inspection';
    case Module.simama:
      return 'Sidak Malam Management';
    case Module.hazard:
      return 'Hazard Report';
    case Module.coaching:
      return 'Coaching';
    case Module.observation:
      return 'Observation';
    case Module.p2h:
      return 'Check P2H';
    case Module.p5m:
      return 'Fit to Work P5M';
    case Module.safety:
      return 'Safety Talk';
    case Module.induction:
      return 'Induction';
  }
}

String capitalized(String str) {
  return str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '';
}

String titleCase(String str) {
  return str
      .replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => capitalized(str))
      .join(' ');
}
