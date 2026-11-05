// lib/features/admin/ai_settings/cubit/admin_ai_key_state.dart
import 'package:equatable/equatable.dart';

import '../data/admin_ai_settings_repository.dart';

abstract class AdminAiKeyState extends Equatable {
  const AdminAiKeyState();
  @override
  List<Object?> get props => [];
}

class AdminAiKeyInitial extends AdminAiKeyState {}

class AdminAiKeyLoading extends AdminAiKeyState {}

/// The masked key status + one-shot SnackBar signals. On a failed mutation we
/// re-emit this with [transientError] so the screen stays usable; on success,
/// [transientSuccess]. Nonces keep repeat messages distinct so the listener
/// fires every time. [isSaving] drives the save/clear button spinners.
class AdminAiKeyLoaded extends AdminAiKeyState {
  final GeminiKeyStatus status;
  final bool isSaving;
  final String? transientSuccess;
  final int successNonce;
  final String? transientError;
  final int errorNonce;

  const AdminAiKeyLoaded(
    this.status, {
    this.isSaving = false,
    this.transientSuccess,
    this.successNonce = 0,
    this.transientError,
    this.errorNonce = 0,
  });

  @override
  List<Object?> get props => [
    status,
    isSaving,
    transientSuccess,
    successNonce,
    transientError,
    errorNonce,
  ];
}

/// Full-screen error — only for a failed initial status load.
class AdminAiKeyError extends AdminAiKeyState {
  final String message;
  const AdminAiKeyError(this.message);
  @override
  List<Object?> get props => [message];
}
