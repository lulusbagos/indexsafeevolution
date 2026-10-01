import 'package:flutter/material.dart';

class SnackBarMsg {
  static void success(BuildContext context, String? message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ??= '',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green.withOpacity(0.8),
          elevation: 0,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static void danger(BuildContext context, String? message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ??= '',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.withOpacity(0.8),
          elevation: 0,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static void warning(BuildContext context, String? message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ??= '',
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.yellow.withOpacity(0.8),
          elevation: 0,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static void info(BuildContext context, String? message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ??= '',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blue.withOpacity(0.8),
          elevation: 0,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static void loader(BuildContext context, bool show, {double top = 0.0}) {
    if (context.mounted) {
      final bottom = (MediaQuery.of(context).size.height / 2.5) - top;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      if (show) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            elevation: 0,
            margin: EdgeInsets.only(bottom: bottom),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            duration: const Duration(minutes: 5),
            dismissDirection: DismissDirection.none,
          ),
        );
      }
    }
  }
}
