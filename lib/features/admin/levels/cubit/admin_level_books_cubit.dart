// lib/features/admin/levels/cubit/admin_level_books_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../models/book_entity.dart';
import '../data/admin_level_repository.dart';
import 'admin_level_books_state.dart';

/// Manages the books assigned to a single level (load / add / remove / reorder).
/// `addBook` handles both a fresh add and a MOVE from another level — the
/// repository's addBookToLevel overwrite is the move.
class AdminLevelBooksCubit extends Cubit<AdminLevelBooksState> {
  final AdminLevelRepository _repo;
  final String levelId;

  List<BookEntity> _books = const [];
  int _successNonce = 0;
  int _errorNonce = 0;

  AdminLevelBooksCubit(this._repo, this.levelId)
    : super(AdminLevelBooksInitial());

  Future<void> load() async {
    emit(AdminLevelBooksLoading());
    final result = await _repo.getBooksInLevel(levelId);
    result.fold((f) => emit(AdminLevelBooksError(f.message)), (books) {
      _books = books;
      _emitLoaded();
    });
  }

  void _emitLoaded({String? success, String? error}) {
    emit(
      AdminLevelBooksLoaded(
        List.of(_books),
        transientSuccess: success,
        successNonce: success != null ? ++_successNonce : _successNonce,
        transientError: error,
        errorNonce: error != null ? ++_errorNonce : _errorNonce,
      ),
    );
  }

  /// Add (or MOVE) a book into this level, then reload so it appears at the end.
  Future<void> addBook(String bookId) async {
    final result = await _repo.addBookToLevel(bookId: bookId, levelId: levelId);
    await result.fold((f) async => _emitLoaded(error: f.message), (_) async {
      await load();
      _emitLoaded(success: 'تمت إضافة الكتاب إلى المستوى');
    });
  }

  Future<void> removeBook(String bookId) async {
    final result = await _repo.removeBookFromLevel(bookId);
    result.fold((f) => _emitLoaded(error: f.message), (_) {
      _books = _books.where((b) => b.id != bookId).toList();
      _emitLoaded(success: 'تمت إزالة الكتاب من المستوى');
    });
  }

  /// Reorders the cached list, reassigns 1-based level_order, persists the
  /// changed rows via the scoped reorder_level_books RPC. Optimistic; reloads on
  /// failure.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final working = List.of(_books);
    final moved = working.removeAt(oldIndex);
    working.insert(newIndex, moved);

    // Renumber EVERY book to its 1-based position (not just moved ones):
    // BookEntity carries no level_order to diff against, and a MOVE out of this
    // level leaves gaps, so a full position-based renumber is the safe choice.
    // Book counts per level are bounded, so the extra rows are cheap.
    final changed = <({String id, int levelOrder})>[];
    for (var i = 0; i < working.length; i++) {
      changed.add((id: working[i].id, levelOrder: i + 1));
    }

    _books = working;
    _emitLoaded(); // responsive: show the new order immediately

    final result = await _repo.reorderLevelBooks(
      levelId: levelId,
      updates: changed,
    );
    await result.fold((f) async {
      await load();
      _emitLoaded(error: f.message);
    }, (_) async => _emitLoaded(success: 'تم تحديث الترتيب'));
  }
}
