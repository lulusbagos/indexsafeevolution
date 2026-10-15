import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
import '../services/background.dart';
import '../services/notification.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;
import '../utils/helpers.dart';
import '../widgets/snackbar_msg.dart';
import 'about_page.dart';
import 'change_password_page.dart';
import 'license_agreement_page.dart';
import 'login_page.dart';
import 'privacy_policy_page.dart';
import 'sync_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _scrollCtrl = ScrollController();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  ImageProvider? _image;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        var temp = '${(await getTemporaryDirectory()).path}/';

        if (_profile != null &&
            _profile!.foto != null &&
            _profile!.foto != '') {
          if (File(_profile!.foto!).existsSync()) {
            setState(() =>
                _image = MemoryImage(File(_profile!.foto!).readAsBytesSync()));
          } else if (File(temp + _profile!.foto!).existsSync()) {
            setState(() => _image =
                MemoryImage(File(temp + _profile!.foto!).readAsBytesSync()));
          } else {
            await _api.dio.download(
              '${_api.baseUrl}/image/${_profile!.foto}',
              temp + _profile!.foto!,
            );
            if (!mounted) return;
            setState(() => _image =
                MemoryImage(File(temp + _profile!.foto!).readAsBytesSync()));
          }
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 40),
          InkWell(
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.camera_alt, color: Colors.grey),
                        title: const Text('Camera'),
                        onTap: () {
                          Navigator.pop(context);
                          Future<File?> imageFile =
                              pickImage(source: ImageSource.camera);
                          imageFile.then((value) {
                            if (value != null && _profile != null) {
                              _profile!.foto = value.path;
                              PreferenceService.setProfile(_profile!);
                              _api.changeProfile(value).then((res) {
                                res.fold((error) {
                                  SnackBarMsg.danger(
                                      context, error['message'].toString());
                                }, (response) async {
                                  /** */
                                });
                              });

                              setState(() => _image = MemoryImage(
                                  File(value.path).readAsBytesSync()));
                            }
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.image, color: Colors.grey),
                        title: const Text('Gallery'),
                        onTap: () {
                          Navigator.pop(context);
                          Future<File?> imageFile =
                              pickImage(source: ImageSource.gallery);
                          imageFile.then((value) {
                            if (value != null && _profile != null) {
                              _profile!.foto = value.path;
                              PreferenceService.setProfile(_profile!);
                              _api.changeProfile(value).then((res) {
                                res.fold((error) {
                                  SnackBarMsg.danger(
                                      context, error['message'].toString());
                                }, (response) async {
                                  /** */
                                });
                              });

                              setState(() => _image = MemoryImage(
                                  File(value.path).readAsBytesSync()));
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade200,
              child: _image == null
                  ? Icon(
                      Icons.account_circle,
                      color: Colors.grey.shade400,
                      size: 90,
                    )
                  : Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        image: DecorationImage(
                          image: _image!,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${_profile?.namaLengkap}'.toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '${_profile?.posisi}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.only(left: 15),
            child: Text(
              'General Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green.shade100,
              child: const Icon(
                Icons.privacy_tip_rounded,
                color: Colors.green,
                size: 24,
              ),
            ),
            title: const Text('Privacy Policy', style: TextStyle(fontSize: 16)),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.indigo.shade400,
              size: 16,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.deepPurple.shade100,
              child: const Stack(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white70,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.flag_circle,
                      color: Colors.deepPurple,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            title: const Text('About', style: TextStyle(fontSize: 16)),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.indigo.shade400,
              size: 16,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade100,
              child: const Stack(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white70,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.info,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            title:
                const Text('License Agreement', style: TextStyle(fontSize: 16)),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.indigo.shade400,
              size: 16,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LicenseAgreementPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.teal.shade100,
              child: const Stack(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.teal,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.password,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            title: const Text('Ganti Password', style: TextStyle(fontSize: 16)),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.indigo.shade400,
              size: 16,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade100,
              child: Stack(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blue.shade800,
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.sync,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            title:
                const Text('Sync Master Data', style: TextStyle(fontSize: 16)),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.indigo.shade400,
              size: 16,
            ),
            onTap: () {
              globals.reSync = true;
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Sync Master Data'),
                    content: const Text(
                      'Apakah anda akan sinkronisasi ulang master data?',
                    ),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                          textStyle: Theme.of(context).textTheme.labelLarge,
                        ),
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          textStyle: Theme.of(context).textTheme.labelLarge,
                        ),
                        child: const Text('Ok'),
                        onPressed: () {
                          PreferenceService.setDataSync(<String, int>{});
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SyncPage(_profile!)),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueGrey.shade100,
              child: const Stack(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            title: const Text('Logout', style: TextStyle(fontSize: 16)),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.indigo.shade400,
              size: 16,
            ),
            onTap: () {
              NotificationService.cancelAll();
              BackgroundService.instance.isRunning().then((val) {
                if (val) BackgroundService.instance.stop();
              });

              _api.logout().then((res) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('bgToken');
                await prefs.remove('bgProfile');

                PreferenceService.removeAuth();
                PreferenceService.removeProfile();

                if (!context.mounted) return;
                await Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              });
            },
          ),
          const SizedBox(height: 150),
        ],
      ),
    );
  }
}
