import 'package:flutter/material.dart';

Color getBrandColor(String? hexString) {
  if (hexString == null) return const Color(0xFF38BDF8);
  try {
    return Color(int.parse('0xFF$hexString'));
  } catch (_) {
    return const Color(0xFF38BDF8);
  }
}
