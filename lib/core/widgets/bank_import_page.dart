// lib/core/widgets/bank_import_page.dart
//
// Shared full-screen picker for importing questions from a question bank into
// the final exam OR a lesson quiz. Shows each question's full text AND all four
// choices (correct answer marked), supports multi-select, and disables
// questions already imported (shown with a "تمت الإضافة" badge). Returns the
// selected List<AdminQuizQuestionEntity> via Navigator.pop, or null if discarded.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../../models/admin_quiz_question_entity.dart';
import 'bank_import_cubit.dart';
import 'empty_state.dart';
import 'sheikhy_button.dart';
import 'sheikhy_checkbox.dart';

class BankImportPage extends StatelessWidget {