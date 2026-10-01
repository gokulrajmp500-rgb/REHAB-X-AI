import 'dart:io';

import 'package:flutter/material.dart';

Widget profileImage(String path) {
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
  );
}