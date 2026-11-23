// lib/features/admin/levels/cubit/admin_levels_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../models/level_entity.dart';
import '../data/admin_level_repository.dart';
import 'admin_levels_state.dart';

class AdminLevelsCubit extends Cubit<AdminLevelsState> {
  final AdminLevelRepository _repo;

  // Cached working copy so list mutations (delete / reorder) update in place and
  // a transient failure never blanks the list.
  List<LevelEntity> _levels = const [];
  int _successNonce = 0;
  int _errorNonce = 0;

  AdminLevelsCubit(this._repo) : super(AdminLevelsInitial());

  Future<void> load() async {
    emit(AdminLevelsLoading());
    final result = await _repo.getLevels();
    result.fold((f) => emit(AdminLevelsError(f.message)), (levels) {
      _levels = levels;
      _emitLoaded();
    });
  }

  void _emitLoaded({String? success, String? error}) {
    emit(
      AdminLevelsLoaded(
        List.of(_levels),
        transientSuccess: success,
        successNonce: success != null ? ++_successNonce : _successNonce,
        transientError: error,
        errorNonce: error != null ? ++_errorNonce : _errorNonce,
      ),
    );
  }

  // ── Form (create / edit) — own cubit instance, mirrors AdminSectionsCubit ───

  Future<void> createLevel({required String name}) async {
    final result = await _repo.createLevel(name: name);
    result.fold(
      (f) => emit(AdminLevelsError(f.message)),
      (_) => emit(AdminLevelMutationSuccess()),
    );
  }

  Future<void> updateLevel({required String id, required String name}) async {
    final result = await _repo.updateLevel(id: id, name: name);
    result.fold(
      (f) => emit(AdminLevelsError(f.message)),
      (_) => emit(AdminLevelMutationSuccess()),
    );
  }

  // ── List mutations — keep the list visible, feedback via SnackBar ───────────

  Future<void> deleteLevel(String id) async {
    final result = await _repo.deleteLevel(id);
    result.fold((f) => _emitLoaded(error: f.message), (_) {
      _levels = _levels.where((l) => l.id != id).toList();
      _emitLoaded(success: 'تم حذف المستوى');
    });
  }

  /// Reorders the cached list, reassigns 1-based sort_order, and persists the
  /// changed rows in one transactional RPC. Emits the new order immediately for
  /// a responsive drag; on failure reloads from the server to restore truth.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final working = List.of(_levels);
    final moved = working.removeAt(oldIndex);
    working.insert(newIndex, moved);

    final renumbered = <LevelEntity>[];
    final changed = <({String id, int sortOrder})>[];
    for (var i = 0; i < working.length; i++) {
      final desired = i + 1;
      final l = working[i];
      if (l.sortOrder != desired) {
        renumbered.add(l.copyWith(sortOrder: desired));
        changed.add((id: l.id, sortOrder: desired));
      } else {
        renumbered.add(l);
      }
    }

    _levels = renumbered;
    _emitLoaded(); // responsive: show the new order immediately

    if (changed.isEmpty) return;
    final result = await _repo.reorderLevels(changed);
    await result.fold((f) async {
      await load();
      _emitLoaded(error: f.message);
    }, (_) async => _emitLoaded(success: 'تم تحديث الترتيب'));
  }
}
