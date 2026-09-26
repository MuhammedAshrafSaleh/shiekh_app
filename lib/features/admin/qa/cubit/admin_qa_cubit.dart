// lib/features/admin/qa/cubit/admin_qa_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/admin_qa_repository.dart';
import 'admin_qa_state.dart';

class AdminQaCubit extends Cubit<AdminQaState> {
  final AdminQaRepository _repo;
  RealtimeChannel? _channel;

  AdminQaCubit(this._repo) : super(AdminQaInitial());

  Future<void> load() async {
    emit(AdminQaLoading());
    final pendingResult = await _repo.getQuestions(status: 'pending');
    await pendingResult.fold(
      (f) async => emit(AdminQaError(f.message)),
      (pending) async {
        final answeredResult = await _repo.getQuestions(status: 'answered');
        answeredResult.fold(
          (f) => emit(AdminQaError(f.message)),
          (answered) {
            emit(AdminQaLoaded(pending: pending, answered: answered));
            _subscribeRealtime();
          },
        );
      },
    );
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = _repo.subscribeToNewQuestions((_) => load());
  }

  Future<bool> answerQuestion({
    required String questionId,
    required String answerText,
  }) async {
    final result = await _repo.answerQuestion(
      questionId: questionId,
      answerText: answerText,
    );
    return result.fold(
      (f) {
        emit(AdminQaError(f.message));
        return false;
      },
      (_) {
        load();
        return true;
      },
    );
  }

  @override
  Future<void> close() async {
    await _channel?.unsubscribe();
    return super.close();
  }
}
