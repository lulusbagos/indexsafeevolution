import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/preference.dart';
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
  final _confirmCtrl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? _savedPassword;

  @override
  void initState() {
    super.initState();
    _savedPassword = PreferenceService.getPassword();
  }

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // --- Password Strength & Validation Rules ---
  bool get _hasMinLength => _newCtrl.text.length >= 6;
  bool get _hasUpperLower =>
      _newCtrl.text.contains(RegExp(r'[a-z]')) &&
      _newCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _newCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _isMatch =>
      _newCtrl.text.isNotEmpty && _newCtrl.text == _confirmCtrl.text;

  int get _strengthScore {
    final text = _newCtrl.text;
    if (text.isEmpty) return 0;
    int score = 0;
    if (text.length >= 6) score++;
    if (text.length >= 8) score++;
    if (_hasUpperLower) score++;
    if (_hasNumber) score++;
    if (text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 1) return 1; // Sangat Lemah
    if (score == 2) return 2; // Lemah
    if (score == 3 || score == 4) return 3; // Sedang
    return 4; // Kuat
  }

  String get _strengthText {
    switch (_strengthScore) {
      case 1:
        return 'Sangat Lemah';
      case 2:
        return 'Lemah';
      case 3:
        return 'Sedang';
      case 4:
        return 'Sangat Kuat';
      default:
        return 'Belum diisi';
    }
  }

  Color get _strengthColor {
    switch (_strengthScore) {
      case 1:
        return const Color(0xFFEF4444); // red-500
      case 2:
        return const Color(0xFFF97316); // orange-500
      case 3:
        return const Color(0xFFF59E0B); // amber-500
      case 4:
        return const Color(0xFF10B981); // emerald-500
      default:
        return const Color(0xFF94A3B8); // slate-400
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final oldPwd = _oldCtrl.text.trim();
    final newPwd = _newCtrl.text.trim();
    final confirmPwd = _confirmCtrl.text.trim();

    if (oldPwd.isEmpty) {
      SnackBarMsg.danger(context, 'Silakan masukkan kata sandi lama Anda.');
      return;
    }
    if (newPwd.isEmpty) {
      SnackBarMsg.danger(context, 'Silakan masukkan kata sandi baru Anda.');
      return;
    }
    if (newPwd.length < 6) {
      SnackBarMsg.danger(context, 'Kata sandi baru minimal 6 karakter.');
      return;
    }
    if (newPwd == oldPwd) {
      SnackBarMsg.danger(
        context,
        'Kata sandi baru tidak boleh sama dengan kata sandi lama.',
      );
      return;
    }
    if (confirmPwd.isEmpty) {
      SnackBarMsg.danger(
        context,
        'Silakan masukkan konfirmasi kata sandi baru.',
      );
      return;
    }
    if (newPwd != confirmPwd) {
      SnackBarMsg.danger(
        context,
        'Konfirmasi kata sandi tidak cocok dengan kata sandi baru.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _api.changePassword(oldPwd, newPwd);
      if (!mounted) return;

      res.fold(
        (error) {
          setState(() => _isLoading = false);
          SnackBarMsg.danger(
            context,
            error['message']?.toString() ?? 'Gagal mengubah kata sandi.',
          );
        },
        (response) async {
          // Sync stored credentials for seamless offline and re-auth
          final user = PreferenceService.getUser();
          if (user != null && user.isNotEmpty) {
            await PreferenceService.setUserPassword(user, newPwd);
            await PreferenceService.setOfflineCredentials(
              nik: user,
              password: newPwd,
            );
          }

          if (!mounted) return;
          setState(() => _isLoading = false);

          await Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const SuccessPage(msg: 'Password Anda berhasil diubah!'),
            ),
            (route) => false,
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarMsg.danger(
          context,
          'Terjadi kesalahan saat mengubah kata sandi: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'Ganti Password'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Form(
              key: _key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Hero Security Header Card ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x402563EB),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0x26FFFFFF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0x4DFFFFFF),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Perbarui Kata Sandi',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Jaga keamanan akun Anda dengan kata sandi yang kuat dan unik.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xD9FFFFFF),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick assist if saved password exists in cache
                  if (_savedPassword != null && _savedPassword!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x05000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.vpn_key_rounded,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kata Sandi Saat Ini Tersedia',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  'Gunakan jika lupa kata sandi lama',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFEFF6FF),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _oldCtrl.text = _savedPassword!;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Kata sandi lama berhasil diisi otomatis'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Color(0xFF0F172A),
                                ),
                              );
                            },
                            child: const Text(
                              'Gunakan',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // --- Form Card ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Field 1: Kata Sandi Lama
                        _buildFieldLabel(
                          label: 'Kata Sandi Lama',
                          isRequired: true,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _oldCtrl,
                          obscureText: _obscureOld,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Masukkan kata sandi lama Anda',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              splashRadius: 20,
                              icon: Icon(
                                _obscureOld
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscureOld = !_obscureOld);
                              },
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 20),

                        // Field 2: Kata Sandi Baru
                        _buildFieldLabel(
                          label: 'Kata Sandi Baru',
                          isRequired: true,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _newCtrl,
                          obscureText: _obscureNew,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Minimal 6 karakter kuat',
                            prefixIcon: Icons.key_rounded,
                            suffixIcon: IconButton(
                              splashRadius: 20,
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscureNew = !_obscureNew);
                              },
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),

                        // Realtime Password Strength Bar
                        if (_newCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kekuatan Kata Sandi:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _strengthText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _strengthColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _strengthScore / 4,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _strengthColor),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Field 3: Konfirmasi Kata Sandi Baru
                        _buildFieldLabel(
                          label: 'Ulangi Kata Sandi Baru',
                          isRequired: true,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _buildInputDecoration(
                            hintText: 'Ketik ulang kata sandi baru',
                            prefixIcon: Icons.lock_reset_rounded,
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_confirmCtrl.text.isNotEmpty)
                                  Icon(
                                    _isMatch
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    size: 18,
                                    color: _isMatch
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                IconButton(
                                  splashRadius: 20,
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() =>
                                        _obscureConfirm = !_obscureConfirm);
                                  },
                                ),
                              ],
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 20),

                        // --- Dynamic Requirements Checklist Box ---
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                    color: Colors.blueGrey.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Persyaratan Keamanan:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildChecklistItem(
                                label: 'Minimal 6 karakter',
                                isSatisfied: _hasMinLength,
                              ),
                              const SizedBox(height: 6),
                              _buildChecklistItem(
                                label: 'Kombinasi huruf besar & huruf kecil',
                                isSatisfied: _hasUpperLower,
                              ),
                              const SizedBox(height: 6),
                              _buildChecklistItem(
                                label: 'Mengandung setidaknya 1 angka (0-9)',
                                isSatisfied: _hasNumber,
                              ),
                              const SizedBox(height: 6),
                              _buildChecklistItem(
                                label: 'Kata sandi baru & konfirmasi cocok',
                                isSatisfied: _isMatch,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Submit Button ---
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                        shadowColor: const Color(0x662563EB),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: _isLoading
                              ? LinearGradient(
                                  colors: [
                                    Colors.grey.shade400,
                                    Colors.grey.shade500,
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF1D4ED8),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'SIMPAN KATA SANDI',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.6,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel({
    required String label,
    required bool isRequired,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEF4444),
            ),
          ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 13.5,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.normal,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(
          prefixIcon,
          size: 20,
          color: const Color(0xFF3B82F6),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(
        minWidth: 44,
        minHeight: 44,
      ),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
    );
  }

  Widget _buildChecklistItem({
    required String label,
    required bool isSatisfied,
  }) {
    return Row(
      children: [
        Icon(
          isSatisfied
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: isSatisfied
              ? const Color(0xFF10B981)
              : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.w400,
              color: isSatisfied
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
