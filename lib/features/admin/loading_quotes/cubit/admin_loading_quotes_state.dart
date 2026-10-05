// lib/features/admin/loading_quotes/cubit/admin_loading_quotes_state.dart
import 'package:equatable/equatable.dart';

import '../../../../models/loading_quote_entity.dart';

abstract class AdminLoadingQuotesState extends Equatable {
  const AdminLoadingQuotesState();
  @override
  List<Object?> get props => [];
}

class AdminLoadingQuotesInitial extends AdminLoadingQuotesState {}

class AdminLoadingQuotesLoading extends AdminLoadingQuotesState {}

/// The list + one-shot SnackBar signals. On a failed LIST mutation we re-emit
/// this with [transientError] so the list stays visible (mirrors the admin
/// lesson delete fix); on success, [transientSuccess]. The nonces keep repeat
/// messages distinct so the listener fires every time.
class AdminLoadingQuotesLoaded extends AdminLoadingQuotesState {
  final List<LoadingQuoteEntity> quotes;
  final String? transientSuccess;
  final int successNonce;
  final String? transientError;
  final int errorNonce;

  const AdminLoadingQuotesLoaded(
    this.quotes, {
    this.transientSuccess,
    this.successNonce = 0,
    this.transientError,
    this.errorNonce = 0,
  });

  /// Whether any quote is active — drives the "defaults will be shown" banner.
  bool get hasActive => quotes.any((q) => q.isActive);

  @override
  List<Object?> get props => [
    quotes,
    transientSuccess,
    successNonce,
    transientError,
    errorNonce,
  ];
}

/// Full-screen error — only for a failed initial load (no list to preserve).
class AdminLoadingQuotesError extends AdminLoadingQuotesState {
  final String message;
  const AdminLoadingQuotesError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Form (create/edit) outcome signals, listened to by the form page.
class AdminLoadingQuotesSaved extends AdminLoadingQuotesState {
  const AdminLoadingQuotesSaved();
}

class AdminLoadingQuotesFormError extends AdminLoadingQuotesState {
  final String message;
  final int nonce;
  const AdminLoadingQuotesFormError(this.message, this.nonce);
  @override
  List<Object?> get props => [message, nonce];
}
