import 'package:flutter/material.dart';

import '../services/api.dart';
import '../utils/helpers.dart';
import '../widgets/button_app.dart';
import '../widgets/snackbar_msg.dart';
import '../widgets/top_bar.dart';
import 'success_page.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _key = GlobalKey<FormState>();
  final _api = ApiService();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _obscureText1 = true;
  bool _obscureText2 = true;

  @override
  void initState() {
    super.initState();

    _oldCtrl.text = '';
    _newCtrl.text = '';
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  void _submit() async {
    if (_key.currentState != null && _key.currentState!.validate()) {
      _key.currentState?.save();
      _api.changePassword(_oldCtrl.text, _newCtrl.text).then((res) {
        res.fold((error) {
          SnackBarMsg.danger(context, error['message'].toString());
        }, (response) async {
          await Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const SuccessPage(msg: 'Password Anda berhasil diubah!')),
            (route) => false,
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBar(title: 'Ganti Password'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 30),
              child: Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Image(
                        image: AssetImage('assets/images/reset-password.gif'),
                        width: 220,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Password Lama',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _oldCtrl,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            Icons.key,
                            size: 24,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                        suffixIcon: SizedBox(
                          width: 30,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscureText1 = !_obscureText1;
                              });
                            },
                            child: Icon(
                              _obscureText1
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                      obscureText: _obscureText1,
                      validator: validator,
                      onChanged: (String val) => setState(() {}),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Password Baru',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _newCtrl,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            Icons.key,
                            size: 24,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                        suffixIcon: SizedBox(
                          width: 30,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscureText2 = !_obscureText2;
                              });
                            },
                            child: Icon(
                              _obscureText2
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                      obscureText: _obscureText2,
                      validator: validator,
                      onChanged: (String val) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            width: 300,
            child: buttonApp(label: 'SIMPAN', onPressed: _submit),
          )
        ],
      ),
    );
  }
}
