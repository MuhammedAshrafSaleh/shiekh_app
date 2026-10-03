// lib/features/admin/loading_quotes/cubit/admin_loading_quotes_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../models/loading_quote_entity.dart';
import '../data/admin_loading_quotes_repository.dart';
import 'admin_loading_quotes_state.dart';

class AdminLoadingQuotesCubit extends Cubit<AdminLoadingQuotesState> {
  final AdminLoadingQuotesRepository _repo;

  // Cached working copy so list mutations update in place and a failure never
  // blanks the list.
  List<LoadingQuoteEntity> _quotes = const [];
  int _successNonce = 0;
  int _errorNonce = 0;
  int _formErrorNonce = 0;

  AdminLoadingQuotesCubit(this._repo) : super(AdminLoadingQuotesInitial());

  Future<void> load() async {
    emit(AdminLoadingQuotesLoading());
    final result = await _repo.getQuotes();
    result.fold((f) => emit(AdminLoadingQuotesError(f.message)), (quotes) {
      _quotes = quotes;
      _emitLoaded();
    });
  }

  void _emitLoaded({String? success, String? error}) {
    emit(
      AdminLoadingQuotesLoaded(
        List.of(_quotes),
        transientSuccess: success,
        successNonce: success != null ? ++_successNonce : _successNonce,
        transientError: error,
        errorNonce: error != null ? ++_errorNonce : _errorNonce,
      ),
    );
  }

  // ── Form (create / edit) — own cubit instance, no cached list ─────────────

  Future<void> createQuote({
    required String text,
    String? source,
    required int sortOrder,
    required bool isActive,
  }) async {
    final result = await _repo.createQuote(
      text: text,
      source: source,
      sortOrder: sortOrder,
      isActive: isActive,
    );
    result.fold(
      (f) => emit(AdminLoadingQuotesFormError(f.message, ++_formErrorNonce)),
      (_) => emit(const AdminLoadingQuotesSaved()),
    );
  }

  Future<void> updateQuote({
    required String id,
    required String text,
    String? source,
    required bool isActive,
  }) async {
    final result = await _repo.updateQuote(
      id: id,
      text: text,
      source: source,
      isActive: isActive,
    );
    result.fold(
      (f) => emit(AdminLoadingQuotesFormError(f.message, ++_formErrorNonce)),
      (_) => emit(const AdminLoadingQuotesSaved()),
    );
  }

  // ── List mutations — keep the list visible on failure ─────────────────────

  Future<void> toggleActive({
    required String id,
    required bool isActive,
  }) async {
    final result = await _repo.setActive(id: id, isActive: isActive);
    result.fold((f) => _emitLoaded(error: f.message), (updated) {
      _quotes = [
        for (final q in _quotes)
          if (q.id == updated.id) updated else q,
      ];
      _emitLoaded(
        success: updated.isActive ? 'تم تفعيل النص' : 'تم إخفاء النص',
      );
    });
  }

  Future<void> deleteQuote(String id) async {
    final result = await _repo.deleteQuote(id);
    result.fold((f) => _emitLoaded(error: f.message), (_) {
      _quotes = _quotes.where((q) => q.id != id).toList();
      _emitLoaded(success: 'تم الحذف');
    });
  }

  /// Reorders the cached list, reassigns 1-based sort_order, persists every row
  /// whose index changed. Emits the new order immediately for a responsive
  /// drag; on any write failure it reloads from the server.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final working = List.of(_quotes);
    final moved = working.removeAt(oldIndex);
    working.insert(newIndex, moved);

    final renumbered = <LoadingQuoteEntity>[];
    final changed = <LoadingQuoteEntity>[];
    for (var i = 0; i < working.length; i++) {
      final desired = i + 1;
      final q = working[i];
      if (q.sortOrder != desired) {
        final updated = q.copyWith(sortOrder: desired);
        renumbered.add(updated);
        changed.add(updated);
      } else {
        renumbered.add(q);
      }
    }

    _quotes = renumbered;
    _emitLoaded(); // responsive: show the new order immediately

    for (final q in changed) {
      final result = await _repo.updateOrder(id: q.id, sortOrder: q.sortOrder);
      if (result.isLeft()) {
        final message = result.fold((f) => f.message, (_) => '');
        await load();
        _emitLoaded(error: message);
        return;
      }
    }
    if (changed.isNotEmpty) _emitLoaded(success: 'تم تحديث الترتيب');
  }

  /// Next sort_order for a new quote (append at the end).
  int get nextSortOrder => _quotes.isEmpty
      ? 1
      : _quotes.map((q) => q.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
}
