import 'package:flutter/material.dart';

Widget buttonApp({
  String label = '',
  IconData? icon,
  void Function()? onPressed,
  Color? bgColor,
  Color? textColor,
}) {
  if (icon != null) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: (textColor != null) ? textColor : Colors.white,
        backgroundColor: (bgColor != null) ? bgColor : Colors.blue.shade700,
        minimumSize: const Size(100, 50),
      ),
      icon: Icon(icon, color: (textColor != null) ? textColor : Colors.white),
      label: Text(
        label.toString().trim(),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      foregroundColor: (textColor != null) ? textColor : Colors.white,
      backgroundColor: (bgColor != null) ? bgColor : Colors.blue.shade700,
      minimumSize: const Size(100, 50),
    ),
    child: Text(
      label.toString().trim(),
      style: const TextStyle(fontSize: 16),
    ),
  );
}
