import 'package:flutter/material.dart';

Widget profileImage(String path) {
  return Image.network(
    path,
    fit: BoxFit.cover,
    errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
  );
}