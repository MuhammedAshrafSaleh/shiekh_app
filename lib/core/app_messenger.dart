// lib/core/app_messenger.dart
import 'package:flutter/material.dart';

/// Root-level ScaffoldMessenger key wired into MaterialApp.router.
/// Use for snackbars that must survive route transitions (e.g. exam
/// auto-submit notification shown on the result page).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();
