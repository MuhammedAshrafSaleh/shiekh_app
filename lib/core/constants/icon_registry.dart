// lib/core/constants/icon_registry.dart
import 'package:flutter/material.dart';

// Fixed 8-icon registry for scientific sections
abstract final class SectionIcons {
  static const Map<String, IconData> icons = {
    'aqeedah': Icons.verified_outlined,
    'fiqh': Icons.balance_outlined,
    'tafseer': Icons.menu_book_outlined,
    'seerah': Icons.history_edu_outlined,
    'hadith': Icons.library_books_outlined,
    'arabic': Icons.translate_outlined,
    'ethics': Icons.favorite_outline,
    'general': Icons.school_outlined,
  };

  static const List<String> keys = [
    'aqeedah',
    'fiqh',
    'tafseer',
    'seerah',
    'hadith',
    'arabic',
    'ethics',
    'general',
  ];

  static const Map<String, String> labels = {
    'aqeedah': 'العقيدة',
    'fiqh': 'الفقه',
    'tafseer': 'التفسير',
    'seerah': 'السيرة',
    'hadith': 'الحديث',
    'arabic': 'اللغة العربية',
    'ethics': 'الأخلاق',
    'general': 'علوم شرعية',
  };

  static IconData fromKey(String key) => icons[key] ?? Icons.school_outlined;
}
