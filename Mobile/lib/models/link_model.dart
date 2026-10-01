import 'package:flutter/material.dart';

class LinkMenuModel {
  String title;
  IconData icon;
  String image;
  String route;
  double opacity;

  LinkMenuModel({
    required this.title,
    required this.icon,
    required this.image,
    required this.route,
    required this.opacity,
  });
}

class LinkNewsModel {
  String? title;
  String? description;
  String? url;
  String? image;

  LinkNewsModel({
    this.title,
    this.description,
    this.url,
    this.image,
  });
}
