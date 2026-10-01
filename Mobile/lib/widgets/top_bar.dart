import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../services/database.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;

class TopBar extends StatefulWidget implements PreferredSizeWidget {
  const TopBar({
    this.title,
    this.border,
    this.back = 1,
    this.onChanged,
    super.key,
  });

  final String? title;
  final InputBorder? border;
  final int back;
  final void Function(String)? onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  void _getData() {
    _db.rawQuery('''select tr.id from action_plans tr
      where tr.deleted_at is null and ((tr.pja_id=${_profile?.id} and tr.status<1) or (tr.pic_id=${_profile?.id} and tr.status<2))''').then((val) async {
      await PreferenceService.setNotif(val.length);
    });
  }

  Future<bool> _showBackDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Batalkan Entri Data'),
          content: const Text(
            'Apakah anda akan membatalkan proses entri data?',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Ok'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: (widget.back == 1)
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF334155),
                ),
              ),
              onPressed: () async {
                if (globals.goHome == true) {
                  globals.goHome = false;
                  globals.currentPage = 0;
                  await Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                    (route) => false,
                  );
                }
                if (!context.mounted) return;
                Navigator.pop(context, true);
              },
            )
          : (widget.back == 2)
              ? IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: Color(0xFF334155),
                    ),
                  ),
                  onPressed: () async {
                    bool isBack = await _showBackDialog();
                    if (isBack) {
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    }
                  },
                )
              : null,
      title: Text(
        widget.title.toString(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
          letterSpacing: -0.2,
        ),
      ),
      centerTitle: false,
      toolbarHeight: 64,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: Color(0xFF475569),
            ),
          ),
          onPressed: () async {
            globals.currentPage = 4;
            await Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
            );
          },
        ),
        const SizedBox(width: 8)
      ],
    );
  }
}
