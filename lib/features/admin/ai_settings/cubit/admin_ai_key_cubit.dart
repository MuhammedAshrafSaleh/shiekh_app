// lib/features/admin/ai_settings/cubit/admin_ai_key_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/admin_ai_settings_repository.dart';
import 'admin_ai_key_state.dart';

class AdminAiKeyCubit extends Cubit<AdminAiKeyState> {
  final AdminAiSettingsRepository _repo;

  GeminiKeyStatus _status = const GeminiKeyStatus(isSet: false);
  int _successNonce = 0;
  int _errorNonce = 0;

  AdminAiKeyCubit(this._repo) : super(AdminAiKeyInitial());

  Future<void> load() async {
    emit(AdminAiKeyLoading());
    final result = await _repo.getGeminiKeyStatus();
    result.fold((f) => emit(AdminAiKeyError(f.message)), (status) {
      _status = status;
      _emitLoaded();
    });
  }

  void _emitLoaded({bool isSaving = false, String? success, String? error}) {
    emit(
      AdminAiKeyLoaded(
        _status,
        isSaving: isSaving,
        transientSuccess: success,
        successNonce: success != null ? ++_successNonce : _successNonce,
        transientError: error,
        errorNonce: error != null ? ++_errorNonce : _errorNonce,
      ),
    );
  }

  Future<void> saveKey(String key) async {
    _emitLoaded(isSaving: true);
    final result = await _repo.setGeminiKey(key);
    await result.fold(
      (f) async => _emitLoaded(error: f.message),
      (_) => _refresh(success: 'تم حفظ المفتاح'),
    );
  }

  Future<void> clearKey() async {
    _emitLoaded(isSaving: true);
    final result = await _repo.clearGeminiKey();
    await result.fold(
      (f) async => _emitLoaded(error: f.message),
      (_) => _refresh(success: 'تم حذف المفتاح'),
    );
  }

  /// Refetch the masked status after a mutation so last4/updated_at reflect the
  /// new value; keep the success message visible even if the refetch fails.
  Future<void> _refresh({required String success}) async {
    final result = await _repo.getGeminiKeyStatus();
    result.fold((_) {}, (status) => _status = status);
    _emitLoaded(success: success);
  }
}
