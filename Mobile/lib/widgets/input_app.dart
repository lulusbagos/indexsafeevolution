import 'package:flutter/material.dart';

Widget inputApp({controller, validator, obscureText = false, hint, icon}) {
  return Container(
    height: 50,
    margin: const EdgeInsets.only(top: 10),
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.all(
        Radius.circular(20),
      ),
      color: Colors.white,
      border: Border.all(width: 1, color: Colors.indigo.shade300),
    ),
    padding: const EdgeInsets.only(left: 5),
    child: TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.indigo.shade200),
        prefixIcon: Icon(icon, color: Colors.indigo.shade300),
      ),
    ),
  );
}
