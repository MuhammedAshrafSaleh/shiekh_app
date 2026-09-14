// lib/core/widgets/bank_import_cubit.dart
//
// Lightweight selection state for the full-screen bank-import picker
// (BankImportPage). Holds the set of currently-selected bank question ids.
// Kept as a Cubit (not setState) per the app's state-management convention.
import 'package:flutter_bloc/flutter_bloc.dart';

class BankImportCubit extends Cubit<Set<String>> {
  BankImportCubit() : super(const {});

  void toggle(String questionId) {
    final next = Set<String>.from(state);
    if (!next.remove(questionId)) next.add(questionId);
    emit(next);
  }
}
